package com.laos.agri.config;

import com.laos.agri.entity.User;
import com.laos.agri.repository.UserRepository;
import com.laos.agri.service.JwtService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

/**
 * JWT 认证过滤器 —— 处理移动端 `Authorization: Bearer <token>`
 *
 * <p>校验三件事，缺一不可：
 * <ol>
 *   <li>签名与有效期（{@link JwtService#parse}）</li>
 *   <li>账号是否仍存在、是否被停用</li>
 *   <li>令牌版本是否与用户当前 token_version 一致 —— 改密码/停用后旧令牌立即失效</li>
 * </ol>
 *
 * <p>校验通过后把用户对象挂到请求属性 {@code currentUser}，控制器可直接注入。
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);

    /** 控制器里用 @RequestAttribute("currentUser") 取当前登录用户 */
    public static final String ATTR_CURRENT_USER = "currentUser";

    private final JwtService jwtService;
    private final UserRepository userRepo;

    public JwtAuthFilter(JwtService jwtService, UserRepository userRepo) {
        this.jwtService = jwtService;
        this.userRepo = userRepo;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            authenticate(header.substring(7).trim(), request);
        }
        chain.doFilter(request, response);
    }

    private void authenticate(String token, HttpServletRequest request) {
        if (token.isEmpty()) return;

        Claims claims = jwtService.parse(token);
        if (claims == null) return;

        Long userId = JwtService.userIdOf(claims);
        if (userId == null) return;

        Optional<User> found = userRepo.findById(userId);
        if (found.isEmpty()) return;

        User user = found.get();
        if (Boolean.FALSE.equals(user.getIsActive())) return;

        int tokenVersion = JwtService.versionOf(claims);
        int currentVersion = user.getTokenVersion() == null ? 0 : user.getTokenVersion();
        if (tokenVersion != currentVersion) {
            log.debug("令牌版本已失效: userId={} token.ver={} current={}", userId, tokenVersion, currentVersion);
            return;
        }

        String role = user.getRole() != null ? user.getRole().name() : "FARMER";
        var auth = new UsernamePasswordAuthenticationToken(
                user.getUuid(),
                null,
                List.of(new SimpleGrantedAuthority("ROLE_" + role)));
        SecurityContextHolder.getContext().setAuthentication(auth);

        // 供控制器通过 @RequestAttribute 直接注入
        request.setAttribute(ATTR_CURRENT_USER, user);
    }
}
