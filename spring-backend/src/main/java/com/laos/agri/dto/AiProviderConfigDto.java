package com.laos.agri.dto;

/**
 * AI 通道配置的对外 DTO —— 与实体分离，确保 API Key 永不明文回传
 *
 * @param id            主键
 * @param provider      通道类型 gemini/kimi/openai/claude/custom/mock
 * @param displayName   展示名
 * @param apiKeyMasked  密钥脱敏串（如 AIza****abcd），未配置为 null
 * @param hasApiKey     是否已配置密钥（界面据此显示"已配置/未配置"）
 * @param baseUrl       自定义地址
 * @param model         模型名
 * @param maxTokens     最大 token 数
 * @param temperature   温度
 * @param timeoutSeconds 超时秒数
 * @param active        是否为当前生效通道
 * @param lastTestOk    最近一次连通性测试是否成功
 * @param lastTestMs    最近一次测试耗时（毫秒）
 * @param lastTestMsg   最近一次测试结果说明
 * @param lastTestAt    最近一次测试时间
 * @param remark        备注
 * @param updatedAt     最后修改时间
 */
public record AiProviderConfigDto(
        Long id,
        String provider,
        String displayName,
        String apiKeyMasked,
        boolean hasApiKey,
        String baseUrl,
        String model,
        Integer maxTokens,
        java.math.BigDecimal temperature,
        Integer timeoutSeconds,
        boolean active,
        Boolean lastTestOk,
        Integer lastTestMs,
        String lastTestMsg,
        String lastTestAt,
        String remark,
        String updatedAt
) {
}
