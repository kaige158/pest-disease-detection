package com.laos.agri.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 安全相关的开关，供 {@code @PreAuthorize} 表达式引用
 *
 * <p>为什么要有这个类：{@code @PreAuthorize} 里写的是 **SpEL**，
 * Spring 不会把 {@code ${...}} 配置占位符解析进去。早期写成
 * {@code @PreAuthorize("hasAnyRole('ADMIN') or ${security.admin-open:false}")}，
 * 结果每次调用都抛 SpelParseException → 接口直接 500
 * （审核中心、数据统计、训练数据统计整组接口全部不可用）。
 *
 * <p>正确做法是让 SpEL 引用一个 Bean：{@code @PreAuthorize("... or @securityFlags.adminOpen")}。
 */
@Component("securityFlags")
public class SecurityFlags {

    private final boolean adminOpen;

    public SecurityFlags(@Value("${security.admin-open:false}") boolean adminOpen) {
        this.adminOpen = adminOpen;
    }

    /**
     * 是否放开了后台鉴权（仅本地演示用）
     *
     * <p>生产环境必须为 false —— 为 true 时后台与后台接口对任何人开放。
     */
    public boolean isAdminOpen() {
        return adminOpen;
    }
}
