package com.laos.agri.service;

import com.laos.agri.dto.ApiResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Base64;
import java.util.Map;

/**
 * AI服务客户端 — 封装对Python AI微服务的HTTP调用
 */
@Service
public class AiServiceClient {

    private static final Logger log = LoggerFactory.getLogger(AiServiceClient.class);
    private final RestClient restClient;

    public AiServiceClient(RestClient aiRestClient) {
        this.restClient = aiRestClient;
    }

    /**
     * 调用病虫害图片识别
     *
     * @param imageBase64 图片Base64编码
     * @param cropName    作物名称(可选)
     * @param language    语言 zh/lo
     * @param version     vegetable/fruit
     * @return AI识别结果
     */
    public Map<String, Object> identifyDisease(
            String imageBase64,
            String cropName,
            String language,
            String version) {

        var request = Map.of(
            "image", imageBase64,
            "crop_name", cropName != null ? cropName : "",
            "language", language,
            "version", version
        );

        log.info("Calling AI identify API: version={}, language={}, crop={}", version, language, cropName);

        try {
            var response = restClient.post()
                    .uri("/api/v1/identify")
                    .body(request)
                    .retrieve()
                    .body(new ParameterizedTypeReference<Map<String, Object>>() {});

            log.info("AI identify API success");
            return response;
        } catch (Exception e) {
            log.error("AI identify API failed: {}", e.getMessage());
            throw new RuntimeException("AI识别服务暂时不可用", e);
        }
    }

    /**
     * 调用AI农业诊断Agent对话
     */
    public String chat(String message, String language, String version, String sessionId) {
        var request = Map.of(
            "message", message,
            "language", language,
            "version", version,
            "session_id", sessionId
        );

        log.info("Calling AI chat API: version={}, language={}", version, language);

        try {
            var response = restClient.post()
                    .uri("/api/v1/chat")
                    .body(request)
                    .retrieve()
                    .body(new ParameterizedTypeReference<Map<String, Object>>() {});

            return response != null ? (String) response.get("reply") : "AI服务返回为空";
        } catch (Exception e) {
            log.error("AI chat API failed: {}", e.getMessage());
            return "诊断服务暂时不可用，请稍后再试";
        }
    }

    /**
     * 生成防控方案
     */
    public Map<String, Object> generatePreventionPlan(Integer diseaseId, String language) {
        try {
            return restClient.get()
                    .uri(uriBuilder -> uriBuilder
                        .path("/api/v1/prevention/{diseaseId}")
                        .queryParam("language", language)
                        .build(diseaseId))
                    .retrieve()
                    .body(new ParameterizedTypeReference<Map<String, Object>>() {});
        } catch (Exception e) {
            log.error("AI prevention API failed: {}", e.getMessage());
            return Map.of("error", "防控方案生成失败");
        }
    }
}
