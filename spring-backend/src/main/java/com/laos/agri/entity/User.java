package com.laos.agri.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 用户表 core.user — 支持四角色: 管理员/专家/技术员/农户
 */
@Entity
@Table(name = "user")
public class User extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 36)
    private String uuid;

    /**
     * 本地手机号（不含区号）。
     *
     * <p>唯一性口径是 {@code (country_code, phone)} 组合，由业务层保证
     * （见 AuthService#createUser 的重复校验）—— 不能给单列加 unique，
     * 否则 +856 20xxxx 与 +66 20xxxx 这两个不同用户会互相冲突。
     */
    @Column(length = 20)
    private String phone;

    /**
     * 国际区号（纯数字，如 856 / 86 / 66 / 84）。
     * 为空表示历史数据：phone 里存的是完整号码（未拆分），登录/展示时按原样处理。
     */
    @Column(name = "country_code", length = 6)
    private String countryCode;

    @Column(name = "password_hash", length = 200)
    private String passwordHash;

    @Column(length = 100)
    private String nickname;

    @Column(name = "avatar_url", length = 500)
    private String avatarUrl;

    @Column(name = "language_pref", length = 10)
    private String languagePref = "lo";  // zh/lo/en

    @Column(name = "region_province", length = 100)
    private String regionProvince;

    @Column(name = "region_district", length = 100)
    private String regionDistrict;

    @Column(name = "crop_preferences", columnDefinition = "TEXT")
    private String cropPreferences = "[]";  // ["白菜","番茄"]

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private UserRole role = UserRole.FARMER;

    @Column(name = "organization_id")
    private Long organizationId;

    @Column(name = "last_login_at")
    private LocalDateTime lastLoginAt;

    /** 令牌版本 — 递增即可让该用户所有已签发 JWT 立即失效 */
    @Column(name = "token_version")
    private Integer tokenVersion = 0;

    @Column(name = "last_login_ip", length = 64)
    private String lastLoginIp;

    @Column(name = "login_count")
    private Integer loginCount = 0;

    /** 账号来源: APP(农户自注册) / SYSTEM(后台) / IMPORT(导入) */
    @Column(length = 20)
    private String source = "APP";

    /**
     * 是否必须修改密码 —— 初始密码 / 被管理员重置后置为 TRUE，
     * 用户自行改密成功后清除。后台据此弹出提醒横幅。
     */
    @Column(name = "must_change_password")
    private Boolean mustChangePassword = false;

    /**
     * 最近一次登录的设备标识 —— 用于判断"是否换设备登录"。
     * 换设备时要求短信验证，可显著提高盗号门槛。
     */
    @Column(name = "last_device_uuid", length = 64)
    private String lastDeviceUuid;

    // ===== getters/setters =====
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getUuid() { return uuid; }
    public void setUuid(String uuid) { this.uuid = uuid; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
    public String getCountryCode() { return countryCode; }
    public void setCountryCode(String countryCode) { this.countryCode = countryCode; }
    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }
    public String getNickname() { return nickname; }
    public void setNickname(String nickname) { this.nickname = nickname; }
    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }
    public String getLanguagePref() { return languagePref; }
    public void setLanguagePref(String languagePref) { this.languagePref = languagePref; }
    public String getRegionProvince() { return regionProvince; }
    public void setRegionProvince(String regionProvince) { this.regionProvince = regionProvince; }
    public String getRegionDistrict() { return regionDistrict; }
    public void setRegionDistrict(String regionDistrict) { this.regionDistrict = regionDistrict; }
    public String getCropPreferences() { return cropPreferences; }
    public void setCropPreferences(String cropPreferences) { this.cropPreferences = cropPreferences; }
    public UserRole getRole() { return role; }
    public void setRole(UserRole role) { this.role = role; }
    public Long getOrganizationId() { return organizationId; }
    public void setOrganizationId(Long organizationId) { this.organizationId = organizationId; }
    public LocalDateTime getLastLoginAt() { return lastLoginAt; }
    public void setLastLoginAt(LocalDateTime lastLoginAt) { this.lastLoginAt = lastLoginAt; }
    public Integer getTokenVersion() { return tokenVersion; }
    public void setTokenVersion(Integer tokenVersion) { this.tokenVersion = tokenVersion; }
    public String getLastLoginIp() { return lastLoginIp; }
    public void setLastLoginIp(String lastLoginIp) { this.lastLoginIp = lastLoginIp; }
    public Integer getLoginCount() { return loginCount; }
    public void setLoginCount(Integer loginCount) { this.loginCount = loginCount; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public Boolean getMustChangePassword() { return mustChangePassword; }
    public void setMustChangePassword(Boolean mustChangePassword) { this.mustChangePassword = mustChangePassword; }
    public String getLastDeviceUuid() { return lastDeviceUuid; }
    public void setLastDeviceUuid(String lastDeviceUuid) { this.lastDeviceUuid = lastDeviceUuid; }
}
