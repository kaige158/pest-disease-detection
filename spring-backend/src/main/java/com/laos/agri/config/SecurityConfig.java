package com.laos.agri.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Spring Security配置 — 开发阶段开放访问，生产环境收紧
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.IF_REQUIRED))
            .authorizeHttpRequests(auth -> auth
                // 公开API
                .requestMatchers("/api/v1/knowledge/**").permitAll()
                .requestMatchers("/api/v1/recognition/**").permitAll()
                .requestMatchers("/api/v1/assistant/**").permitAll()
                // 管理API + Web后台 (开发阶段开放)
                .requestMatchers("/api/v1/admin/**").permitAll()
                .requestMatchers("/admin/**").permitAll()
                // 静态资源
                .requestMatchers("/css/**", "/js/**", "/images/**").permitAll()
                // 文档 + 健康检查
                .requestMatchers("/health", "/api-docs/**", "/swagger-ui/**").permitAll()
                // 其他
                .anyRequest().permitAll()
            )
            .formLogin(form -> form
                .loginPage("/admin/login")
                .defaultSuccessUrl("/admin/dashboard")
                .permitAll()
            )
            .logout(logout -> logout
                .logoutSuccessUrl("/admin/login")
                .permitAll()
            );

        return http.build();
    }
}
