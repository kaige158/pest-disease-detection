package com.laos.agri.controller;

import com.laos.agri.dto.ApiResponse;
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

    public AssistantController(AiServiceClient aiServiceClient) {
        this.aiServiceClient = aiServiceClient;
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
            String reply = aiServiceClient.chat(message, language, version, sessionId);
            return ApiResponse.ok(Map.of(
                "reply", reply,
                "session_id", sessionId
            ));
        } catch (Exception e) {
            return ApiResponse.error(502, "AI服务暂时不可用");
        }
    }
}
