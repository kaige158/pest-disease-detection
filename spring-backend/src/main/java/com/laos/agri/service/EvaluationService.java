package com.laos.agri.service;

import com.laos.agri.repository.DiagnosisRecordRepository;
import com.laos.agri.repository.DiseaseRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;

/**
 * AI评估服务 — 追踪AI诊断准确率，积累评估数据
 *
 * Sprint 10.2: 基础版 — 手动触发评估
 * 未来可扩展为自动化评估管线
 */
@Service
public class EvaluationService {

    private static final Logger log = LoggerFactory.getLogger(EvaluationService.class);

    private final JdbcTemplate jdbc;
    private final DiagnosisRecordRepository diagnosisRepo;
    private final DiseaseRepository diseaseRepo;

    public EvaluationService(JdbcTemplate jdbc,
                              DiagnosisRecordRepository diagnosisRepo,
                              DiseaseRepository diseaseRepo) {
        this.jdbc = jdbc;
        this.diagnosisRepo = diagnosisRepo;
        this.diseaseRepo = diseaseRepo;
    }

    /**
     * 记录一条AI评估
     * 专家审核后自动调用
     */
    public void recordEvaluation(Long diagnosisId, Integer correctDiseaseId,
                                  Long evaluatedBy, String notes) {
        var record = diagnosisRepo.findById(diagnosisId).orElse(null);
        if (record == null) return;

        String aiPrediction = extractDiseaseName(record.getParsedResults());
        BigDecimal aiConfidence = record.getTopConfidence();
        boolean isCorrect = correctDiseaseId != null &&
                correctDiseaseId.equals(record.getTopDiseaseId());

        jdbc.update(
            "INSERT INTO expert.evaluation_record " +
            "(diagnosis_id, ai_prediction, ai_confidence, expert_disease_id, " +
            "is_correct, crop_id, provider_used, evaluated_by, evaluated_at, notes) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            diagnosisId, aiPrediction, aiConfidence, correctDiseaseId,
            isCorrect, record.getCropId(), record.getProviderUsed(),
            evaluatedBy, LocalDateTime.now(), notes
        );

        log.info("评估已记录: diagnosisId={}, correct={}", diagnosisId, isCorrect);
    }

    /**
     * 获取AI准确率统计
     */
    public Map<String, Object> getAccuracyStats(String provider, Integer cropId) {
        StringBuilder sql = new StringBuilder(
            "SELECT COUNT(*) as total, " +
            "SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) as correct " +
            "FROM expert.evaluation_record WHERE 1=1");
        List<Object> params = new ArrayList<>();

        if (provider != null && !provider.isBlank()) {
            sql.append(" AND provider_used = ?");
            params.add(provider);
        }
        if (cropId != null) {
            sql.append(" AND crop_id = ?");
            params.add(cropId);
        }

        var result = jdbc.queryForMap(sql.toString(), params.toArray());
        long total = ((Number) result.get("total")).longValue();
        long correct = ((Number) result.get("correct")).longValue();
        double accuracy = total > 0 ? (double) correct / total : 0.0;

        return Map.of(
            "total_evaluations", total,
            "correct_predictions", correct,
            "accuracy", Math.round(accuracy * 10000.0) / 100.0,
            "provider", provider != null ? provider : "all",
            "crop_id", cropId != null ? cropId : 0
        );
    }

    /**
     * 按作物分组统计准确率
     */
    public List<Map<String, Object>> getAccuracyByCrop() {
        String sql = """
            SELECT c.name_zh as crop_name, e.crop_id,
                   COUNT(*) as total,
                   SUM(CASE WHEN e.is_correct THEN 1 ELSE 0 END) as correct
            FROM expert.evaluation_record e
            LEFT JOIN core.crop c ON e.crop_id = c.id
            GROUP BY e.crop_id, c.name_zh
            ORDER BY total DESC
            """;
        return jdbc.queryForList(sql).stream()
            .map(row -> {
                long total = ((Number) row.get("total")).longValue();
                long correct = ((Number) row.get("correct")).longValue();
                double acc = total > 0 ? (double) correct / total : 0.0;
                Map<String, Object> m = new LinkedHashMap<>(row);
                m.put("accuracy", Math.round(acc * 10000.0) / 100.0);
                return m;
            })
            .toList();
    }

    private String extractDiseaseName(String parsedResults) {
        if (parsedResults == null) return "";
        try {
            // 简单提取 disease_name_zh
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
}
