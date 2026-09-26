package com.laos.agri.entity;

import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 角色权限定义 —— 每个角色能进后台做什么
 *
 * <p>背景：项目早有四个角色（ADMIN/EXPERT/TECHNICIAN/FARMER），
 * 但早期**只有 ADMIN 真正生效**，其余三个只是数据库里的标签，
 * 存在"给了专家角色却什么也做不了、或本该只读的人能改数据"的混乱。
 * 这里把权限口径集中定义，避免散落在各 Controller 里各写一套。
 *
 * <p>设计原则（农业平台的实际分工）：
 * <ul>
 *   <li><b>ADMIN 平台管理员</b>：技术/运营负责人 —— 全部权限，
 *       包括 AI 配置与用户管理（涉及密钥与账号安全）</li>
 *   <li><b>EXPERT 农业专家（老师）</b>：审核识别结果、维护知识库内容。
 *       能改内容但**不能碰 AI 密钥与用户账号** —— 职责分离</li>
 *   <li><b>TECHNICIAN 农技推广员</b>：只读 + 可审核自己负责的结果，
 *       **不能改知识库**（避免未经审核的内容进入用户端）</li>
 *   <li><b>FARMER 农户</b>：只能用 APP，无后台权限</li>
 * </ul>
 */
public enum Permission {

    /** 查看仪表盘 */
    DASHBOARD_VIEW,
    /** 查看待审核列表 */
    REVIEW_VIEW,
    /** 提交审核结论（确认/纠正/驳回） */
    REVIEW_SUBMIT,
    /** 查看知识库 */
    KNOWLEDGE_VIEW,
    /** 新增/修改知识库内容 */
    KNOWLEDGE_EDIT,
    /** 查看用户列表 */
    USER_VIEW,
    /** 停用账号 / 改角色 / 重置密码 */
    USER_MANAGE,
    /** 查看用户完整手机号（含二次验证与审计） */
    USER_REVEAL_PHONE,
    /** 删除用户及其全部关联数据（不可恢复，需二次验证密码） */
    USER_DELETE,
    /** 查看 AI 通道配置 */
    AI_CONFIG_VIEW,
    /** 修改 AI 通道（涉及 API Key） */
    AI_CONFIG_EDIT,
    /** 查看统计与审计日志 */
    STATS_VIEW;

    /** 各角色拥有的权限 */
    public static Set<Permission> of(UserRole role) {
        if (role == null) return Set.of();
        return switch (role) {
            case ADMIN -> Set.of(
                    DASHBOARD_VIEW, REVIEW_VIEW, REVIEW_SUBMIT,
                    KNOWLEDGE_VIEW, KNOWLEDGE_EDIT,
                    USER_VIEW, USER_MANAGE, USER_REVEAL_PHONE, USER_DELETE,
                    AI_CONFIG_VIEW, AI_CONFIG_EDIT, STATS_VIEW);

            // 专家：内容与审核的全权，但不碰密钥与账号 —— 职责分离
            case EXPERT -> Set.of(
                    DASHBOARD_VIEW, REVIEW_VIEW, REVIEW_SUBMIT,
                    KNOWLEDGE_VIEW, KNOWLEDGE_EDIT,
                    USER_VIEW, AI_CONFIG_VIEW, STATS_VIEW);

            // 农技员：只读 + 审核，不能改知识库
            case TECHNICIAN -> Set.of(
                    DASHBOARD_VIEW, REVIEW_VIEW, REVIEW_SUBMIT,
                    KNOWLEDGE_VIEW, USER_VIEW, STATS_VIEW);

            // 农户：无后台权限
            case FARMER -> Set.of();
        };
    }

    public static boolean has(UserRole role, Permission permission) {
        return of(role).contains(permission);
    }

    /**
     * 权限矩阵的一行 —— 供后台「角色权限说明」界面渲染
     *
     * <p>为什么要从代码里生成给界面看：交付后管理员要能自己看懂
     * "给某个人 EXPERT 到底给了他什么"。如果界面上的说明是另写一份文案，
     * 迟早会和 {@link #of(UserRole)} 里的真实规则脱节 ——
     * 界面写着"专家能改知识库"、代码里却禁止，是最难排查的一类问题。
     */
    public record MatrixRow(Permission permission, Set<UserRole> allowed) {

        /** i18n 键名（messages_zh/lo.properties 里的 perm.XXX） */
        public String labelKey() {
            return "perm." + permission.name();
        }

        public boolean allows(UserRole role) {
            return allowed.contains(role);
        }
    }

    /** 权限矩阵（顺序即界面显示顺序，与枚举声明顺序一致） */
    public static List<MatrixRow> matrix() {
        return Arrays.stream(values())
                .map(p -> new MatrixRow(p, Arrays.stream(UserRole.values())
                        .filter(r -> has(r, p))
                        .collect(LinkedHashSet::new, Set::add, Set::addAll)))
                .toList();
    }
}
