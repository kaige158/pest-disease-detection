package com.laos.agri.entity;

import jakarta.persistence.*;

/**
 * AI Provider 通道配置 — 管理员可在后台可视化修改，改完即生效
 *
 * <p>与 Python AI 服务的契约：AI 服务在每次识别时读取本表 is_active=true 的行，
 * 因此后台保存后无需重启任何服务。
 *
 * <p>安全约定：
 * <ul>
 *   <li>{@code apiKeyEnc} 只存 AES-256-GCM 密文，密钥来自环境变量 {@code AI_KEY_SECRET}</li>
 *   <li>{@code apiKeyMasked} 是脱敏串，用于界面展示，接口永不回传明文</li>
 * </ul>
 *
 * <p>注意：{@code isActive} 继承自 {@link BaseEntity}，在业务上表示
 * "该通道当前生效"（全表最多一行为 TRUE，由应用层保证）。
 */
@Entity
@Table(name = "ai_provider_config", schema = "core")
public class AiProviderConfig extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** gemini / kimi / openai / claude / custom / mock */
    @Column(nullable = false, length = 30)
    private String provider;

    /** 展示名，如 "Google Gemini（免费额度）" */
    @Column(name = "display_name", length = 100)
    private String displayName;

    /** API Key 密文（AES-256-GCM / Base64），仅服务端可解 */
    @Column(name = "api_key_enc", columnDefinition = "TEXT")
    private String apiKeyEnc;

    /** 脱敏展示，如 "AIza****abcd" */
    @Column(name = "api_key_masked", length = 60)
    private String apiKeyMasked;

    /** 自定义 / 代理地址，留空用官方地址 */
    @Column(name = "base_url", length = 300)
    private String baseUrl;

    @Column(length = 100)
    private String model;

    @Column(name = "max_tokens")
    private Integer maxTokens = 2000;

    @Column(precision = 3, scale = 2)
    private java.math.BigDecimal temperature = new java.math.BigDecimal("0.30");

    @Column(name = "timeout_seconds")
    private Integer timeoutSeconds = 60;

    @Column(name = "last_test_at")
    private java.time.LocalDateTime lastTestAt;

    @Column(name = "last_test_ok")
    private Boolean lastTestOk;

    @Column(name = "last_test_ms")
    private Integer lastTestMs;

    @Column(name = "last_test_msg", length = 500)
    private String lastTestMsg;

    @Column(length = 300)
    private String remark;

    // ===== getters / setters =====
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getProvider() { return provider; }
    public void setProvider(String provider) { this.provider = provider; }
    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }
    public String getApiKeyEnc() { return apiKeyEnc; }
    public void setApiKeyEnc(String apiKeyEnc) { this.apiKeyEnc = apiKeyEnc; }
    public String getApiKeyMasked() { return apiKeyMasked; }
    public void setApiKeyMasked(String apiKeyMasked) { this.apiKeyMasked = apiKeyMasked; }
    public String getBaseUrl() { return baseUrl; }
    public void setBaseUrl(String baseUrl) { this.baseUrl = baseUrl; }
    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }
    public Integer getMaxTokens() { return maxTokens; }
    public void setMaxTokens(Integer maxTokens) { this.maxTokens = maxTokens; }
    public java.math.BigDecimal getTemperature() { return temperature; }
    public void setTemperature(java.math.BigDecimal temperature) { this.temperature = temperature; }
    public Integer getTimeoutSeconds() { return timeoutSeconds; }
    public void setTimeoutSeconds(Integer timeoutSeconds) { this.timeoutSeconds = timeoutSeconds; }
    public java.time.LocalDateTime getLastTestAt() { return lastTestAt; }
    public void setLastTestAt(java.time.LocalDateTime lastTestAt) { this.lastTestAt = lastTestAt; }
    public Boolean getLastTestOk() { return lastTestOk; }
    public void setLastTestOk(Boolean lastTestOk) { this.lastTestOk = lastTestOk; }
    public Integer getLastTestMs() { return lastTestMs; }
    public void setLastTestMs(Integer lastTestMs) { this.lastTestMs = lastTestMs; }
    public String getLastTestMsg() { return lastTestMsg; }
    public void setLastTestMsg(String lastTestMsg) { this.lastTestMsg = lastTestMsg; }
    public String getRemark() { return remark; }
    public void setRemark(String remark) { this.remark = remark; }
}
