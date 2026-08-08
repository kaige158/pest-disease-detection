package com.laos.agri.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 诊断记录表 core.diagnosis_record — 含用户反馈+专家审核字段
 */
@Entity
@Table(name = "diagnosis_record", schema = "core")
public class DiagnosisRecord extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "task_id", unique = true, nullable = false, length = 50)
    private String taskId;

    @Column(name = "user_id")
    private Long userId;

    @Column(name = "device_uuid", length = 100)
    private String deviceUuid;

    @Column(nullable = false, length = 20)
    private String version;

    @Column(length = 10)
    private String language = "zh";

    // 图片
    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "crop_id")
    private Integer cropId;

    // 状态
    @Column(length = 30)
    private String status = "pending";  // pending/processing/completed/failed/reviewed

    // AI结果
    @Column(name = "ai_raw_response", columnDefinition = "jsonb")
    private String aiRawResponse;

    @Column(name = "parsed_results", columnDefinition = "jsonb")
    private String parsedResults;

    // 最佳匹配
    @Column(name = "top_disease_id")
    private Integer topDiseaseId;

    @Column(name = "top_confidence", precision = 5, scale = 4)
    private BigDecimal topConfidence;

    @Column(name = "confidence_level", length = 20)
    private String confidenceLevel;  // high/medium/low

    // 用户反馈
    @Column(name = "user_feedback", length = 20)
    private String userFeedback;  // confirmed/disputed/ignored

    @Column(name = "user_feedback_at")
    private LocalDateTime userFeedbackAt;

    // 专家审核
    @Column(name = "expert_reviewed")
    private Boolean expertReviewed = false;

    @Column(name = "expert_action", length = 30)
    private String expertAction;  // verified/corrected/rejected

    @Column(name = "expert_disease_id")
    private Integer expertDiseaseId;

    @Column(name = "expert_notes", columnDefinition = "TEXT")
    private String expertNotes;

    @Column(name = "reviewed_by")
    private Long reviewedBy;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    // 防控方案快照
    @Column(name = "prevention_json", columnDefinition = "jsonb")
    private String preventionJson;

    // 采集元数据
    @Column(name = "gps_latitude", precision = 10, scale = 7)
    private BigDecimal gpsLatitude;

    @Column(name = "gps_longitude", precision = 10, scale = 7)
    private BigDecimal gpsLongitude;

    @Column(name = "location_name", length = 300)
    private String locationName;

    @Column(name = "weather_info", columnDefinition = "jsonb")
    private String weatherInfo;

    @Column(name = "growth_stage", length = 50)
    private String growthStage;

    @Column(name = "plant_part", length = 50)
    private String plantPart;

    // 技术
    @Column(name = "provider_used", length = 50)
    private String providerUsed;

    @Column(name = "processing_time_ms")
    private Integer processingTimeMs;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "device_info", length = 300)
    private String deviceInfo;

    // getters/setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getTaskId() { return taskId; }
    public void setTaskId(String taskId) { this.taskId = taskId; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getDeviceUuid() { return deviceUuid; }
    public void setDeviceUuid(String deviceUuid) { this.deviceUuid = deviceUuid; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public Integer getCropId() { return cropId; }
    public void setCropId(Integer cropId) { this.cropId = cropId; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getAiRawResponse() { return aiRawResponse; }
    public void setAiRawResponse(String aiRawResponse) { this.aiRawResponse = aiRawResponse; }
    public String getParsedResults() { return parsedResults; }
    public void setParsedResults(String parsedResults) { this.parsedResults = parsedResults; }
    public Integer getTopDiseaseId() { return topDiseaseId; }
    public void setTopDiseaseId(Integer topDiseaseId) { this.topDiseaseId = topDiseaseId; }
    public BigDecimal getTopConfidence() { return topConfidence; }
    public void setTopConfidence(BigDecimal topConfidence) { this.topConfidence = topConfidence; }
    public String getConfidenceLevel() { return confidenceLevel; }
    public void setConfidenceLevel(String confidenceLevel) { this.confidenceLevel = confidenceLevel; }
    public String getUserFeedback() { return userFeedback; }
    public void setUserFeedback(String userFeedback) { this.userFeedback = userFeedback; }
    public LocalDateTime getUserFeedbackAt() { return userFeedbackAt; }
    public void setUserFeedbackAt(LocalDateTime userFeedbackAt) { this.userFeedbackAt = userFeedbackAt; }
    public Boolean getExpertReviewed() { return expertReviewed; }
    public void setExpertReviewed(Boolean expertReviewed) { this.expertReviewed = expertReviewed; }
    public String getExpertAction() { return expertAction; }
    public void setExpertAction(String expertAction) { this.expertAction = expertAction; }
    public Integer getExpertDiseaseId() { return expertDiseaseId; }
    public void setExpertDiseaseId(Integer expertDiseaseId) { this.expertDiseaseId = expertDiseaseId; }
    public String getExpertNotes() { return expertNotes; }
    public void setExpertNotes(String expertNotes) { this.expertNotes = expertNotes; }
    public Long getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Long reviewedBy) { this.reviewedBy = reviewedBy; }
    public LocalDateTime getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(LocalDateTime reviewedAt) { this.reviewedAt = reviewedAt; }
    public String getPreventionJson() { return preventionJson; }
    public void setPreventionJson(String preventionJson) { this.preventionJson = preventionJson; }
    public BigDecimal getGpsLatitude() { return gpsLatitude; }
    public void setGpsLatitude(BigDecimal gpsLatitude) { this.gpsLatitude = gpsLatitude; }
    public BigDecimal getGpsLongitude() { return gpsLongitude; }
    public void setGpsLongitude(BigDecimal gpsLongitude) { this.gpsLongitude = gpsLongitude; }
    public String getLocationName() { return locationName; }
    public void setLocationName(String locationName) { this.locationName = locationName; }
    public String getWeatherInfo() { return weatherInfo; }
    public void setWeatherInfo(String weatherInfo) { this.weatherInfo = weatherInfo; }
    public String getGrowthStage() { return growthStage; }
    public void setGrowthStage(String growthStage) { this.growthStage = growthStage; }
    public String getPlantPart() { return plantPart; }
    public void setPlantPart(String plantPart) { this.plantPart = plantPart; }
    public String getProviderUsed() { return providerUsed; }
    public void setProviderUsed(String providerUsed) { this.providerUsed = providerUsed; }
    public Integer getProcessingTimeMs() { return processingTimeMs; }
    public void setProcessingTimeMs(Integer processingTimeMs) { this.processingTimeMs = processingTimeMs; }
    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
    public String getDeviceInfo() { return deviceInfo; }
    public void setDeviceInfo(String deviceInfo) { this.deviceInfo = deviceInfo; }
}
