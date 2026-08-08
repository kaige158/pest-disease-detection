package com.laos.agri.entity;

import jakarta.persistence.*;

/**
 * 作物分类表 core.crop_category
 */
@Entity
@Table(name = "crop_category", schema = "core")
public class CropCategory extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 20)
    private String version;  // vegetable/fruit

    @Column(name = "name_zh", nullable = false, length = 100)
    private String nameZh;

    @Column(name = "name_lo", length = 200)
    private String nameLo;

    @Column(name = "name_en", length = 100)
    private String nameEn;

    @Column(name = "parent_id")
    private Integer parentId;

    @Column(name = "sort_order")
    private Integer sortOrder = 0;

    @Column(name = "icon_url", length = 500)
    private String iconUrl;

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public String getNameZh() { return nameZh; }
    public void setNameZh(String nameZh) { this.nameZh = nameZh; }
    public String getNameLo() { return nameLo; }
    public void setNameLo(String nameLo) { this.nameLo = nameLo; }
    public String getNameEn() { return nameEn; }
    public void setNameEn(String nameEn) { this.nameEn = nameEn; }
    public Integer getParentId() { return parentId; }
    public void setParentId(Integer parentId) { this.parentId = parentId; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
    public String getIconUrl() { return iconUrl; }
    public void setIconUrl(String iconUrl) { this.iconUrl = iconUrl; }
}
