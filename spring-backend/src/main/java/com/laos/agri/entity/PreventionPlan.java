package com.laos.agri.entity;

import jakarta.persistence.*;

/**
 * 防控方案分类表 core.prevention_plan
 * 每种病虫害有多个方案类型: chemical/biological/physical/cultivation
 */
@Entity
@Table(name = "prevention_plan")
public class PreventionPlan extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "disease_id", nullable = false)
    private Integer diseaseId;

    @Column(name = "plan_type", nullable = false, length = 30)
    private String planType;  // chemical/biological/physical/cultivation

    @Column(name = "title_zh", nullable = false, length = 200)
    private String titleZh;

    @Column(name = "title_lo", length = 300)
    private String titleLo;

    @Column(name = "title_en", length = 200)
    private String titleEn;

    @Column(name = "sort_order")
    private Integer sortOrder = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", length = 30)
    private SourceType sourceType = SourceType.TEACHER_DATA;

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public Integer getDiseaseId() { return diseaseId; }
    public void setDiseaseId(Integer diseaseId) { this.diseaseId = diseaseId; }
    public String getPlanType() { return planType; }
    public void setPlanType(String planType) { this.planType = planType; }
    public String getTitleZh() { return titleZh; }
    public void setTitleZh(String titleZh) { this.titleZh = titleZh; }
    public String getTitleLo() { return titleLo; }
    public void setTitleLo(String titleLo) { this.titleLo = titleLo; }
    public String getTitleEn() { return titleEn; }
    public void setTitleEn(String titleEn) { this.titleEn = titleEn; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
    public SourceType getSourceType() { return sourceType; }
    public void setSourceType(SourceType sourceType) { this.sourceType = sourceType; }
}
