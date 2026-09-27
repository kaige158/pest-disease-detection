package com.laos.agri.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.laos.agri.config.AiServiceConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * AI服务客户端 — 封装对 Python AI 微服务的 HTTP 调用
 *
 * <p>两个刻意的实现选择（都是踩坑换来的）：
 * <ol>
 *   <li><b>响应先当字符串收，再自己解析 JSON</b>：以前直接 {@code .body(Map.class)}，
 *       一旦 AI 服务地址填错、连到了别的东西（静态文件服务/网关），Spring 只会抛
 *       {@code Error while extracting response for type [Map] and content type
 *       [application/octet-stream]} —— 既看不出连到了谁，也看不出返回了什么，
 *       排查时完全靠猜。现在会把 HTTP 状态、Content-Type、响应体前 300 字一起报出来。</li>
 *   <li><b>每次都把日志打到"调用哪个地址"</b>：AI 服务地址来自环境变量
 *       {@code AI_SERVICE_URL}，配错时症状是"AI 不可用"，但没人知道它到底在打哪个地址。</li>
 * </ol>
 */
@Service
public class AiServiceClient {

    private static final Logger log = LoggerFactory.getLogger(AiServiceClient.class);

    private final RestClient restClient;
    private final AiServiceConfig aiServiceConfig;
    private final ObjectMapper objectMapper;

    public AiServiceClient(RestClient aiRestClient,
                           AiServiceConfig aiServiceConfig,
                           ObjectMapper objectMapper) {
        this.restClient = aiRestClient;
        this.aiServiceConfig = aiServiceConfig;
        this.objectMapper = objectMapper;
    }

    /**
     * 启动时就把 AI 服务地址打进日志
     *
     * <p>踩过的坑：地址配错时，症状只是"AI 不可用"，还要翻配置、猜环境变量。
     * 现在 {@code docker logs laos_spring | grep "AI 服务地址"} 一眼就能看到实际值。
     */
    @jakarta.annotation.PostConstruct
    void logAiServiceUrl() {
        log.info("AI 服务地址 (AI_SERVICE_URL) = {}", aiServiceConfig.getUrl());
    }

    /**
     * 调用病虫害图片识别
     *
     * @param imageBase64    图片Base64编码
     * @param cropName       作物名称(可选)
     * @param language       语言 zh/lo
     * @param version        vegetable/fruit
     * @param providerConfig 当前生效的 AI 通道（来自后台配置中心，含明文Key，只走内存）
     * @return AI识别结果
     */
    public Map<String, Object> identifyDisease(
            String imageBase64,
            String cropName,
            String language,
            String version,
            Map<String, Object> providerConfig) {

        var request = new LinkedHashMap<String, Object>();
        request.put("image", imageBase64);
        request.put("crop_name", cropName != null ? cropName : "");
        request.put("language", language);
        request.put("version", version);
        request.put("provider_config", providerConfig == null ? Map.of() : providerConfig);

        String path = "/api/v1/identify";
        log.info("调用 AI 识别: url={}{}, version={}, language={}, crop={}, 图片Base64={}字",
                aiServiceConfig.getUrl(), path, version, language, cropName,
                imageBase64 == null ? 0 : imageBase64.length());

        try {
            Map<String, Object> response = postJson(path, request, "识别");
            log.info("AI 识别成功: 返回字段={}", response.keySet());
            return response;
        } catch (Exception e) {
            // 把 AI 服务的真实出错信息透传出来，不要再吞成一句"暂时不可用"。
            // 踩过的坑：AI 服务返回 502 + {"detail":"AI识别服务异常: 模型不支持图片输入"}，
            // 这里一律包成"AI识别服务暂时不可用"，手机上只能看到这句空话，
            // 排查时完全不知道该改什么（模型名？Key？还是图片太大）。
            String detail = extractAiServiceError(e);
            log.error("AI 识别失败: url={}{}, detail={}", aiServiceConfig.getUrl(), path, detail, e);
            throw new RuntimeException("AI识别失败：" + detail, e);
        }
    }

    /**
     * 调用AI农业诊断Agent对话
     *
     * @param providerConfig 当前生效的 AI 通道（同识别，后台改了立即生效）
     */
    public String chat(String message, String language, String version, String sessionId,
                       Map<String, Object> providerConfig) {
        var request = new LinkedHashMap<String, Object>();
        request.put("message", message);
        request.put("language", language);
        request.put("version", version);
        request.put("session_id", sessionId);
        request.put("provider_config", providerConfig == null ? Map.of() : providerConfig);

        String path = "/api/v1/chat";
        log.info("调用 AI 助手: url={}{}, version={}, language={}", aiServiceConfig.getUrl(), path, version, language);

        try {
            Map<String, Object> response = postJson(path, request, "助手");
            Object reply = response.get("reply");
            return reply != null ? String.valueOf(reply) : "AI服务返回为空";
        } catch (Exception e) {
            String detail = extractAiServiceError(e);
            log.error("AI 助手失败: url={}{}, detail={}", aiServiceConfig.getUrl(), path, detail, e);
            throw new RuntimeException("AI助手调用失败：" + detail, e);
        }
    }

    /**
     * 连通性自检 —— 后台"AI 配置中心"点「测试连接」时调用
     *
     * <p>由 AI 服务按其自身网络环境发起一次最小真实调用（不是只 ping 端口），
     * 因此能真正验证 Key / 模型名 / 网络是否可用。
     *
     * @param provider gemini/kimi/openai/claude/deepseek/custom/mock
     * @param apiKey   明文密钥（后台解密后传入；AI 服务不落库）
     * @param baseUrl  自定义地址，可空
     * @param model    模型名，可空（用该 Provider 默认值）
     */
    public Map<String, Object> testProvider(String provider, String apiKey, String baseUrl, String model) {
        var request = new LinkedHashMap<String, Object>();
        request.put("provider", provider == null ? "" : provider);
        request.put("api_key", apiKey == null ? "" : apiKey);
        request.put("base_url", baseUrl == null ? "" : baseUrl);
        request.put("model", model == null ? "" : model);

        String path = "/api/v1/config/test";
        log.info("调用 AI 通道自检: url={}{}, provider={}, model={}", aiServiceConfig.getUrl(), path, provider, model);

        Map<String, Object> response = postJson(path, request, "通道自检");
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
                    .body(new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {});
        } catch (Exception e) {
            log.error("AI prevention API failed: url={}/api/v1/prevention/{}, err={}",
                    aiServiceConfig.getUrl(), diseaseId, e.getMessage());
            return Map.of("error", "防控方案生成失败");
        }
    }

    // ==================== 内部工具 ====================

    /**
     * POST JSON 并返回解析后的 Map —— 响应先按字符串收，避免"提取失败"的黑盒报错
     */
    private Map<String, Object> postJson(String path, Object request, String what) {
        ResponseEntity<String> entity = restClient.post()
                .uri(path)
                .body(request)
                .retrieve()
                .toEntity(String.class);

        String body = entity.getBody();
        var contentType = entity.getHeaders().getContentType();
        String ct = contentType == null ? "(无)" : contentType.toString();

        if (body == null || body.isBlank()) {
            throw new IllegalStateException("AI服务" + what + "接口返回空响应（HTTP "
                    + entity.getStatusCode().value() + "）");
        }
        if (contentType == null || !ct.toLowerCase().contains("json")) {
            // 走到这里基本可以断定：AI 服务地址配错了，连到了别的服务
            throw new IllegalStateException("AI服务" + what + "接口返回的不是 JSON（HTTP "
                    + entity.getStatusCode().value() + ", Content-Type: " + ct
                    + "），请检查 AI_SERVICE_URL 是否正确。响应开头：" + preview(body));
        }
        try {
            return objectMapper.readValue(body, new TypeReference<Map<String, Object>>() {});
        } catch (Exception e) {
            throw new IllegalStateException("AI服务" + what + "接口返回的 JSON 解析失败（HTTP "
                    + entity.getStatusCode().value() + "）：" + preview(body), e);
        }
    }

    /**
     * 从异常里挖出 AI 服务的错误说明
     *
     * <p>AI 服务（FastAPI）出错时返回 {@code {"detail": "..."}}，
     * Spring 的 RestClient 会把它包在 RestClientResponseException 的响应体里。
     * 这里尽量把那段文本取出来展示给用户/日志。
     */
    private static String extractAiServiceError(Exception e) {
        if (e instanceof org.springframework.web.client.RestClientResponseException resp) {
            String body = resp.getResponseBodyAsString();
            if (body != null && !body.isBlank()) {
                String readable = readableDetail(body);
                if (readable != null) return readable;
                return preview(body);
            }
            return "AI 服务返回 HTTP " + resp.getStatusCode().value();
        }
        if (e instanceof java.net.ConnectException || e instanceof java.net.SocketTimeoutException
                || e instanceof java.net.UnknownHostException) {
            return "连不上 AI 服务（" + e.getClass().getSimpleName() + ": " + e.getMessage() + "）";
        }
        return e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
    }

    /**
     * 把 FastAPI 的错误响应翻译成一句人能看懂的话
     *
     * <p>FastAPI 的错误体有两种形态：
     * <ul>
     *   <li>{@code {"detail": "文本"}} —— 普通异常</li>
     *   <li>{@code {"detail": {"error": "...", "issues": [...], "suggestions_zh": [...]}}}
     *       —— 图片质量不合格时返回的结构化信息</li>
     * </ul>
     * 第二种以前会被整段 JSON 塞给用户看，手机上是没法看的。
     */
    private static String readableDetail(String body) {
        try {
            var root = new com.fasterxml.jackson.databind.ObjectMapper().readTree(body);
            var detail = root.get("detail");
            if (detail == null) return null;
            if (detail.isTextual()) return detail.asText();

            String error = detail.path("error").asText("");
            var issues = detail.path("issues");
            var suggestions = detail.path("suggestions_zh");
            StringBuilder sb = new StringBuilder(error.isBlank() ? "AI 服务返回错误" : error);
            if (issues.isArray() && !issues.isEmpty()) {
                sb.append("：");
                for (int i = 0; i < issues.size(); i++) {
                    if (i > 0) sb.append("；");
                    sb.append(issues.get(i).asText());
                }
            }
            if (suggestions.isArray() && !suggestions.isEmpty()) {
                sb.append("。建议：").append(suggestions.get(0).asText());
            }
            return sb.toString();
        } catch (Exception ignore) {
            return null;
        }
    }

    /** 响应体单行预览（打日志用，避免把整篇 HTML/Base64 灌进日志） */
    private static String preview(String body) {
        String s = body.replaceAll("\\s+", " ").trim();
        return s.length() > 300 ? s.substring(0, 300) + "…" : s;
    }
}
