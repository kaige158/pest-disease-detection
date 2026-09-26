package com.laos.agri.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * API Key 加解密 —— AI 通道的密钥在库里只存密文
 *
 * <p>算法：AES-256-GCM（带认证标签，防篡改），每次加密随机 12 字节 IV，
 * 存储格式为 {@code Base64(IV || CipherText)}。
 *
 * <p>主密钥来自环境变量 {@code AI_KEY_SECRET}（绝不硬编码、绝不入库）。
 * 未配置时按开发模式处理：使用固定的开发密钥并打印醒目告警，
 * 生产环境请务必配置，否则换机器后旧密文无法解密。
 */
@Component
public class ApiKeyCipher {

    private static final Logger log = LoggerFactory.getLogger(ApiKeyCipher.class);

    private static final String ALGO = "AES";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int IV_LENGTH = 12;
    private static final int TAG_BITS = 128;
    private static final String DEV_FALLBACK_SECRET = "laos-agri-dev-only-secret-change-me";

    private final SecretKeySpec key;
    private final boolean usingDevKey;

    public ApiKeyCipher(@Value("${security.ai-key-secret:}") String secret) {
        String effective = (secret == null || secret.isBlank()) ? DEV_FALLBACK_SECRET : secret;
        this.usingDevKey = (secret == null || secret.isBlank());
        this.key = new SecretKeySpec(sha256(effective), ALGO);
        if (usingDevKey) {
            log.warn("未配置 AI_KEY_SECRET，正在使用开发密钥加密 API Key —— 生产环境必须配置！");
        }
    }

    /** 是否在使用开发兜底密钥（后台界面会据此给出提示） */
    public boolean isUsingDevKey() {
        return usingDevKey;
    }

    /** 加密；明文为空时返回 null（表示"未配置密钥"） */
    public String encrypt(String plain) {
        if (plain == null || plain.isBlank()) return null;
        try {
            byte[] iv = new byte[IV_LENGTH];
            new SecureRandom().nextBytes(iv);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            byte[] cipherText = cipher.doFinal(plain.getBytes(StandardCharsets.UTF_8));

            byte[] combined = new byte[iv.length + cipherText.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(cipherText, 0, combined, iv.length, cipherText.length);
            return Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            throw new IllegalStateException("API Key 加密失败: " + e.getMessage(), e);
        }
    }

    /** 解密；密文为空或解密失败返回 null（不抛异常，避免因历史脏数据导致接口整体不可用） */
    public String decrypt(String encrypted) {
        if (encrypted == null || encrypted.isBlank()) return null;
        try {
            byte[] combined = Base64.getDecoder().decode(encrypted);
            if (combined.length <= IV_LENGTH) return null;

            byte[] iv = new byte[IV_LENGTH];
            System.arraycopy(combined, 0, iv, 0, IV_LENGTH);
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            byte[] plain = cipher.doFinal(combined, IV_LENGTH, combined.length - IV_LENGTH);
            return new String(plain, StandardCharsets.UTF_8);
        } catch (Exception e) {
            log.warn("API Key 解密失败（可能是主密钥变更或数据损坏）: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 脱敏展示 —— 只保留头 4 位与尾 4 位，中间用 **** 代替。
     * 短于 12 位的直接全部打码，避免泄露。
     */
    public static String mask(String plain) {
        if (plain == null || plain.isBlank()) return null;
        String p = plain.trim();
        if (p.length() < 12) return "****";
        return p.substring(0, 4) + "****" + p.substring(p.length() - 4);
    }

    private static byte[] sha256(String input) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(input.getBytes(StandardCharsets.UTF_8));
        } catch (Exception e) {
            throw new IllegalStateException("无法构造加密主密钥", e);
        }
    }
}
