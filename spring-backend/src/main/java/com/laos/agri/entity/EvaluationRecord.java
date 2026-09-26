package com.laos.agri.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * AI 诊断质量评估记录 expert.evaluation_record
 *
 * <p>用途：把"专家判定的正确答案"与"AI 当时的判断"并排存下来，
 * 用于统计模型准确率、按 Provider/作物对比效果，是平台数据资产的一部分。
 *
 * <p>为什么以前只有 SQL 没有实体：这张表一直由 {@code EvaluationService}
 * 用原生 SQL 读写。但演示档（H2）靠 Hibernate 建表，没有实体就不会建表 ——
 * 于是数据统计页的准确率接口在 demo 下直接 500（表不存在）。
 * 补上实体后，demo 与生产（{@code database/evaluation_record.sql}）都能建出这张表。
 */
@Entity
@Table(name = "evaluation_record", schema = "expert")
public class EvaluationRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 被评估的诊断记录 */
    @Column(name = "diagnosis_id")
    private Long diagnosisId;

    /** AI 预测的病虫害名 */
    @Column(name = "ai_prediction", length = 300)
    private String aiPrediction;

    @Column(name = "ai_confidence", precision = 5, scale = 4)
    private BigDecimal aiConfidence;

    /** 专家标注的正确答案 */
    @Column(name = "expert_label", length = 300)
    private String expertLabel;

    @Column(name = "expert_disease_id")
    private Integer expertDiseaseId;

    /** AI 第一选择是否正确 —— 准确率统计的分母口径 */
    @Column(name = "is_correct", nullable = false)
    private Boolean isCorrect;

    /** AI 前三选择中是否包含正确答案 */
    @Column(name = "is_top3_correct")
    private Boolean isTop3Correct;

    @Column(name = "crop_id")
    private Integer cropId;

    /** 当时使用的 AI 通道，用于按模型比较效果 */
    @Column(name = "provider_used", length = 50)
    private String providerUsed;

    /** 评估批次，用于观察"换了模型/Prompt 之后准确率有没有变好" */
    @Column(name = "evaluation_batch", length = 100)
    private String evaluationBatch;

    @Column(name = "evaluated_by")
    private Long evaluatedBy;

    @Column(name = "evaluated_at")
    private LocalDateTime evaluatedAt;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    // ===== getters/setters =====
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getDiagnosisId() { return diagnosisId; }
    public void setDiagnosisId(Long diagnosisId) { this.diagnosisId = diagnosisId; }
    public String getAiPrediction() { return aiPrediction; }
    public void setAiPrediction(String aiPrediction) { this.aiPrediction = aiPrediction; }
    public BigDecimal getAiConfidence() { return aiConfidence; }
    public void setAiConfidence(BigDecimal aiConfidence) { this.aiConfidence = aiConfidence; }
    public String getExpertLabel() { return expertLabel; }
    public void setExpertLabel(String expertLabel) { this.expertLabel = expertLabel; }
    public Integer getExpertDiseaseId() { return expertDiseaseId; }
    public void setExpertDiseaseId(Integer expertDiseaseId) { this.expertDiseaseId = expertDiseaseId; }
    public Boolean getIsCorrect() { return isCorrect; }
    public void setIsCorrect(Boolean isCorrect) { this.isCorrect = isCorrect; }
    public Boolean getIsTop3Correct() { return isTop3Correct; }
    public void setIsTop3Correct(Boolean isTop3Correct) { this.isTop3Correct = isTop3Correct; }
    public Integer getCropId() { return cropId; }
    public void setCropId(Integer cropId) { this.cropId = cropId; }
    public String getProviderUsed() { return providerUsed; }
    public void setProviderUsed(String providerUsed) { this.providerUsed = providerUsed; }
    public String getEvaluationBatch() { return evaluationBatch; }
    public void setEvaluationBatch(String evaluationBatch) { this.evaluationBatch = evaluationBatch; }
    public Long getEvaluatedBy() { return evaluatedBy; }
    public void setEvaluatedBy(Long evaluatedBy) { this.evaluatedBy = evaluatedBy; }
    public LocalDateTime getEvaluatedAt() { return evaluatedAt; }
    public void setEvaluatedAt(LocalDateTime evaluatedAt) { this.evaluatedAt = evaluatedAt; }
    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
