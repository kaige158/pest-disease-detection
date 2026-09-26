package com.laos.agri.service;

import com.laos.agri.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

/**
 * JWT 令牌服务 —— 移动端用户登录态
 *
 * <p>令牌里带 {@code ver}（用户 token_version）。改密码 / 停用账号时递增该版本号，
 * 所有已签发令牌立即失效，无需维护黑名单。
 *
 * <p>密钥来自环境变量 {@code JWT_SECRET}，未配置时使用开发密钥并告警。
 */
@Service
public class JwtService {

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    private static final String DEV_FALLBACK_SECRET =
            "laos-agri-dev-only-jwt-secret-please-change-in-production-32bytes";
    private static final String CLAIM_ROLE = "role";
    private static final String CLAIM_UUID = "uuid";
    private static final String CLAIM_VERSION = "ver";

    private final SecretKey key;
    private final long expirationHours;
    private final boolean usingDevKey;

    public JwtService(@Value("${jwt.secret:}") String secret,
                      @Value("${jwt.expiration-hours:24}") long expirationHours) {
        String effective = (secret == null || secret.isBlank()) ? DEV_FALLBACK_SECRET : secret;
        this.usingDevKey = (secret == null || secret.isBlank());
        this.expirationHours = expirationHours;
        this.key = Keys.hmacShaKeyFor(effective.getBytes(StandardCharsets.UTF_8));
        if (usingDevKey) {
            log.warn("未配置 JWT_SECRET，正在使用开发密钥签发令牌 —— 生产环境必须配置！");
        }
    }

    public boolean isUsingDevKey() {
        return usingDevKey;
    }

    public long getExpirationHours() {
        return expirationHours;
    }

    /** 签发令牌 */
    public String issue(User user) {
        Date now = new Date();
        Date exp = new Date(now.getTime() + expirationHours * 3600_000L);
        return Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim(CLAIM_ROLE, user.getRole() != null ? user.getRole().name() : "FARMER")
                .claim(CLAIM_UUID, user.getUuid())
                .claim(CLAIM_VERSION, user.getTokenVersion() == null ? 0 : user.getTokenVersion())
                .issuedAt(now)
                .expiration(exp)
                .signWith(key)
                .compact();
    }

    /** 解析并验签；非法或过期返回 null */
    public Claims parse(String token) {
        try {
            return Jwts.parser().verifyWith(key).build()
                    .parseSignedClaims(token).getPayload();
        } catch (Exception e) {
            log.debug("JWT 校验失败: {}", e.getMessage());
            return null;
        }
    }

    public static Long userIdOf(Claims claims) {
        try {
            return Long.valueOf(claims.getSubject());
        } catch (Exception e) {
            return null;
        }
    }

    public static String roleOf(Claims claims) {
        Object v = claims.get(CLAIM_ROLE);
        return v == null ? null : v.toString();
    }

    public static int versionOf(Claims claims) {
        Object v = claims.get(CLAIM_VERSION);
        return v instanceof Number n ? n.intValue() : 0;
    }
}
