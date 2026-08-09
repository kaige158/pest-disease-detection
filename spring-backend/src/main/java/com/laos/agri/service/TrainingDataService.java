package com.laos.agri.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.laos.agri.entity.DiagnosisRecord;
import com.laos.agri.entity.TrainingDataset;
import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.TrainingDatasetRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * 训练数据资产管理服务 — Sprint 11 核心
 *
 * 原则:
 *   1. AI识别 → training_ready = false (默认)
 *   2. 专家审核通过 → training_ready = true
 *   3. 只有 training_ready=true 的数据才能导出训练
 */
@Service
public class TrainingDataService {

    private static final Logger log = LoggerFactory.getLogger(TrainingDataService.class);
    private static final ObjectMapper objectMapper = new ObjectMapper();

    private final TrainingDatasetRepository tdRepo;
    private final DiagnosisRecordRepository diagnosisRepo;
    private final JdbcTemplate jdbc;

    public TrainingDataService(TrainingDatasetRepository tdRepo,
                                DiagnosisRecordRepository diagnosisRepo,
                                JdbcTemplate jdbc) {
        this.tdRepo = tdRepo;
        this.diagnosisRepo = diagnosisRepo;
        this.jdbc = jdbc;
    }

    /**
     * 识别完成后创建训练数据记录（training_ready=false）
     */
    @Transactional
    public TrainingDataset createFromDiagnosis(DiagnosisRecord record) {
        // 避免重复创建
        if (record.getId() != null && tdRepo.findByDiagnosisId(record.getId()).isPresent()) {
            return tdRepo.findByDiagnosisId(record.getId()).get();
        }

        TrainingDataset td = new TrainingDataset();
        td.setAssetId(generateAssetId(record));
        td.setDiagnosisId(record.getId());
        td.setCropId(record.getCropId());
        td.setVersion(record.getVersion());
        td.setLanguage(record.getLanguage());
        td.setLocationName(record.getLocationName());
        td.setGpsLatitude(record.getGpsLatitude());
        td.setGpsLongitude(record.getGpsLongitude());
        td.setPlantPart(record.getPlantPart());
        td.setGrowthStage(record.getGrowthStage());
        td.setImagePath(record.getImageUrl());

        // AI预测信息
        td.setAiPrediction(extractDiseaseName(record.getParsedResults()));
        td.setAiConfidence(record.getTopConfidence());
        td.setAiModel(record.getProviderUsed());
        td.setAiRawResponse(record.getAiRawResponse());

        // 默认不用于训练
        td.setExpertConfirm(false);
        td.setTrainingReady(false);

        td = tdRepo.save(td);
        log.info("训练数据记录已创建: assetId={}, training_ready=false", td.getAssetId());
        return td;
    }

    /**
     * 专家审核通过 → 标记为可训练 ⭐
     *
     * @param diagnosisId  诊断记录ID
     * @param expertId     专家ID
     * @param correctLabel 专家确认的正确病虫害名
     * @param notes        专家备注
     */
    @Transactional
    public TrainingDataset approveForTraining(Long diagnosisId, Long expertId,
                                               String correctLabel, String correctLabelLo,
                                               String notes, BigDecimal imageQualityScore) {
        var td = tdRepo.findByDiagnosisId(diagnosisId)
                .orElseThrow(() -> new RuntimeException("训练数据记录不存在: diagnosisId=" + diagnosisId));

        td.setExpertConfirm(true);
        td.setExpertId(expertId);
        td.setExpertLabel(correctLabel);
        td.setExpertLabelLo(correctLabelLo);
        td.setExpertNotes(notes);
        td.setReviewedAt(LocalDateTime.now());

        // 训练就绪条件: 专家确认 + 质量评分 >= 50
        double quality = imageQualityScore != null ? imageQualityScore.doubleValue() : 70.0;
        td.setImageQualityScore(BigDecimal.valueOf(quality).setScale(1, RoundingMode.HALF_UP));

        boolean ready = quality >= 50.0;
        td.setTrainingReady(ready);

        // 更新病害标签
        td.setDiseaseZh(correctLabel);
        td.setDiseaseLo(correctLabelLo);

        td.setUpdatedAt(LocalDateTime.now());
        td = tdRepo.save(td);

        log.info("训练数据审核完成: assetId={}, training_ready={}, label={}",
                td.getAssetId(), td.getTrainingReady(), correctLabel);
        return td;
    }

    /**
     * 导出训练就绪数据集
     */
    public Map<String, Object> exportTrainingReady(String format) {
        var ready = tdRepo.findUnexportedTrainingReady();
        String batchId = "EXPORT_" + LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));

        // 分配 train/val/test 分割
        Random random = new Random(42);
        int total = ready.size();
        int trainEnd = (int) (total * 0.7);
        int valEnd = (int) (total * 0.85);

        List<TrainingDataset> trainSet = new ArrayList<>();
        List<TrainingDataset> valSet = new ArrayList<>();
        List<TrainingDataset> testSet = new ArrayList<>();

        for (int i = 0; i < total; i++) {
            TrainingDataset td = ready.get(i);
            if (i < trainEnd) {
                td.setTrainingSplit("train");
                trainSet.add(td);
            } else if (i < valEnd) {
                td.setTrainingSplit("val");
                valSet.add(td);
            } else {
                td.setTrainingSplit("test");
                testSet.add(td);
            }
            td.setExportBatch(batchId);
            td.setExportedAt(LocalDateTime.now());
        }
        tdRepo.saveAll(ready);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("batch_id", batchId);
        result.put("format", format);
        result.put("total", total);
        result.put("train", trainSet.size());
        result.put("val", valSet.size());
        result.put("test", testSet.size());
        result.put("manifest", buildManifest(ready));

        // 记录导出任务
        jdbc.update(
            "INSERT INTO extension.training_export_job " +
            "(batch_id, export_format, total_images, train_count, val_count, test_count, status, started_at) " +
            "VALUES (?, ?, ?, ?, ?, ?, 'completed', NOW())",
            batchId, format, total, trainSet.size(), valSet.size(), testSet.size()
        );

        log.info("训练数据导出完成: batch={}, total={}, train/val/test={}/{}/{}",
                batchId, total, trainSet.size(), valSet.size(), testSet.size());
        return result;
    }

    /**
     * 获取训练数据统计
     */
    public Map<String, Object> getStats() {
        long total = tdRepo.count();
        long ready = tdRepo.countTrainingReady();
        long confirmed = tdRepo.count();  // 从DB查expert_confirm=true的

        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("total_assets", total);
        stats.put("training_ready", ready);
        stats.put("expert_confirmed", confirmed);
        stats.put("ready_percent", total > 0 ? ready * 100 / total : 0);

        // 按作物
        List<Map<String, Object>> byCrop = new ArrayList<>();
        for (Object[] row : tdRepo.countByCrop()) {
            byCrop.add(Map.of(
                "crop", row[0] != null ? row[0].toString() : "",
                "total", ((Number) row[1]).longValue(),
                "ready", ((Number) row[2]).longValue()
            ));
        }
        stats.put("by_crop", byCrop);

        // 按模型
        List<Map<String, Object>> byModel = new ArrayList<>();
        for (Object[] row : tdRepo.countByAiModel()) {
            byModel.add(Map.of(
                "model", row[0] != null ? row[0].toString() : "",
                "total", ((Number) row[1]).longValue(),
                "ready", ((Number) row[2]).longValue(),
                "avg_confidence", row[3] != null ? Math.round(((Number) row[3]).doubleValue() * 10000) / 100.0 : 0
            ));
        }
        stats.put("by_model", byModel);

        return stats;
    }

    // ========== 私有方法 ==========

    private String generateAssetId(DiagnosisRecord record) {
        String cropPart = record.getCropId() != null ? "C" + record.getCropId() : "XX";
        return String.format("LA_%s_%s_%d",
                cropPart,
                LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd")),
                record.getId() != null ? record.getId() : System.currentTimeMillis() % 10000
        );
    }

    private String extractDiseaseName(String parsedResults) {
        if (parsedResults == null) return "";
        try {
            int idx = parsedResults.indexOf("\"disease_name_zh\"");
            if (idx >= 0) {
                int start = parsedResults.indexOf("\"", idx + 19);
                int end = parsedResults.indexOf("\"", start + 1);
                if (start >= 0 && end > start) {
                    return parsedResults.substring(start + 1, end);
                }
            }
        } catch (Exception ignored) {}
        return "";
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> buildManifest(List<TrainingDataset> items) {
        List<Map<String, Object>> manifest = new ArrayList<>();
        for (TrainingDataset td : items) {
            Map<String, Object> entry = new LinkedHashMap<>();
            entry.put("asset_id", td.getAssetId());
            entry.put("image_path", td.getImagePath());
            entry.put("label", td.getExpertLabel() != null ? td.getExpertLabel() : td.getDiseaseZh());
            entry.put("crop", td.getCropZh());
            entry.put("split", td.getTrainingSplit());
            entry.put("quality_score", td.getImageQualityScore());
            manifest.add(entry);
        }
        return manifest;
    }
}
