package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.dto.PageData;
import com.laos.agri.entity.AuditLog;
import com.laos.agri.service.AuditService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 审计日志查询 —— 仅管理员
 *
 * <p>为什么必须有这个接口：删除用户、查看完整手机号这类操作，
 * 我们在实现里都写了"记入审计日志"。但如果没有任何界面能看到审计日志，
 * 那句承诺就是空的 —— 出了事没人查得到"谁在什么时候删了谁"。
 *
 * <p>只读，不提供修改/删除接口：审计日志的价值就在于不可篡改。
 * 当前实现直接返回最近记录；数据量大时再按时间/操作人加筛选条件与归档策略。
 */
@RestController
@RequestMapping("/api/v1/admin/audit-logs")
@PreAuthorize("hasRole('ADMIN')")
public class AdminAuditController {

    private final AuditService auditService;

    public AdminAuditController(AuditService auditService) {
        this.auditService = auditService;
    }

    @GetMapping
    public ApiResponse<PageData<Map<String, Object>>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {

        var result = auditService.list(page, size);
        List<Map<String, Object>> items = result.getContent().stream().map(a -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", a.getId());
            m.put("actor_id", a.getActorId());
            m.put("actor_phone", a.getActorPhone());
            m.put("action", a.getAction());
            m.put("target_type", a.getTargetType());
            m.put("target_id", a.getTargetId());
            m.put("detail", a.getDetail());
            m.put("client_ip", a.getClientIp());
            m.put("created_at", a.getCreatedAt() == null ? null : a.getCreatedAt().toString());
            return m;
        }).toList();

        return ApiResponse.ok(new PageData<>(items, result.getTotalElements(), page, size));
    }
}
