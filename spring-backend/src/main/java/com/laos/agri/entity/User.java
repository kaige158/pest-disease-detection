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

    @Column(length = 20)
    private String phone;

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

    // ===== getters/setters =====
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getUuid() { return uuid; }
    public void setUuid(String uuid) { this.uuid = uuid; }
    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }
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
}
