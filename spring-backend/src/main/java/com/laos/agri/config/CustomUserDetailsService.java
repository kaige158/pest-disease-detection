package com.laos.agri.config;

import com.laos.agri.entity.User;
import com.laos.agri.repository.UserRepository;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 管理后台登录 —— 用 core.user 表做真实账号校验
 *
 * <p>表单登录的用户名即手机号（默认管理员账号为 {@code admin}）。
 * 密码为 BCrypt 哈希，由 {@link com.laos.agri.config.DataInitializer} 首次启动时写入。
 */
@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepo;

    public CustomUserDetailsService(UserRepository userRepo) {
        this.userRepo = userRepo;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userRepo.findByPhone(username)
                .orElseThrow(() -> new UsernameNotFoundException("账号不存在: " + username));

        String role = user.getRole() != null ? user.getRole().name() : "FARMER";

        return org.springframework.security.core.userdetails.User
                .withUsername(username)
                .password(user.getPasswordHash() == null ? "" : user.getPasswordHash())
                .authorities(List.of(new SimpleGrantedAuthority("ROLE_" + role)))
                .disabled(Boolean.FALSE.equals(user.getIsActive()))
                .build();
    }
}
