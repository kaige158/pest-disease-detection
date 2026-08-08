package com.laos.agri.entity;

import jakarta.persistence.*;

/**
 * 作物表 core.crop
 */
@Entity
@Table(name = "crop")
public class Crop extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 20)
    private String version;

    @Column(name = "category_id", nullable = false)
    private Integer categoryId;

    @Column(name = "name_zh", nullable = false, length = 100)
    private String nameZh;

    @Column(name = "name_lo", length = 200)
    private String nameLo;

    @Column(name = "name_en", length = 100)
    private String nameEn;

    @Column(name = "scientific_name", length = 200)
    private String scientificName;

    @Column(name = "description_zh", columnDefinition = "TEXT")
    private String descriptionZh;

    @Column(name = "description_lo", columnDefinition = "TEXT")
    private String descriptionLo;

    @Column(name = "description_en", columnDefinition = "TEXT")
    private String descriptionEn;

    @Column(name = "planting_info_zh", columnDefinition = "TEXT")
    private String plantingInfoZh;

    @Column(name = "planting_info_lo", columnDefinition = "TEXT")
    private String plantingInfoLo;

    @Column(name = "icon_url", length = 500)
    private String iconUrl;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "disease_count")
    private Integer diseaseCount = 0;

    @Column(name = "sort_order")
    private Integer sortOrder = 0;

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public Integer getCategoryId() { return categoryId; }
    public void setCategoryId(Integer categoryId) { this.categoryId = categoryId; }
    public String getNameZh() { return nameZh; }
    public void setNameZh(String nameZh) { this.nameZh = nameZh; }
    public String getNameLo() { return nameLo; }
    public void setNameLo(String nameLo) { this.nameLo = nameLo; }
    public String getNameEn() { return nameEn; }
    public void setNameEn(String nameEn) { this.nameEn = nameEn; }
    public String getScientificName() { return scientificName; }
    public void setScientificName(String scientificName) { this.scientificName = scientificName; }
    public String getDescriptionZh() { return descriptionZh; }
    public void setDescriptionZh(String descriptionZh) { this.descriptionZh = descriptionZh; }
    public String getDescriptionLo() { return descriptionLo; }
    public void setDescriptionLo(String descriptionLo) { this.descriptionLo = descriptionLo; }
    public String getDescriptionEn() { return descriptionEn; }
    public void setDescriptionEn(String descriptionEn) { this.descriptionEn = descriptionEn; }
    public String getPlantingInfoZh() { return plantingInfoZh; }
    public void setPlantingInfoZh(String plantingInfoZh) { this.plantingInfoZh = plantingInfoZh; }
    public String getPlantingInfoLo() { return plantingInfoLo; }
    public void setPlantingInfoLo(String plantingInfoLo) { this.plantingInfoLo = plantingInfoLo; }
    public String getIconUrl() { return iconUrl; }
    public void setIconUrl(String iconUrl) { this.iconUrl = iconUrl; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public Integer getDiseaseCount() { return diseaseCount; }
    public void setDiseaseCount(Integer diseaseCount) { this.diseaseCount = diseaseCount; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
}
