package com.laos.agri.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.laos.agri.dto.ApiResponse;
import com.laos.agri.entity.DiagnosisRecord;
import com.laos.agri.repository.CropRepository;
import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.DiseaseRepository;
import com.laos.agri.service.AiRuntimeConfigService;
import com.laos.agri.service.AiServiceClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.*;

/**
 * 病虫害识别API — 供Flutter APP调用
 *
 * Sprint 10.2 升级：完整实现识别→入库→反馈闭环
 */
@RestController
@RequestMapping("/api/v1/recognition")
public class RecognitionController {

    private static final Logger log = LoggerFactory.getLogger(RecognitionController.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    /** 识别图片在 uploads 下的子目录（与对外 URL /uploads/recognition/xxx.jpg 对应） */
    private static final String RECOGNITION_SUBDIR = "recognition";

    private final AiServiceClient aiServiceClient;
    private final AiRuntimeConfigService aiRuntimeConfigService;
    private final DiagnosisRecordRepository diagnosisRepo;
    private final DiseaseRepository diseaseRepo;
    private final CropRepository cropRepo;

    /**
     * 上传根目录 —— 必须用**绝对路径**
     *
     * <p>踩过的坑：{@code MultipartFile.transferTo(相对路径)} 在 Tomcat 下是相对
     * **multipart 临时目录**解析的，不是相对进程工作目录。结果是目录建在了
     * ./uploads/recognition，文件却被写到临时目录并在请求结束后消失 ——
     * 表现为"识别记录有 image_url，但图片 404 且磁盘上找不到"。
     */
    private final Path uploadBase;

    public RecognitionController(AiServiceClient aiServiceClient,
                                  AiRuntimeConfigService aiRuntimeConfigService,
                                  DiagnosisRecordRepository diagnosisRepo,
                                  DiseaseRepository diseaseRepo,
                                  CropRepository cropRepo,
                                  @org.springframework.beans.factory.annotation.Value(
                                          "${app.storage.upload-dir:./uploads}") String uploadDir) {
        this.aiServiceClient = aiServiceClient;
        this.aiRuntimeConfigService = aiRuntimeConfigService;
        this.diagnosisRepo = diagnosisRepo;
        this.diseaseRepo = diseaseRepo;
        this.cropRepo = cropRepo;
        this.uploadBase = Paths.get(uploadDir).toAbsolutePath().normalize();
    }

    /**
     * 上传图片进行病虫害识别 — 完整入库版
     */
    @PostMapping("/identify")
    public ApiResponse<Map<String, Object>> identify(
            @RequestParam("image") MultipartFile image,
            @RequestParam(value = "crop_id", required = false) Integer cropId,
            @RequestParam(value = "language", defaultValue = "zh") String language,
            @RequestParam(value = "version", defaultValue = "vegetable") String version,
            @RequestParam(value = "user_id", required = false) Long userId,
            @RequestParam(value = "device_uuid", required = false) String deviceUuid,
            @RequestParam(value = "latitude", required = false) BigDecimal latitude,
            @RequestParam(value = "longitude", required = false) BigDecimal longitude,
            @RequestParam(value = "location_name", required = false) String locationName) {

        long startTime = System.currentTimeMillis();

        // 1. 校验图片
        if (image.isEmpty()) {
            return ApiResponse.error(400, "图片不能为空");
        }
        String contentType = image.getContentType();
        if (contentType == null || !contentType.matches("image/(jpeg|png|webp)")) {
            return ApiResponse.error(400, "仅支持 jpg/png/webp 格式");
        }
        if (image.getSize() > 10 * 1024 * 1024) {
            return ApiResponse.error(413, "图片大小不能超过10MB");
        }

        // 2. 先把图片字节读进内存 —— **顺序很关键**
        //
        //    踩过的坑：saveImage() 里的 MultipartFile.transferTo() 会把 multipart 临时文件
        //    **移动**到目标路径；之后再调用 image.getBytes() 就会抛
        //    FileNotFoundException（消息里是 /tmp/tomcat…/upload_xxx.tmp 这样的临时路径）。
        //    这个异常被下面的 catch 包成"AI识别服务不可用"，看起来像 AI 侧问题，
        //    实际是上传处理顺序错了 —— 拍照识别会 100% 失败。
        byte[] imageBytes;
        try {
            imageBytes = image.getBytes();
        } catch (IOException e) {
            log.error("读取上传图片失败: {}", e.getMessage());
            return ApiResponse.error(400, "读取上传的图片失败，请重试");
        }

        String taskId = "rec_" + UUID.randomUUID().toString().substring(0, 8);
        String imagePath = saveImage(image, taskId);

        // 3. 解析作物名（如果提供了crop_id）
        String cropName = resolveCropName(cropId);

        // 4. 创建诊断记录 (status=processing)
        DiagnosisRecord record = new DiagnosisRecord();
        record.setTaskId(taskId);
        record.setUserId(userId);
        record.setDeviceUuid(deviceUuid);
        record.setVersion(version);
        record.setLanguage(language);
        record.setImageUrl(imagePath);
        record.setCropId(cropId);
        record.setStatus("processing");
        record.setGpsLatitude(latitude);
        record.setGpsLongitude(longitude);
        record.setLocationName(locationName);
        diagnosisRepo.save(record);

        try {
            // 5. 编码图片为Base64 → 发给AI服务
            //    用上面已经读进内存的 imageBytes（不能再调 image.getBytes()，临时文件已被移走）
            String base64Image = Base64.getEncoder().encodeToString(imageBytes);

            // 6. 调用AI识别
            //    把后台「AI 配置中心」里当前生效的通道一起下发 ——
            //    少了这个参数，AI 服务只能用 .env 默认值，后台换通道等于没换。
            Map<String, Object> aiResult = aiServiceClient.identifyDisease(
                    base64Image, cropName, language, version,
                    aiRuntimeConfigService.activeChannel());

            int processingTimeMs = (int) (System.currentTimeMillis() - startTime);

            // 7. 解析AI结果 → 填充诊断记录
            populateRecordFromAiResult(record, aiResult, version, processingTimeMs);

            record.setStatus("completed");
            diagnosisRepo.save(record);

            log.info("识别完成: taskId={}, disease={}, confidence={}",
                    taskId, record.getTopDiseaseId(), record.getTopConfidence());

            // 8. 返回结果
            Map<String, Object> resultData = new LinkedHashMap<>();
            resultData.put("task_id", taskId);
            resultData.put("status", "completed");
            resultData.put("disease_name_zh", aiResult.getOrDefault("disease_name_zh", ""));
            resultData.put("disease_name_lo", aiResult.getOrDefault("disease_name_lo", ""));
            resultData.put("confidence", aiResult.getOrDefault("confidence", 0));
            resultData.put("confidence_level", aiResult.getOrDefault("confidence_level", "low"));
            resultData.put("type", aiResult.getOrDefault("type", "disease"));
            resultData.put("severity", aiResult.getOrDefault("severity", "moderate"));
            resultData.put("symptoms_zh", aiResult.getOrDefault("symptoms_zh", ""));
            resultData.put("conditions_zh", aiResult.getOrDefault("conditions_zh", ""));
            resultData.put("prevention", aiResult.getOrDefault("prevention", Map.of()));
            resultData.put("provider", aiResult.getOrDefault("provider", "gemini"));
            resultData.put("processing_time_ms", processingTimeMs);
            resultData.put("need_expert_review", aiResult.getOrDefault("need_expert_review", false));

            return ApiResponse.ok(resultData);

        } catch (Exception e) {
            log.error("AI识别失败: taskId={}, error={}", taskId, e.getMessage());

            // 更新为失败状态
            record.setStatus("failed");
            record.setErrorMessage(e.getMessage());
            record.setProcessingTimeMs((int) (System.currentTimeMillis() - startTime));
            diagnosisRepo.save(record);

            return ApiResponse.error(502, "AI识别服务不可用: " + e.getMessage());
        }
    }

    /**
     * 查询识别结果
     */
    @GetMapping("/result/{taskId}")
    public ApiResponse<Map<String, Object>> getResult(@PathVariable String taskId) {
        var record = diagnosisRepo.findByTaskId(taskId);
        if (record.isEmpty()) {
            return ApiResponse.error(404, "任务不存在");
        }
        var r = record.get();
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("task_id", r.getTaskId());
        data.put("status", r.getStatus());
        data.put("disease_name_zh",
                r.getParsedResults() != null ? extractField(r.getParsedResults(), "disease_name_zh") : "");
        data.put("confidence", r.getTopConfidence());
        data.put("confidence_level", r.getConfidenceLevel());
        data.put("provider", r.getProviderUsed());
        data.put("processing_time_ms", r.getProcessingTimeMs());
        data.put("user_feedback", r.getUserFeedback());
        data.put("error_message", r.getErrorMessage());
        return ApiResponse.ok(data);
    }

    /**
     * 用户提交识别反馈 ✅
     */
    @PostMapping("/{taskId}/feedback")
    public ApiResponse<?> submitFeedback(
            @PathVariable String taskId,
            @RequestBody Map<String, Object> feedback) {

        var record = diagnosisRepo.findByTaskId(taskId)
                .orElseThrow(() -> new RuntimeException("诊断记录不存在: " + taskId));

        String fb = (String) feedback.getOrDefault("feedback", "confirmed");
        String note = (String) feedback.getOrDefault("note", "");

        record.setUserFeedback(fb);
        record.setUserFeedbackAt(LocalDateTime.now());

        // 如果用户反馈"不正确" → 标记需要专家审核
        if ("disputed".equals(fb)) {
            record.setExpertReviewed(false);
            record.setExpertNotes("用户反馈不正确: " + note);
            if (record.getStatus().equals("completed")) {
                record.setStatus("reviewed");  // 进入待审核
            }
        }

        diagnosisRepo.save(record);
        log.info("用户反馈已记录: taskId={}, feedback={}", taskId, fb);

        return ApiResponse.ok("反馈已提交");
    }

    /**
     * 获取用户的识别历史
     */
    @GetMapping("/history")
    public ApiResponse<?> getHistory(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) String version,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        if (userId == null) {
            return ApiResponse.error(400, "需要提供user_id");
        }

        var pageData = diagnosisRepo.findByUserIdOrderByCreatedAtDesc(
                userId, org.springframework.data.domain.PageRequest.of(page, size));
        return ApiResponse.ok(Map.of(
            "items", pageData.getContent(),
            "total", pageData.getTotalElements(),
            "page", page,
            "pageSize", size
        ));
    }

    // ========== 私有方法 ==========

    /**
     * 保存上传的图片到本地
     *
     * <p>路径必须绝对化后再写：`transferTo` 收到相对路径会按 multipart 临时目录解析，
     * 文件会落在临时目录并在请求结束后被清掉（图片 URL 随即 404）。
     */
    private String saveImage(MultipartFile image, String taskId) {
        try {
            Path uploadDir = uploadBase.resolve(RECOGNITION_SUBDIR);
            Files.createDirectories(uploadDir);

            String ext = ".jpg";
            String ct = image.getContentType();
            if (ct != null) {
                if (ct.contains("png")) ext = ".png";
                else if (ct.contains("webp")) ext = ".webp";
            }

            String filename = taskId + ext;
            Path filePath = uploadDir.resolve(filename);
            image.transferTo(filePath.toFile());

            return "/uploads/" + RECOGNITION_SUBDIR + "/" + filename;
        } catch (IOException e) {
            log.warn("图片保存失败: taskId={}, error={}", taskId, e.getMessage());
            return "";  // 保存失败不影响主流程
        }
    }

    /**
     * 解析作物名称
     */
    private String resolveCropName(Integer cropId) {
        if (cropId == null) return "";
        try {
            var crop = cropRepo.findById(cropId);
            return crop.map(c -> c.getNameZh()).orElse("");
        } catch (Exception e) {
            return "";
        }
    }

    /**
     * 将AI返回结果填充到DiagnosisRecord
     */
    private void populateRecordFromAiResult(DiagnosisRecord record,
                                             Map<String, Object> aiResult,
                                             String version,
                                             int processingTimeMs) {
        // 保存原始AI响应
        try {
            record.setAiRawResponse(objectMapper.writeValueAsString(aiResult));
        } catch (JsonProcessingException e) {
            record.setAiRawResponse(aiResult.toString());
        }

        // 提取置信度
        Object confObj = aiResult.get("confidence");
        double confidence = 0.0;
        if (confObj instanceof Number) {
            confidence = ((Number) confObj).doubleValue();
        }
        record.setTopConfidence(BigDecimal.valueOf(confidence).setScale(4, RoundingMode.HALF_UP));

        // 置信度级别 — 直接采用 AI 服务 confidence_manager 的决策结果(单一来源)
        String level = (String) aiResult.getOrDefault("confidence_level", "low");
        record.setConfidenceLevel(level);

        // 提取病害名 → 尝试匹配本地病害库
        String diseaseNameZh = (String) aiResult.getOrDefault("disease_name_zh", "");
        if (diseaseNameZh != null && !diseaseNameZh.isBlank() && !diseaseNameZh.contains("无法识别")) {
            // 尝试在本地病害库中匹配
            var diseases = diseaseRepo.findByNameZhContaining(diseaseNameZh);
            if (!diseases.isEmpty()) {
                record.setTopDiseaseId(diseases.get(0).getId());
            }
        }

        // 保存解析后的结果（用于查询展示）
        Map<String, Object> parsed = new LinkedHashMap<>();
        parsed.put("disease_name_zh", aiResult.getOrDefault("disease_name_zh", ""));
        parsed.put("disease_name_lo", aiResult.getOrDefault("disease_name_lo", ""));
        parsed.put("confidence", confidence);
        parsed.put("type", aiResult.getOrDefault("type", "disease"));
        parsed.put("severity", aiResult.getOrDefault("severity", "moderate"));
        parsed.put("symptoms_zh", aiResult.getOrDefault("symptoms_zh", ""));
        parsed.put("conditions_zh", aiResult.getOrDefault("conditions_zh", ""));
        parsed.put("need_expert_review", aiResult.getOrDefault("need_expert_review", false));
        if (aiResult.containsKey("prevention")) {
            parsed.put("prevention", aiResult.get("prevention"));
        }
        try {
            record.setParsedResults(objectMapper.writeValueAsString(parsed));
        } catch (JsonProcessingException e) {
            record.setParsedResults(parsed.toString());
        }

        // 防控方案快照
        if (aiResult.containsKey("prevention")) {
            try {
                record.setPreventionJson(objectMapper.writeValueAsString(aiResult.get("prevention")));
            } catch (JsonProcessingException ignored) {}
        }

        // 技术元数据
        String providerUsed = (String) aiResult.getOrDefault("provider", "gemini");
        record.setProviderUsed(providerUsed);
        record.setProcessingTimeMs(processingTimeMs);
    }

    /**
     * 从parsed_results JSON中提取字段
     */
    @SuppressWarnings("unchecked")
    private String extractField(String parsedResults, String field) {
        try {
            Map<String, Object> map = objectMapper.readValue(parsedResults, Map.class);
            Object val = map.get(field);
            return val != null ? val.toString() : "";
        } catch (Exception e) {
            return "";
        }
    }
}
