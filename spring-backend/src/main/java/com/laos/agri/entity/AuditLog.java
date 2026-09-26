package com.laos.agri.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * 敏感操作审计日志 —— 记录"谁在什么时候对谁做了什么"
 *
 * <p>为什么必须有：管理员查看用户完整手机号属于个人信息访问，
 * 没有留痕就无法追责。这也是《个人信息保护法》对个人信息处理的基本要求：
 * 能够事后追溯谁访问了哪些个人信息。
 *
 * <p>只追加、不修改、不删除（业务上不提供删改接口）。
 */
@Entity
@Table(name = "audit_log", schema = "core")
public class AuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 操作者（管理员）用户 id */
    @Column(name = "actor_id", nullable = false)
    private Long actorId;

    /** 操作者账号，便于直接查日志时辨认 */
    @Column(name = "actor_phone", length = 32)
    private String actorPhone;

    /** 动作，如 REVEAL_PHONE */
    @Column(nullable = false, length = 64)
    private String action;

    @Column(name = "target_type", length = 32)
    private String targetType;

    @Column(name = "target_id")
    private Long targetId;

    @Column(length = 500)
    private String detail;

    @Column(name = "client_ip", length = 64)
    private String clientIp;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getActorId() { return actorId; }
    public void setActorId(Long actorId) { this.actorId = actorId; }
    public String getActorPhone() { return actorPhone; }
    public void setActorPhone(String actorPhone) { this.actorPhone = actorPhone; }
    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }
    public String getTargetType() { return targetType; }
    public void setTargetType(String targetType) { this.targetType = targetType; }
    public Long getTargetId() { return targetId; }
    public void setTargetId(Long targetId) { this.targetId = targetId; }
    public String getDetail() { return detail; }
    public void setDetail(String detail) { this.detail = detail; }
    public String getClientIp() { return clientIp; }
    public void setClientIp(String clientIp) { this.clientIp = clientIp; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
