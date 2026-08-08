package com.laos.agri.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

/**
 * AI服务配置 — 连接Python AI微服务
 */
@Configuration
@ConfigurationProperties(prefix = "ai.service")
public class AiServiceConfig {

    /** AI服务地址，例如 http://ai-service:8000 */
    private String url = "http://localhost:8000";

    /** 连接超时 */
    private Duration connectTimeout = Duration.ofSeconds(10);

    /** 读取超时（AI识别可能较慢） */
    private Duration readTimeout = Duration.ofSeconds(30);

    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    public Duration getConnectTimeout() { return connectTimeout; }
    public void setConnectTimeout(Duration connectTimeout) { this.connectTimeout = connectTimeout; }
    public Duration getReadTimeout() { return readTimeout; }
    public void setReadTimeout(Duration readTimeout) { this.readTimeout = readTimeout; }
}
