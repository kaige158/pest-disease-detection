package com.laos.agri.entity;

import jakarta.persistence.*;

/**
 * 防控措施条目表 core.prevention_item
 */
@Entity
@Table(name = "prevention_item", schema = "core")
public class PreventionItem extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "plan_id", nullable = false)
    private Integer planId;

    @Column(name = "name_zh", nullable = false, length = 300)
    private String nameZh;

    @Column(name = "name_lo", length = 400)
    private String nameLo;

    @Column(name = "name_en", length = 300)
    private String nameEn;

    @Column(name = "usage_zh", columnDefinition = "TEXT")
    private String usageZh;

    @Column(name = "usage_lo", columnDefinition = "TEXT")
    private String usageLo;

    @Column(name = "usage_en", columnDefinition = "TEXT")
    private String usageEn;

    @Column(name = "notes_zh", columnDefinition = "TEXT")
    private String notesZh;

    @Column(name = "notes_lo", columnDefinition = "TEXT")
    private String notesLo;

    @Column(name = "sort_order")
    private Integer sortOrder = 0;

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public Integer getPlanId() { return planId; }
    public void setPlanId(Integer planId) { this.planId = planId; }
    public String getNameZh() { return nameZh; }
    public void setNameZh(String nameZh) { this.nameZh = nameZh; }
    public String getNameLo() { return nameLo; }
    public void setNameLo(String nameLo) { this.nameLo = nameLo; }
    public String getNameEn() { return nameEn; }
    public void setNameEn(String nameEn) { this.nameEn = nameEn; }
    public String getUsageZh() { return usageZh; }
    public void setUsageZh(String usageZh) { this.usageZh = usageZh; }
    public String getUsageLo() { return usageLo; }
    public void setUsageLo(String usageLo) { this.usageLo = usageLo; }
    public String getUsageEn() { return usageEn; }
    public void setUsageEn(String usageEn) { this.usageEn = usageEn; }
    public String getNotesZh() { return notesZh; }
    public void setNotesZh(String notesZh) { this.notesZh = notesZh; }
    public String getNotesLo() { return notesLo; }
    public void setNotesLo(String notesLo) { this.notesLo = notesLo; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
}
