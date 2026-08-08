package com.laos.agri.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 知识库文章表 core.knowledge_article
 */
@Entity
@Table(name = "knowledge_article")
public class KnowledgeArticle extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false, length = 20)
    private String version;

    @Column(name = "crop_id")
    private Integer cropId;

    @Column(name = "disease_id")
    private Integer diseaseId;

    @Column(name = "article_type", nullable = false, length = 30)
    private String articleType;  // disease/crop/general/faq/news

    @Column(name = "title_zh", nullable = false, length = 300)
    private String titleZh;

    @Column(name = "title_lo", length = 400)
    private String titleLo;

    @Column(name = "title_en", length = 300)
    private String titleEn;

    @Column(name = "content_zh", columnDefinition = "TEXT")
    private String contentZh;

    @Column(name = "content_lo", columnDefinition = "TEXT")
    private String contentLo;

    @Column(name = "content_en", columnDefinition = "TEXT")
    private String contentEn;

    @Column(length = 500)
    private String tags;

    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", length = 30)
    private SourceType sourceType = SourceType.TEACHER_DATA;

    @Column(name = "is_published")
    private Boolean isPublished = false;

    @Column(name = "published_at")
    private LocalDateTime publishedAt;

    @Column(name = "view_count")
    private Integer viewCount = 0;

    @Column(name = "author_id")
    private Long authorId;

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public String getVersion() { return version; }
    public void setVersion(String version) { this.version = version; }
    public Integer getCropId() { return cropId; }
    public void setCropId(Integer cropId) { this.cropId = cropId; }
    public Integer getDiseaseId() { return diseaseId; }
    public void setDiseaseId(Integer diseaseId) { this.diseaseId = diseaseId; }
    public String getArticleType() { return articleType; }
    public void setArticleType(String articleType) { this.articleType = articleType; }
    public String getTitleZh() { return titleZh; }
    public void setTitleZh(String titleZh) { this.titleZh = titleZh; }
    public String getTitleLo() { return titleLo; }
    public void setTitleLo(String titleLo) { this.titleLo = titleLo; }
    public String getTitleEn() { return titleEn; }
    public void setTitleEn(String titleEn) { this.titleEn = titleEn; }
    public String getContentZh() { return contentZh; }
    public void setContentZh(String contentZh) { this.contentZh = contentZh; }
    public String getContentLo() { return contentLo; }
    public void setContentLo(String contentLo) { this.contentLo = contentLo; }
    public String getContentEn() { return contentEn; }
    public void setContentEn(String contentEn) { this.contentEn = contentEn; }
    public String getTags() { return tags; }
    public void setTags(String tags) { this.tags = tags; }
    public SourceType getSourceType() { return sourceType; }
    public void setSourceType(SourceType sourceType) { this.sourceType = sourceType; }
    public Boolean getIsPublished() { return isPublished; }
    public void setIsPublished(Boolean isPublished) { this.isPublished = isPublished; }
    public LocalDateTime getPublishedAt() { return publishedAt; }
    public void setPublishedAt(LocalDateTime publishedAt) { this.publishedAt = publishedAt; }
    public Integer getViewCount() { return viewCount; }
    public void setViewCount(Integer viewCount) { this.viewCount = viewCount; }
    public Long getAuthorId() { return authorId; }
    public void setAuthorId(Long authorId) { this.authorId = authorId; }
}
