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
     */
    @Query("""
            SELECT u FROM User u
            WHERE (:keyword IS NULL
                   OR LOWER(u.phone) LIKE LOWER(CONCAT('%', :keyword, '%'))
                   OR LOWER(u.nickname) LIKE LOWER(CONCAT('%', :keyword, '%')))
              AND (:role IS NULL OR u.role = :role)
            ORDER BY u.id DESC
            """)
    Page<User> search(@Param("keyword") String keyword,
                      @Param("role") UserRole role,
                      Pageable pageable);
}
