package com.laos.agri.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 训练数据资产表 extension.training_dataset
 *
 * Sprint 11: 农业AI核心数据资产。只有 expert_confirm=true + 质量达标 的数据才能导出训练。
 * 原则: AI识别默认 training_ready=false → 专家审核通过 → training_ready=true
 */
@Entity
@Table(name = "training_dataset", schema = "extension")
public class TrainingDataset {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "asset_id", unique = true, nullable = false, length = 100)
    private String assetId;

    // 版本和语言
    @Column(length = 20)
    private String version = "vegetable";

    @Column(length = 10)
    private String language = "zh";  // LA_TOMATO_2026_001

    // 来源关联
    @Column(name = "image_id")
    private Long imageId;

    @Column(name = "diagnosis_id")
    private Long diagnosisId;

    // 农业信息
    @Column(name = "crop_id")
    private Integer cropId;

    @Column(name = "crop_zh", length = 100)
    private String cropZh;

    @Column(name = "crop_lo", length = 200)
    private String cropLo;

    @Column(name = "disease_id")
    private Integer diseaseId;

    @Column(name = "disease_zh", length = 300)
    private String diseaseZh;

    @Column(name = "disease_lo", length = 300)
    private String diseaseLo;

    @Column(name = "disease_type", length = 30)
    private String diseaseType = "disease";

    @Column(name = "plant_part", length = 50)
    private String plantPart;

    @Column(length = 20)
    private String severity = "moderate";

    // 地理信息
    @Column(length = 10)
    private String country = "LA";

    @Column(name = "location_name", length = 300)
    private String locationName;

    @Column(name = "gps_latitude", precision = 10, scale = 7)
    private BigDecimal gpsLatitude;

    @Column(name = "gps_longitude", precision = 10, scale = 7)
    private BigDecimal gpsLongitude;

    // 生长信息
    @Column(name = "growth_stage", length = 50)
    private String growthStage;

    @Column(length = 20)
    private String season;

    // AI预测
    @Column(name = "ai_prediction", length = 300)
    private String aiPrediction;

    @Column(name = "ai_confidence", precision = 5, scale = 4)
    private BigDecimal aiConfidence;

    @Column(name = "ai_model", length = 100)
    private String aiModel;

    @Column(name = "ai_raw_response", columnDefinition = "TEXT")
    private String aiRawResponse;

    // 专家确认（核心⭐）
    @Column(name = "expert_label", length = 300)
    private String expertLabel;

    @Column(name = "expert_label_lo", length = 300)
    private String expertLabelLo;

    @Column(name = "expert_confirm")
    private Boolean expertConfirm = false;

    @Column(name = "expert_id")
    private Long expertId;

    @Column(name = "expert_notes", columnDefinition = "TEXT")
    private String expertNotes;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    // 训练就绪标记 ⭐⭐⭐
    @Column(name = "training_ready")
    private Boolean trainingReady = false;

    @Column(name = "training_split", length = 20)
    private String trainingSplit;  // train/val/test

    // 图片信息
    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Column(name = "image_quality_score", precision = 3, scale = 1)
    private BigDecimal imageQualityScore;

    @Column(name = "image_width")
    private Integer imageWidth;

    @Column(name = "image_height")
    private Integer imageHeight;

    @Column(name = "file_size_bytes")
    private Long fileSizeBytes;

    // 导出元数据
    @Column(name = "export_batch", length = 100)
    private String exportBatch;

    @Column(name = "exported_at")
    private LocalDateTime exportedAt;

    @Column(name = "is_active")
    private Boolean isActive = true;

    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();

    @Column(name = "updated_at")
    private LocalDateTime updatedAt = LocalDateTime.now();

    // ===== getters/setters =====
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getAssetId() { return assetId; }
    public void setAssetId(String assetId) { this.assetId = assetId; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }
    public Long getImageId() { return imageId; }
    public void setImageId(Long imageId) { this.imageId = imageId; }
    public Long getDiagnosisId() { return diagnosisId; }
    public void setDiagnosisId(Long diagnosisId) { this.diagnosisId = diagnosisId; }
    public Integer getCropId() { return cropId; }
    public void setCropId(Integer cropId) { this.cropId = cropId; }
    public String getCropZh() { return cropZh; }
    public void setCropZh(String cropZh) { this.cropZh = cropZh; }
    public String getCropLo() { return cropLo; }
    public void setCropLo(String cropLo) { this.cropLo = cropLo; }
    public Integer getDiseaseId() { return diseaseId; }
    public void setDiseaseId(Integer diseaseId) { this.diseaseId = diseaseId; }
    public String getDiseaseZh() { return diseaseZh; }
    public void setDiseaseZh(String diseaseZh) { this.diseaseZh = diseaseZh; }
    public String getDiseaseLo() { return diseaseLo; }
    public void setDiseaseLo(String diseaseLo) { this.diseaseLo = diseaseLo; }
    public String getDiseaseType() { return diseaseType; }
    public void setDiseaseType(String diseaseType) { this.diseaseType = diseaseType; }
    public String getPlantPart() { return plantPart; }
    public void setPlantPart(String plantPart) { this.plantPart = plantPart; }
    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }
    public String getCountry() { return country; }
    public void setCountry(String country) { this.country = country; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    public BigDecimal getGpsLatitude() { return gpsLatitude; }
    public void setGpsLatitude(BigDecimal gpsLatitude) { this.gpsLatitude = gpsLatitude; }
    public BigDecimal getGpsLongitude() { return gpsLongitude; }
    public void setGpsLongitude(BigDecimal gpsLongitude) { this.gpsLongitude = gpsLongitude; }
    public String getGrowthStage() { return growthStage; }
    public void setGrowthStage(String growthStage) { this.growthStage = growthStage; }
    public String getSeason() { return season; }
    public void setSeason(String season) { this.season = season; }
    public String getAiPrediction() { return aiPrediction; }
    public void setAiPrediction(String aiPrediction) { this.aiPrediction = aiPrediction; }
    public BigDecimal getAiConfidence() { return aiConfidence; }
    public void setAiConfidence(BigDecimal aiConfidence) { this.aiConfidence = aiConfidence; }
    public String getAiModel() { return aiModel; }
    public void setAiModel(String aiModel) { this.aiModel = aiModel; }
    public String getAiRawResponse() { return aiRawResponse; }
    public void setAiRawResponse(String aiRawResponse) { this.aiRawResponse = aiRawResponse; }
    public String getExpertLabel() { return expertLabel; }
    public void setExpertLabel(String expertLabel) { this.expertLabel = expertLabel; }
    public String getExpertLabelLo() { return expertLabelLo; }
    public void setExpertLabelLo(String expertLabelLo) { this.expertLabelLo = expertLabelLo; }
    public Boolean getExpertConfirm() { return expertConfirm; }
    public void setExpertConfirm(Boolean expertConfirm) { this.expertConfirm = expertConfirm; }
    public Long getExpertId() { return expertId; }
    public void setExpertId(Long expertId) { this.expertId = expertId; }
    public String getExpertNotes() { return expertNotes; }
    public void setExpertNotes(String expertNotes) { this.expertNotes = expertNotes; }
    public LocalDateTime getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(LocalDateTime reviewedAt) { this.reviewedAt = reviewedAt; }
    public Boolean getTrainingReady() { return trainingReady; }
    public void setTrainingReady(Boolean trainingReady) { this.trainingReady = trainingReady; }
    public String getTrainingSplit() { return trainingSplit; }
    public void setTrainingSplit(String trainingSplit) { this.trainingSplit = trainingSplit; }
    public String getImagePath() { return imagePath; }
    public void setImagePath(String imagePath) { this.imagePath = imagePath; }
    public BigDecimal getImageQualityScore() { return imageQualityScore; }
    public void setImageQualityScore(BigDecimal imageQualityScore) { this.imageQualityScore = imageQualityScore; }
    public Integer getImageWidth() { return imageWidth; }
    public void setImageWidth(Integer imageWidth) { this.imageWidth = imageWidth; }
    public Integer getImageHeight() { return imageHeight; }
    public void setImageHeight(Integer imageHeight) { this.imageHeight = imageHeight; }
    public Long getFileSizeBytes() { return fileSizeBytes; }
    public void setFileSizeBytes(Long fileSizeBytes) { this.fileSizeBytes = fileSizeBytes; }
    public String getExportBatch() { return exportBatch; }
    public void setExportBatch(String exportBatch) { this.exportBatch = exportBatch; }
    public LocalDateTime getExportedAt() { return exportedAt; }
    public void setExportedAt(LocalDateTime exportedAt) { this.exportedAt = exportedAt; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
