package com.laos.agri.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 手机号验证码 —— 证明"这个号码确实是本人的"
 *
 * <p>要解决的问题：首版只需"手机号 + 密码"，而**密码是自己设的、号码却无法验证**，
 * 于是任何人编一个格式合法的号码就能注册。后果不只是假账号，
 * 还会造成后台用户列表被无效账号淹没（用户反馈的"后台拥堵"）。
 *
 * <p>安全设计：
 * <ul>
 *   <li>只存验证码的 <b>SHA-256 哈希</b>，不存明文；即使库被拖走也无法直接使用</li>
 *   <li>有效期 5 分钟，过期即失效</li>
 *   <li>最多尝试 5 次，超过作废，防暴力枚举（6 位码共 100 万种，5 次机会等于 20 万分之一）</li>
 *   <li>同一号码 60 秒内只能发 1 条、1 小时最多 5 条、1 天最多 10 条</li>
 *   <li>发送时记录 IP 与设备号，用于识别批量刷号行为</li>
 * </ul>
 */
@Entity
@Table(name = "phone_verification", schema = "core")
public class PhoneVerification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 国际区号 + 本地号码（不含 +），如 8613900001111 */
    @Column(name = "phone_full", nullable = false, length = 24)
    private String phoneFull;

    /** 验证码的 SHA-256 哈希（不存明文） */
    @Column(name = "code_hash", nullable = false, length = 64)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "attempts", nullable = false)
    private Integer attempts = 0;

    @Column(nullable = false)
    private Boolean used = false;

    @Column(name = "client_ip", length = 64)
    private String clientIp;

    @Column(name = "device_uuid", length = 64)
    private String deviceUuid;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    /** 校验用的一次性码（已用/过期都不算有效） */
    public boolean isUsable() {
        return !Boolean.TRUE.equals(used)
                && expiresAt != null
                && expiresAt.isAfter(LocalDateTime.now());
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getPhoneFull() { return phoneFull; }
    public void setPhoneFull(String phoneFull) { this.phoneFull = phoneFull; }
    public String getCodeHash() { return codeHash; }
    public void setCodeHash(String codeHash) { this.codeHash = codeHash; }
    public LocalDateTime getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDateTime expiresAt) { this.expiresAt = expiresAt; }
    public Integer getAttempts() { return attempts; }
    public void setAttempts(Integer attempts) { this.attempts = attempts; }
    public Boolean getUsed() { return used; }
    public void setUsed(Boolean used) { this.used = used; }
    public String getClientIp() { return clientIp; }
    public void setClientIp(String clientIp) { this.clientIp = clientIp; }
    public String getDeviceUuid() { return deviceUuid; }
    public void setDeviceUuid(String deviceUuid) { this.deviceUuid = deviceUuid; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
