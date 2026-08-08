package com.laos.agri.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * REST客户端配置 — 用于调用Python AI微服务
 */
@Configuration
public class RestClientConfig {

    private final AiServiceConfig aiServiceConfig;

    public RestClientConfig(AiServiceConfig aiServiceConfig) {
        this.aiServiceConfig = aiServiceConfig;
    }

    @Bean
    public RestClient aiRestClient() {
        var factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(aiServiceConfig.getConnectTimeout());
        factory.setReadTimeout(aiServiceConfig.getReadTimeout());

        return RestClient.builder()
                .baseUrl(aiServiceConfig.getUrl())
                .requestFactory(factory)
                .build();
    }
}
