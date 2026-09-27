package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
import com.laos.agri.service.AiRuntimeConfigService;
import com.laos.agri.service.AiServiceClient;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * AI农业助手API — 诊断Agent对话
 */
@RestController
@RequestMapping("/api/v1/assistant")
public class AssistantController {

    private final AiServiceClient aiServiceClient;
    private final AiRuntimeConfigService aiRuntimeConfigService;

    public AssistantController(AiServiceClient aiServiceClient,
                               AiRuntimeConfigService aiRuntimeConfigService) {
        this.aiServiceClient = aiServiceClient;
        this.aiRuntimeConfigService = aiRuntimeConfigService;
    }

    @PostMapping("/chat")
    public ApiResponse<Map<String, Object>> chat(@RequestBody Map<String, Object> request) {
        String message = (String) request.getOrDefault("message", "");
        String language = (String) request.getOrDefault("language", "zh");
        String version = (String) request.getOrDefault("version", "vegetable");
        String sessionId = (String) request.getOrDefault("session_id",
                "sess_" + UUID.randomUUID().toString().substring(0, 8));

        if (message.isBlank()) {
            return ApiResponse.error(400, "消息不能为空");
        }

        try {
            // 同样下发当前生效通道，保证后台换模型对助手也立即生效
            String reply = aiServiceClient.chat(message, language, version, sessionId,
                    aiRuntimeConfigService.activeChannel());
            return ApiResponse.ok(Map.of(
                "reply", reply,
                "session_id", sessionId
            ));
        } catch (Exception e) {
            // 以前这里无论什么原因都只回"AI服务暂时不可用"，排查时没有任何线索；
            // 现在把 AI 层的原因带出来（调不通/模型不支持/Key 无效 都能一眼看到）。
            return ApiResponse.error(502, e.getMessage() == null ? "AI服务暂时不可用" : e.getMessage());
        }
    }
}
