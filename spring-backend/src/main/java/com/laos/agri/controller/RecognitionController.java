package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.service.AiServiceClient;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;

/**
 * 病虫害识别API — 供Flutter APP调用
 */
@RestController
@RequestMapping("/api/v1/recognition")
public class RecognitionController {

    private final AiServiceClient aiServiceClient;

    public RecognitionController(AiServiceClient aiServiceClient) {
        this.aiServiceClient = aiServiceClient;
    }

    /**
     * 上传图片进行病虫害识别
     */
    @PostMapping("/identify")
    public ApiResponse<Map<String, Object>> identify(
            @RequestParam("image") MultipartFile image,
            @RequestParam(value = "crop_id", required = false) Integer cropId,
            @RequestParam(value = "language", defaultValue = "zh") String language,
            @RequestParam(value = "version", defaultValue = "vegetable") String version) {

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

        // 2. 生成任务ID
        String taskId = "rec_" + UUID.randomUUID().toString().substring(0, 8);

        try {
            // 3. 编码图片为Base64 → 发给AI服务
            String base64Image = Base64.getEncoder().encodeToString(image.getBytes());

            // 4. 调用AI识别
            // TODO: 第三阶段完整实现 — 先查本地数据库获取作物名 + 调用AI + 解析结果 + 入库
            Map<String, Object> aiResult = aiServiceClient.identifyDisease(
                    base64Image, null, language, version);

            return ApiResponse.ok(Map.of(
                "task_id", taskId,
                "status", "completed",
                "results", aiResult.getOrDefault("results", "[]")
            ));
        } catch (IOException e) {
            return ApiResponse.error(500, "图片处理失败: " + e.getMessage());
        } catch (Exception e) {
            return ApiResponse.error(502, "AI识别服务不可用: " + e.getMessage());
        }
    }

    /**
     * 查询识别结果
     */
    @GetMapping("/result/{taskId}")
    public ApiResponse<Map<String, String>> getResult(@PathVariable String taskId) {
        return ApiResponse.ok(Map.of(
            "task_id", taskId,
            "status", "pending"
        ));
    }
}
