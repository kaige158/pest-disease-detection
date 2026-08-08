package com.laos.agri.entity;

import jakarta.persistence.*;

/**
 * 多语言资源表 core.language_resource
 * 支持中文/老挝语/英语/泰语/越南语扩展
 */
@Entity
@Table(name = "language_resource",
       uniqueConstraints = @UniqueConstraint(columnNames = {"resource_key", "module"}))
public class LanguageResource extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "resource_key", nullable = false, length = 200)
    private String resourceKey;

    @Column(nullable = false, length = 50)
    private String module;  // ui/knowledge/prevention/system

    @Column(name = "text_zh", length = 2000)
    private String textZh;

    @Column(name = "text_lo", length = 2000)
    private String textLo;

    @Column(name = "text_en", length = 2000)
    private String textEn;

    @Column(name = "text_th", length = 2000)
    private String textTh;  // 泰语(预留)

    @Column(name = "text_vi", length = 2000)
    private String textVi;  // 越南语(预留)

    // getters/setters
    public Integer getId() { return id; }
    public void setId(Integer id) { this.id = id; }
    public String getResourceKey() { return resourceKey; }
    public void setResourceKey(String resourceKey) { this.resourceKey = resourceKey; }
    public String getModule() { return module; }
    public void setModule(String module) { this.module = module; }
    public String getTextZh() { return textZh; }
    public void setTextZh(String textZh) { this.textZh = textZh; }
    public String getTextLo() { return textLo; }
    public void setTextLo(String textLo) { this.textLo = textLo; }
    public String getTextEn() { return textEn; }
    public void setTextEn(String textEn) { this.textEn = textEn; }
    public String getTextTh() { return textTh; }
    public void setTextTh(String textTh) { this.textTh = textTh; }
    public String getTextVi() { return textVi; }
    public void setTextVi(String textVi) { this.textVi = textVi; }

    /** 根据语言代码获取文本 */
    public String getText(String lang) {
        return switch (lang) {
            case "lo" -> textLo;
            case "en" -> textEn;
            case "th" -> textTh;
            case "vi" -> textVi;
            default -> textZh;
        };
    }
}
