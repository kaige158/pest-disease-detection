package com.laos.agri.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 病虫害字典表 core.disease — 核心知识资产
 */
@Entity
@Table(name = "disease")
public class Disease extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 20)
    private String version;

    @Column(name = "crop_id", nullable = false)
    private Integer cropId;

    // === 多语言名称 ===
    @Column(name = "name_zh", nullable = false, length = 200)
    private String nameZh;

    @Column(name = "name_lo", length = 300)
    private String nameLo;

    @Column(name = "name_en", length = 200)
    private String nameEn;

    @Column(name = "scientific_name", length = 300)
    private String scientificName;

    // === 分类 ===
    @Column(nullable = false, length = 20)
    private String type;  // disease / pest / physiological

    @Column(name = "severity_level", length = 20)
    private String severityLevel = "moderate";

    // === 症状 (多语言) ===
    @Column(name = "symptoms_zh", columnDefinition = "TEXT")
    private String symptomsZh;

    @Column(name = "symptoms_lo", columnDefinition = "TEXT")
    private String symptomsLo;

    @Column(name = "symptoms_en", columnDefinition = "TEXT")
    private String symptomsEn;

    // === 发病条件 (多语言) ===
    @Column(name = "conditions_zh", columnDefinition = "TEXT")
    private String conditionsZh;

    @Column(name = "conditions_lo", columnDefinition = "TEXT")
    private String conditionsLo;

    @Column(name = "conditions_en", columnDefinition = "TEXT")
    private String conditionsEn;

    // === 数据来源追踪 ===
    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", length = 30)
    private SourceType sourceType = SourceType.TEACHER_DATA;

    @Column(name = "collector_id")
    private Integer collectorId;

    @Column(name = "collection_time")
    private LocalDateTime collectionTime;

    // === 审核状态 ===
    @Column(name = "approval_status", length = 30)
    private String approvalStatus = "approved";  // draft/pending/approved/rejected

    @Column(name = "reviewed_by")
    private Integer reviewedBy;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    // === 搜索与元数据 ===
    @Column(length = 500)
    private String tags;

    @Column(name = "image_count")
    private Integer imageCount = 0;

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public Integer getCropId() { return cropId; }
    public void setCropId(Integer cropId) { this.cropId = cropId; }
    public String getNameZh() { return nameZh; }
    public void setNameZh(String nameZh) { this.nameZh = nameZh; }
    public String getNameLo() { return nameLo; }
    public void setNameLo(String nameLo) { this.nameLo = nameLo; }
    public String getNameEn() { return nameEn; }
    public void setNameEn(String nameEn) { this.nameEn = nameEn; }
    public String getScientificName() { return scientificName; }
    public void setScientificName(String scientificName) { this.scientificName = scientificName; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public String getSeverityLevel() { return severityLevel; }
    public void setSeverityLevel(String severityLevel) { this.severityLevel = severityLevel; }
    public String getSymptomsZh() { return symptomsZh; }
    public void setSymptomsZh(String symptomsZh) { this.symptomsZh = symptomsZh; }
    public String getSymptomsLo() { return symptomsLo; }
    public void setSymptomsLo(String symptomsLo) { this.symptomsLo = symptomsLo; }
    public String getSymptomsEn() { return symptomsEn; }
    public void setSymptomsEn(String symptomsEn) { this.symptomsEn = symptomsEn; }
    public String getConditionsZh() { return conditionsZh; }
    public void setConditionsZh(String conditionsZh) { this.conditionsZh = conditionsZh; }
    public String getConditionsLo() { return conditionsLo; }
    public void setConditionsLo(String conditionsLo) { this.conditionsLo = conditionsLo; }
    public String getConditionsEn() { return conditionsEn; }
    public void setConditionsEn(String conditionsEn) { this.conditionsEn = conditionsEn; }
    public SourceType getSourceType() { return sourceType; }
    public void setSourceType(SourceType sourceType) { this.sourceType = sourceType; }
    public Integer getCollectorId() { return collectorId; }
    public void setCollectorId(Integer collectorId) { this.collectorId = collectorId; }
    public LocalDateTime getCollectionTime() { return collectionTime; }
    public void setCollectionTime(LocalDateTime collectionTime) { this.collectionTime = collectionTime; }
    public String getApprovalStatus() { return approvalStatus; }
    public void setApprovalStatus(String approvalStatus) { this.approvalStatus = approvalStatus; }
    public Integer getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Integer reviewedBy) { this.reviewedBy = reviewedBy; }
    public LocalDateTime getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(LocalDateTime reviewedAt) { this.reviewedAt = reviewedAt; }
    public String getTags() { return tags; }
    public void setTags(String tags) { this.tags = tags; }
    public Integer getImageCount() { return imageCount; }
    public void setImageCount(Integer imageCount) { this.imageCount = imageCount; }
}
