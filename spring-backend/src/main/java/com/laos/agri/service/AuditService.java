package com.laos.agri.service;

import com.laos.agri.entity.AuditLog;
import com.laos.agri.entity.User;
import com.laos.agri.repository.AuditLogRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 审计日志服务 —— 敏感操作留痕
 *
 * <p>设计要点：审计写入使用 {@link Propagation#REQUIRES_NEW}，
 * 因为"记录一次失败的越权尝试"恰恰是主事务要回滚的场景，
 * 若共用事务会导致最关键的那条日志被一起回滚掉。
 */
@Service
public class AuditService {

    private static final Logger log = LoggerFactory.getLogger(AuditService.class);

    private final AuditLogRepository repo;

    public AuditService(AuditLogRepository repo) {
        this.repo = repo;
    }

    /**
     * 记录一条审计日志
     *
     * <p>独立事务 + 吞掉异常：审计失败绝不能影响主业务，
     * 但必须打错误日志，便于运维发现"审计表写不进去"这种隐患。
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(User actor, String action, String targetType, Long targetId,
                       String detail, String clientIp) {
        try {
            AuditLog entry = new AuditLog();
            entry.setActorId(actor == null ? 0L : actor.getId());
            entry.setActorPhone(actor == null ? null : actor.getPhone());
            entry.setAction(action);
            entry.setTargetType(targetType);
            entry.setTargetId(targetId);
            entry.setDetail(detail);
            entry.setClientIp(clientIp);
            repo.save(entry);
        } catch (Exception e) {
            log.error("审计日志写入失败（action={}, targetId={}）: {}", action, targetId, e.getMessage());
        }
    }

    public Page<AuditLog> list(int page, int size) {
        return repo.findAllByOrderByIdDesc(PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size))));
    }
}
