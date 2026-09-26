package com.laos.agri.repository;

import com.laos.agri.entity.PhoneVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Optional;

public interface PhoneVerificationRepository extends JpaRepository<PhoneVerification, Long> {

    /** 取最近一条仍可用的验证码 */
    @Query("""
            SELECT v FROM PhoneVerification v
            WHERE v.phoneFull = :phoneFull
              AND v.used = false
              AND v.expiresAt > :now
            ORDER BY v.id DESC
            """)
    java.util.List<PhoneVerification> findUsable(@Param("phoneFull") String phoneFull,
                                                 @Param("now") LocalDateTime now);

    /** 最近一条发送记录（用于发送频率限制），不区分是否已用 */
    Optional<PhoneVerification> findFirstByPhoneFullOrderByIdDesc(String phoneFull);

    /** 时间窗口内该号码的发发送条数 */
    long countByPhoneFullAndCreatedAtAfter(String phoneFull, LocalDateTime after);

    /** 时间窗口内该 IP 的发送条数 —— 用于识别批量刷号 */
    long countByClientIpAndCreatedAtAfter(String clientIp, LocalDateTime after);

    /** 全局发送量 —— 防止被恶意刷爆短信费用 */
    long countByCreatedAtAfter(LocalDateTime after);

    /** 某号码的全部验证码记录（删除用户时一并清掉，避免残留个人信息） */
    long countByPhoneFull(String phoneFull);

    void deleteByPhoneFull(String phoneFull);
}
