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
            // 把 AI 服务的真实出错信息透传出来，不要再吞成一句"暂时不可用"。
            // 踩过的坑：AI 服务返回 502 + {"detail":"AI识别服务异常: 模型不支持图片输入"}，
            // 这里一律包成"AI识别服务暂时不可用"，手机上只能看到这句空话，
            // 排查时完全不知道该改什么（模型名？Key？还是图片太大）。
            String detail = extractAiServiceError(e);
            log.error("AI identify API failed: {}", detail, e);
            throw new RuntimeException("AI识别失败：" + detail, e);
        }
    }

    /**
     * 从异常里挖出 AI 服务的错误说明
     *
     * <p>AI 服务（FastAPI）出错时返回 {@code {"detail": "..."}}，
     * Spring 的 RestClient 会把它包在 HttpStatusCodeException 的响应体里。
     * 这里尽量把那段文本取出来展示给用户/日志。
     */
    private static String extractAiServiceError(Exception e) {
        if (e instanceof org.springframework.web.client.RestClientResponseException resp) {
            String body = resp.getResponseBodyAsString();
            if (body != null && !body.isBlank()) {
                var m = java.util.regex.Pattern
                        .compile("\"detail\"\\s*:\\s*\"([^\"]+)\"")
                        .matcher(body);
                if (m.find()) return m.group(1);
                return body.length() > 300 ? body.substring(0, 300) : body;
            }
            return "AI 服务返回 HTTP " + resp.getStatusCode().value();
        }
        if (e instanceof java.net.ConnectException || e instanceof java.net.SocketTimeoutException) {
            return "连不上 AI 服务（" + e.getMessage() + "）";
        }
        return e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
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
     * 连通性自检 —— 后台"AI 配置中心"点「测试连接」时调用
     *
     * <p>由 AI 服务按其自身网络环境发起一次最小真实调用（不是只 ping 端口），
     * 因此能真正验证 Key / 模型名 / 网络是否可用。
     *
     * @param provider gemini/kimi/openai/claude/custom/mock
     * @param apiKey   明文密钥（后台解密后传入；AI 服务不落库）
     * @param baseUrl  自定义地址，可空
     * @param model    模型名，可空（用该 Provider 默认值）
     */
    public Map<String, Object> testProvider(String provider, String apiKey, String baseUrl, String model) {
        var request = new java.util.HashMap<String, Object>();
        request.put("provider", provider);
        request.put("api_key", apiKey == null ? "" : apiKey);
        request.put("base_url", baseUrl == null ? "" : baseUrl);
        request.put("model", model == null ? "" : model);

        log.info("Calling AI provider self-test: provider={}, model={}", provider, model);

        var response = restClient.post()
                .uri("/api/v1/config/test")
                .body(request)
                .retrieve()
                .body(new ParameterizedTypeReference<Map<String, Object>>() {});

        return response != null ? response : Map.of("ok", false, "message", "AI 服务返回为空");
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
