package com.laos.agri.repository;

import com.laos.agri.entity.User;
import com.laos.agri.entity.UserRole;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByPhone(String phone);

    /** 按「区号 + 本地号码」查找 —— 唯一性口径 */
    Optional<User> findFirstByCountryCodeAndPhone(String countryCode, String phone);

    Optional<User> findByUuid(String uuid);

    boolean existsByPhone(String phone);

    long countByRole(UserRole role);

    /**
     * 后台用户列表检索：关键字匹配手机号/昵称，可选按角色过滤。
     * 两个参数都可为 null（表示不过滤）。
     *
     * <p><b>为什么用 COALESCE 而不是 {@code :keyword IS NULL}</b>：
     * 后者在 H2 上没问题，但在 PostgreSQL 上会直接报
     * {@code ERROR: function lower(bytea) does not exist} ——
     * PG 推断不出这个参数的类型，默认当成 bytea。
     * 用 {@code COALESCE(:keyword, '')} 之后参数类型由另一个操作数确定为 text，
     * 且 null 会退化成空串 → {@code LIKE '%%'} 匹配全部，语义不变。
     * （这个坑只在真 PG 上暴露，演示档用 H2 一直没发现。）
     */
    @Query("""
            SELECT u FROM User u
            WHERE (LOWER(COALESCE(u.phone, '')) LIKE LOWER(CONCAT('%', COALESCE(:keyword, ''), '%'))
                   OR LOWER(COALESCE(u.nickname, '')) LIKE LOWER(CONCAT('%', COALESCE(:keyword, ''), '%')))
              AND (COALESCE(:role, u.role) = u.role)
            ORDER BY u.id DESC
            """)
    Page<User> search(@Param("keyword") String keyword,
                      @Param("role") UserRole role,
                      Pageable pageable);
}
