package com.laos.agri.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 病虫害图片表 core.disease_image — 核心数据资产
 * 每张图片都是科研数据，记录完整采集元数据
 */
@Entity
@Table(name = "disease_image")
public class DiseaseImage extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // === 图片本身 ===
    @Column(name = "image_url", nullable = false, length = 500)
    private String imageUrl;

    @Column(name = "thumbnail_url", length = 500)
    private String thumbnailUrl;

    @Column(name = "image_hash", length = 64)
    private String imageHash;  // SHA256去重

    @Column(name = "file_size_bytes")
    private Integer fileSizeBytes;

    // === 关联 ===
    @Column(nullable = false, length = 20)
    private String version;

    @Column(name = "crop_id")
    private Integer cropId;

    @Column(name = "disease_id")
    private Integer diseaseId;

    @Column(name = "diagnosis_id")
    private Long diagnosisId;

    // === 图片分类 ===
    @Column(name = "image_type", length = 30)
    private String imageType = "symptom";

    @Column(name = "image_source", length = 30)
    private String imageSource = "TEACHER_DATA";

    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", length = 30)
    private SourceType sourceType = SourceType.TEACHER_DATA;

    // === 采集元数据 ===
    @Column(name = "gps_latitude", precision = 10, scale = 7)
    private BigDecimal gpsLatitude;

    @Column(name = "gps_longitude", precision = 10, scale = 7)
    private BigDecimal gpsLongitude;

    @Column(name = "location_name", length = 300)
    private String locationName;

    @Column(name = "taken_at")
    private LocalDateTime takenAt;

    // === 生长信息 ===
    @Column(name = "growth_stage", length = 50)
    private String growthStage;

    @Column(name = "plant_part", length = 50)
    private String plantPart;

    // === 环境信息 ===
    @Column(name = "weather_condition", length = 50)
    private String weatherCondition;

    @Column(precision = 5, scale = 2)
    private BigDecimal temperature;

    @Column(precision = 5, scale = 2)
    private BigDecimal humidity;

    // === 采集者 ===
    @Column(name = "collector_id")
    private Integer collectorId;

    @Column(name = "collection_time")
    private LocalDateTime collectionTime;

    @Column(name = "device_model", length = 100)
    private String deviceModel;

    // === AI标注 ===
    @Column(name = "ai_label", length = 300)
    private String aiLabel;

    @Column(name = "ai_confidence", precision = 5, scale = 4)
    private BigDecimal aiConfidence;

    // === 人工标注 ===
    @Column(name = "human_label", length = 300)
    private String humanLabel;

    @Column(name = "human_label_by")
    private Integer humanLabelBy;

    @Column(name = "label_status", length = 30)
    private String labelStatus = "ai_only";  // ai_only/verified/corrected/disputed/rejected

    @Column(name = "label_notes", columnDefinition = "TEXT")
    private String labelNotes;

    // === 质量 ===
    @Column(name = "image_quality_score", precision = 3, scale = 2)
    private BigDecimal imageQualityScore;

    @Column(name = "is_usable")
    private Boolean isUsable = true;

    @Column(name = "reject_reason", length = 300)
    private String rejectReason;

    // === 数据质量等级 ===
    @Enumerated(EnumType.STRING)
    @Column(name = "data_grade", length = 5)
    private DataGrade dataGrade = DataGrade.B;

    // === 审核 ===
    @Column(name = "approval_status", length = 30)
    private String approvalStatus = "pending";

    @Column(name = "reviewed_by")
    private Integer reviewedBy;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    // === 权限 ===
    @Column(length = 10)
    private String language = "zh";

    @Column(name = "is_public")
    private Boolean isPublic = false;

    // ===== getters/setters =====
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }
    public String getImageHash() { return imageHash; }
    public void setImageHash(String imageHash) { this.imageHash = imageHash; }
    public Integer getFileSizeBytes() { return fileSizeBytes; }
    public void setFileSizeBytes(Integer fileSizeBytes) { this.fileSizeBytes = fileSizeBytes; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public Integer getCropId() { return cropId; }
    public void setCropId(Integer cropId) { this.cropId = cropId; }
    public Integer getDiseaseId() { return diseaseId; }
    public void setDiseaseId(Integer diseaseId) { this.diseaseId = diseaseId; }
    public Long getDiagnosisId() { return diagnosisId; }
    public void setDiagnosisId(Long diagnosisId) { this.diagnosisId = diagnosisId; }
    public String getImageType() { return imageType; }
    public void setImageType(String imageType) { this.imageType = imageType; }
    public String getImageSource() { return imageSource; }
    public void setImageSource(String imageSource) { this.imageSource = imageSource; }
    public SourceType getSourceType() { return sourceType; }
    public void setSourceType(SourceType sourceType) { this.sourceType = sourceType; }
    public BigDecimal getGpsLatitude() { return gpsLatitude; }
    public void setGpsLatitude(BigDecimal gpsLatitude) { this.gpsLatitude = gpsLatitude; }
    public BigDecimal getGpsLongitude() { return gpsLongitude; }
    public void setGpsLongitude(BigDecimal gpsLongitude) { this.gpsLongitude = gpsLongitude; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    public LocalDateTime getTakenAt() { return takenAt; }
    public void setTakenAt(LocalDateTime takenAt) { this.takenAt = takenAt; }
    public String getGrowthStage() { return growthStage; }
    public void setGrowthStage(String growthStage) { this.growthStage = growthStage; }
    public String getPlantPart() { return plantPart; }
    public void setPlantPart(String plantPart) { this.plantPart = plantPart; }
    public String getWeatherCondition() { return weatherCondition; }
    public void setWeatherCondition(String weatherCondition) { this.weatherCondition = weatherCondition; }
    public BigDecimal getTemperature() { return temperature; }
    public void setTemperature(BigDecimal temperature) { this.temperature = temperature; }
    public BigDecimal getHumidity() { return humidity; }
    public void setHumidity(BigDecimal humidity) { this.humidity = humidity; }
    public Integer getCollectorId() { return collectorId; }
    public void setCollectorId(Integer collectorId) { this.collectorId = collectorId; }
    public LocalDateTime getCollectionTime() { return collectionTime; }
    public void setCollectionTime(LocalDateTime collectionTime) { this.collectionTime = collectionTime; }
    public String getDeviceModel() { return deviceModel; }
    public void setDeviceModel(String deviceModel) { this.deviceModel = deviceModel; }
    public String getAiLabel() { return aiLabel; }
    public void setAiLabel(String aiLabel) { this.aiLabel = aiLabel; }
    public BigDecimal getAiConfidence() { return aiConfidence; }
    public void setAiConfidence(BigDecimal aiConfidence) { this.aiConfidence = aiConfidence; }
    public String getHumanLabel() { return humanLabel; }
    public void setHumanLabel(String humanLabel) { this.humanLabel = humanLabel; }
    public Integer getHumanLabelBy() { return humanLabelBy; }
    public void setHumanLabelBy(Integer humanLabelBy) { this.humanLabelBy = humanLabelBy; }
    public String getLabelStatus() { return labelStatus; }
    public void setLabelStatus(String labelStatus) { this.labelStatus = labelStatus; }
    public String getLabelNotes() { return labelNotes; }
    public void setLabelNotes(String labelNotes) { this.labelNotes = labelNotes; }
    public BigDecimal getImageQualityScore() { return imageQualityScore; }
    public void setImageQualityScore(BigDecimal imageQualityScore) { this.imageQualityScore = imageQualityScore; }
    public Boolean getIsUsable() { return isUsable; }
    public void setIsUsable(Boolean isUsable) { this.isUsable = isUsable; }
    public String getRejectReason() { return rejectReason; }
    public void setRejectReason(String rejectReason) { this.rejectReason = rejectReason; }
    public DataGrade getDataGrade() { return dataGrade; }
    public void setDataGrade(DataGrade dataGrade) { this.dataGrade = dataGrade; }
    public String getApprovalStatus() { return approvalStatus; }
    public void setApprovalStatus(String approvalStatus) { this.approvalStatus = approvalStatus; }
    public Integer getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Integer reviewedBy) { this.reviewedBy = reviewedBy; }
    public LocalDateTime getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(LocalDateTime reviewedAt) { this.reviewedAt = reviewedAt; }
    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }
    public Boolean getIsPublic() { return isPublic; }
    public void setIsPublic(Boolean isPublic) { this.isPublic = isPublic; }
}
