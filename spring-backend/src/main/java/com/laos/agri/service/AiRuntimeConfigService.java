package com.laos.agri.service;

import com.laos.agri.entity.AiProviderConfig;
import com.laos.agri.repository.AiProviderConfigRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * AI 运行时通道配置 —— 把后台「AI 配置中心」当前生效的通道下发给 Python AI 服务
 *
 * <p>设计约定（见 AGENTS.md「关键决策记录」）：
 * <ul>
 *   <li>配置的**唯一来源**是 {@code core.ai_provider_config} 表，管理员在后台维护</li>
 *   <li>业务后端在每次调用 AI 服务时把当前通道放进请求体，AI 服务保持无状态</li>
 *   <li>因此后台改通道/改模型/换 Key 立即生效，AI 服务无需重启、也无需连数据库</li>
 * </ul>
 *
 * <p>踩过的坑：识别接口曾经**完全没有**下发 {@code provider_config}，
 * 于是 AI 服务每次都回退到 .env 默认值 —— 后台点了「设为当前生效」、
 * 界面上也显示生效了，识别结果却还是旧通道（甚至是 mock）。
 * 这类"界面显示对、实际没生效"的问题最难排查，所以这里下发什么一律打日志。
 */
@Service
public class AiRuntimeConfigService {

    private static final Logger log = LoggerFactory.getLogger(AiRuntimeConfigService.class);

    private final AiProviderConfigRepository repo;
    private final ApiKeyCipher cipher;

    public AiRuntimeConfigService(AiProviderConfigRepository repo, ApiKeyCipher cipher) {
        this.repo = repo;
        this.cipher = cipher;
    }

    /**
     * @return 当前生效通道的运行时配置；没有任何生效通道时返回空 Map
     *         （AI 服务会回退到它自己的 .env 默认配置）
     */
    public Map<String, Object> activeChannel() {
        return repo.findFirstByIsActiveTrue()
                .map(this::toRuntimeConfig)
                .orElseGet(() -> {
                    log.warn("core.ai_provider_config 里没有 is_active=true 的通道，"
                            + "本次调用将回退到 AI 服务的 .env 默认配置");
                    return Map.of();
                });
    }

    /** 实体 → AI 服务认识的运行时配置字典（字段名与 Python ProviderConfig.from_dict 对齐） */
    public Map<String, Object> toRuntimeConfig(AiProviderConfig c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("provider", nz(c.getProvider()));
        m.put("api_key", nz(cipher.decrypt(c.getApiKeyEnc())));
        m.put("model", nz(c.getModel()));
        m.put("base_url", nz(c.getBaseUrl()));
        if (c.getMaxTokens() != null) m.put("max_tokens", c.getMaxTokens());
        if (c.getTemperature() != null) m.put("temperature", c.getTemperature().doubleValue());
        if (c.getTimeoutSeconds() != null) m.put("timeout_seconds", c.getTimeoutSeconds());

        log.info("下发 AI 通道: id={}, provider={}, model={}, baseUrl={}, key={}",
                c.getId(), m.get("provider"), m.get("model"),
                m.get("base_url"),
                ((String) m.get("api_key")).isEmpty() ? "未配置" : "已配置(" + ((String) m.get("api_key")).length() + "位)");
        return m;
    }

    private static String nz(String s) { return s == null ? "" : s.trim(); }
}
