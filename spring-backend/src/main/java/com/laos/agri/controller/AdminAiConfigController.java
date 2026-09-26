package com.laos.agri.controller;

import com.laos.agri.dto.AiProviderConfigDto;
import com.laos.agri.dto.ApiResponse;
import com.laos.agri.entity.AiProviderConfig;
import com.laos.agri.repository.AiProviderConfigRepository;
import com.laos.agri.service.ApiKeyCipher;
import com.laos.agri.service.AiServiceClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * AI 配置中心 —— 管理员可在后台可视化切换/配置 AI 通道，改完即生效
 *
 * <p>接口一览：
 * <pre>
 *   GET    /api/v1/admin/ai/configs            列出全部通道（密钥脱敏）
 *   POST   /api/v1/admin/ai/configs            新增通道
 *   PUT    /api/v1/admin/ai/configs/{id}       修改通道（apiKey 留空=不修改）
 *   POST   /api/v1/admin/ai/configs/{id}/activate  设为当前生效
 *   POST   /api/v1/admin/ai/configs/{id}/test      连通性测试（用库中密钥）
 *   POST   /api/v1/admin/ai/test               连通性测试（用表单里刚填的密钥，未保存也可测）
 *   DELETE /api/v1/admin/ai/configs/{id}       删除通道（生效中的不允许删）
 *   GET    /api/v1/admin/ai/active             当前生效通道（供 AI 服务/排障查看）
 * </pre>
 *
 * <p>安全：{@code apiKey} 只在写入方向出现，读出方向只有脱敏串；
 * 明文密钥落库前用 AES-256-GCM 加密（{@link ApiKeyCipher}）。
 */
@RestController
@RequestMapping("/api/v1/admin/ai")
/**
 * 权限：查看通道配置允许 ADMIN/EXPERT（专家需要知道当前用哪个模型），
 * 但**修改配置（涉及 API Key）仅限 ADMIN**。
 */
@PreAuthorize("hasAnyRole('ADMIN','EXPERT')")
public class AdminAiConfigController {

    private static final Logger log = LoggerFactory.getLogger(AdminAiConfigController.class);

    /**
     * 支持的通道类型 —— 与 Python 侧 `SUPPORTED_PROVIDERS` 必须保持一致。
     *
     * <p>deepseek / custom 走 OpenAI 兼容协议（`/v1/chat/completions`），
     * 因此通义千问、智谱、自建代理都可以通过 custom 接入，无需改代码。
     */
    private static final Set<String> SUPPORTED_PROVIDERS =
            Set.of("gemini", "kimi", "openai", "claude", "deepseek", "custom", "mock");

    private final AiProviderConfigRepository repo;
    private final ApiKeyCipher cipher;
    private final AiServiceClient aiServiceClient;

    public AdminAiConfigController(AiProviderConfigRepository repo,
                                   ApiKeyCipher cipher,
                                   AiServiceClient aiServiceClient) {
        this.repo = repo;
        this.cipher = cipher;
        this.aiServiceClient = aiServiceClient;
    }

    // ==================== 请求体 ====================

    /** 新增/修改通道。apiKey 为空字符串表示"保持原密钥不变"。 */
    public record ConfigRequest(
            String provider,
            String displayName,
            String apiKey,
            String baseUrl,
            String model,
            Integer maxTokens,
            BigDecimal temperature,
            Integer timeoutSeconds,
            String remark
    ) {}

    /** 未保存前的连通性测试：直接用表单里的值试 */
    public record TestRequest(
            Long id,
            String provider,
            String apiKey,
            String baseUrl,
            String model
    ) {}

    // ==================== 查询 ====================

    /**
     * 可选通道类型 + 厂商预设 —— 后台下拉框据此动态渲染
     *
     * <p>为什么后端下发而不是写死在模板里：新增一个厂商（如 DeepSeek）时
     * 只需要改这一处，后台模板与前端脚本都不用动。
     *
     * <p>{@code preset} 给出官方请求地址与推荐模型名，选中后自动预填，
     * 运维不必去翻厂商文档拼路径。通义千问、智谱等同样兼容 OpenAI 协议，
     * 因此可先用 custom 接入，后续再加预设即可。
     */
    @GetMapping("/providers")
    public ApiResponse<List<Map<String, Object>>> providers() {
        List<Map<String, Object>> list = new ArrayList<>();

        list.add(providerOption("gemini", "Google Gemini（有免费额度）", true,
                "在 https://aistudio.google.com/apikey 申请 Key", null, "gemini-3.6-flash"));
        list.add(providerOption("deepseek", "DeepSeek（国内直连）", true,
                "国内可直连；视觉识别需使用 vision 系列模型，请先点「测试连接」验证",
                "https://api.deepseek.com/v1/chat/completions", "deepseek-v4-flash-vision-exp"));
        list.add(providerOption("kimi", "月之暗面 Kimi（国内可直连）", true,
                "在 https://platform.moonshot.cn 申请 Key", null, "moonshot-v1-8k-vision-preview"));
        list.add(providerOption("openai", "OpenAI GPT-4o", true,
                "需要海外网络环境", null, "gpt-4o"));
        list.add(providerOption("claude", "Anthropic Claude", true,
                "需要海外网络环境", null, "claude-sonnet-4-20250514"));
        list.add(providerOption("custom", "自定义 / 代理（通义千问、智谱等）", true,
                "兼容 OpenAI 协议：填接口地址与模型名即可接入任意厂商或自建代理",
                null, null));
        list.add(providerOption("mock", "Mock（离线演示，不调外部 API）", false,
                "无需密钥，用于演示与联调，识别结果固定", null, null));

        return ApiResponse.ok(list);
    }

    private Map<String, Object> providerOption(String value, String label, boolean needKey,
                                               String note, String baseUrl, String model) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("value", value);
        m.put("label", label);
        m.put("need_key", needKey);
        m.put("note", note);
        Map<String, Object> preset = new LinkedHashMap<>();
        if (baseUrl != null) preset.put("baseUrl", baseUrl);
        if (model != null) preset.put("model", model);
        m.put("preset", preset);
        return m;
    }

    @GetMapping("/configs")
    public ApiResponse<List<AiProviderConfigDto>> list() {
        List<AiProviderConfigDto> data = repo.findAllByOrderByIdAsc().stream().map(this::toDto).toList();
        return ApiResponse.ok(data);
    }

    @GetMapping("/active")
    public ApiResponse<Map<String, Object>> active() {
        return repo.findFirstByIsActiveTrue()
                .map(c -> {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("id", c.getId());
                    m.put("provider", c.getProvider());
                    m.put("model", c.getModel());
                    m.put("configured", c.getApiKeyEnc() != null && !c.getApiKeyEnc().isBlank());
                    return ApiResponse.ok(m);
                })
                .orElseGet(() -> ApiResponse.error(404, "尚未启用任何 AI 通道"));
    }

    // ==================== 写入 ====================

    // 写操作（涉及 API Key）仅限 ADMIN；专家只能查看
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/configs")
    @Transactional
    public ApiResponse<AiProviderConfigDto> create(@RequestBody ConfigRequest req) {
        String err = validate(req, true);
        if (err != null) return ApiResponse.error(400, err);

        if (repo.findByProvider(req.provider().toLowerCase()).isPresent()) {
            return ApiResponse.error(409, "该通道已存在，请直接编辑：" + req.provider());
        }

        AiProviderConfig c = new AiProviderConfig();
        c.setProvider(req.provider().toLowerCase());
        applyRequest(c, req);
        boolean firstChannel = repo.count() == 0;
        c.setIsActive(firstChannel);   // 第一个通道自动生效
        repo.save(c);
        log.info("管理员新增 AI 通道: provider={}, active={}", c.getProvider(), c.getIsActive());
        return ApiResponse.ok(toDto(c));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PutMapping("/configs/{id}")
    @Transactional
    public ApiResponse<AiProviderConfigDto> update(@PathVariable Long id, @RequestBody ConfigRequest req) {
        return repo.findById(id).map(c -> {
            String err = validate(req, false);
            if (err != null) return ApiResponse.<AiProviderConfigDto>error(400, err);

            if (req.provider() != null && !req.provider().isBlank()) {
                c.setProvider(req.provider().toLowerCase());
            }
            applyRequest(c, req);
            repo.save(c);
            log.info("管理员修改 AI 通道: id={}, provider={}, 密钥是否更新={}",
                    id, c.getProvider(), req.apiKey() != null && !req.apiKey().isBlank());
            return ApiResponse.ok(toDto(c));
        }).orElseGet(() -> ApiResponse.error(404, "通道不存在: " + id));
    }

    /** 设为当前生效通道 —— 改完 AI 服务下一次请求即用新通道，无需重启 */
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/configs/{id}/activate")
    @Transactional
    public ApiResponse<AiProviderConfigDto> activate(@PathVariable Long id) {
        return repo.findById(id).map(target -> {
            if (target.getApiKeyEnc() == null || target.getApiKeyEnc().isBlank()) {
                // 允许启用（比如 mock 通道不需要密钥），但明确告知
                log.warn("启用未配置密钥的通道: id={}, provider={}", id, target.getProvider());
            }
            repo.findFirstByIsActiveTrue().ifPresent(current -> {
                if (!current.getId().equals(id)) {
                    current.setIsActive(false);
                    repo.save(current);
                }
            });
            target.setIsActive(true);
            repo.save(target);
            log.info("AI 通道已切换: {} (id={})", target.getProvider(), id);
            return ApiResponse.ok(toDto(target));
        }).orElseGet(() -> ApiResponse.error(404, "通道不存在: " + id));
    }

    @PreAuthorize("hasRole('ADMIN')")
    @DeleteMapping("/configs/{id}")
    @Transactional
    public ApiResponse<String> delete(@PathVariable Long id) {
        return repo.findById(id).map(c -> {
            if (Boolean.TRUE.equals(c.getIsActive())) {
                return ApiResponse.<String>error(400, "当前生效的通道不能删除，请先启用其它通道");
            }
            repo.delete(c);
            log.info("管理员删除 AI 通道: id={}, provider={}", id, c.getProvider());
            return ApiResponse.ok("已删除");
        }).orElseGet(() -> ApiResponse.error(404, "通道不存在: " + id));
    }

    // ==================== 连通性测试 ====================

    /** 测试已保存的通道（使用库中密钥） */
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/configs/{id}/test")
    public ApiResponse<Map<String, Object>> testSaved(@PathVariable Long id) {
        var found = repo.findById(id);
        if (found.isEmpty()) return ApiResponse.error(404, "通道不存在: " + id);

        AiProviderConfig c = found.get();
        String apiKey = cipher.decrypt(c.getApiKeyEnc());
        if (apiKey == null && !"mock".equalsIgnoreCase(c.getProvider())) {
            return ApiResponse.error(400, "该通道尚未配置 API Key，请先填写并保存");
        }

        Map<String, Object> result = runTest(c.getProvider(), apiKey, c.getBaseUrl(), c.getModel());

        // 回写测试结果，方便后台一眼看到各通道健康状况
        c.setLastTestAt(LocalDateTime.now());
        c.setLastTestOk(Boolean.TRUE.equals(result.get("ok")));
        c.setLastTestMs(result.get("elapsed_ms") instanceof Number n ? n.intValue() : null);
        c.setLastTestMsg(String.valueOf(result.getOrDefault("message", "")).substring(
                0, Math.min(500, String.valueOf(result.getOrDefault("message", "")).length())));
        repo.save(c);

        return ApiResponse.ok(result);
    }

    /**
     * 测试尚未保存的表单值 —— 管理员可以先验证密钥再保存
     * （apiKey 为空时回退到该 id 已保存的密钥）
     */
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/test")
    public ApiResponse<Map<String, Object>> testDraft(@RequestBody TestRequest req) {
        String apiKey = req.apiKey();
        String provider = req.provider();
        String baseUrl = req.baseUrl();
        String model = req.model();

        if ((apiKey == null || apiKey.isBlank()) && req.id() != null) {
            var saved = repo.findById(req.id());
            if (saved.isPresent()) {
                AiProviderConfig c = saved.get();
                apiKey = cipher.decrypt(c.getApiKeyEnc());
                if (provider == null || provider.isBlank()) provider = c.getProvider();
                if (baseUrl == null || baseUrl.isBlank()) baseUrl = c.getBaseUrl();
                if (model == null || model.isBlank()) model = c.getModel();
            }
        }
        if (provider == null || provider.isBlank()) {
            return ApiResponse.error(400, "请先选择通道类型");
        }
        if ((apiKey == null || apiKey.isBlank()) && !"mock".equalsIgnoreCase(provider)) {
            return ApiResponse.error(400, "请先填写 API Key");
        }

        return ApiResponse.ok(runTest(provider, apiKey, baseUrl, model));
    }

    /** 实际调用 AI 服务的自检接口 */
    private Map<String, Object> runTest(String provider, String apiKey, String baseUrl, String model) {
        long start = System.currentTimeMillis();
        try {
            Map<String, Object> resp = aiServiceClient.testProvider(provider, apiKey, baseUrl, model);
            long elapsed = System.currentTimeMillis() - start;
            Map<String, Object> m = new LinkedHashMap<>(resp);
            m.putIfAbsent("ok", false);
            m.put("elapsed_ms", elapsed);
            return m;
        } catch (Exception e) {
            long elapsed = System.currentTimeMillis() - start;
            log.warn("AI 通道测试失败: provider={}, err={}", provider, e.getMessage());
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("ok", false);
            m.put("elapsed_ms", elapsed);
            m.put("message", "无法连接 AI 服务（Python 微服务）：" + e.getMessage());
            return m;
        }
    }

    // ==================== 内部工具 ====================

    /** 把请求体写进实体；apiKey 为空则保持原密钥不变 */
    private void applyRequest(AiProviderConfig c, ConfigRequest req) {
        if (req.displayName() != null) c.setDisplayName(req.displayName().trim());
        if (req.baseUrl() != null) c.setBaseUrl(blankToNull(req.baseUrl()));
        if (req.model() != null) c.setModel(blankToNull(req.model()));
        if (req.maxTokens() != null && req.maxTokens() > 0) c.setMaxTokens(req.maxTokens());
        if (req.temperature() != null) c.setTemperature(req.temperature());
        if (req.timeoutSeconds() != null && req.timeoutSeconds() > 0) c.setTimeoutSeconds(req.timeoutSeconds());
        if (req.remark() != null) c.setRemark(blankToNull(req.remark()));

        if (req.apiKey() != null && !req.apiKey().isBlank()) {
            String plain = req.apiKey().trim();
            c.setApiKeyEnc(cipher.encrypt(plain));
            c.setApiKeyMasked(ApiKeyCipher.mask(plain));
        }
    }

    private String validate(ConfigRequest req, boolean requireProvider) {
        if (requireProvider && (req.provider() == null || req.provider().isBlank())) {
            return "请选择通道类型";
        }
        if (req.provider() != null && !req.provider().isBlank()
                && !SUPPORTED_PROVIDERS.contains(req.provider().toLowerCase())) {
            return "不支持的通道类型：" + req.provider() + "（可选：" + String.join("/", SUPPORTED_PROVIDERS) + "）";
        }
        if (req.temperature() != null
                && (req.temperature().compareTo(BigDecimal.ZERO) < 0
                    || req.temperature().compareTo(BigDecimal.ONE) > 0)) {
            return "temperature 必须在 0~1 之间";
        }
        return null;
    }

    private static String blankToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private AiProviderConfigDto toDto(AiProviderConfig c) {
        return new AiProviderConfigDto(
                c.getId(),
                c.getProvider(),
                c.getDisplayName(),
                c.getApiKeyMasked(),
                c.getApiKeyEnc() != null && !c.getApiKeyEnc().isBlank(),
                c.getBaseUrl(),
                c.getModel(),
                c.getMaxTokens(),
                c.getTemperature(),
                c.getTimeoutSeconds(),
                Boolean.TRUE.equals(c.getIsActive()),
                c.getLastTestOk(),
                c.getLastTestMs(),
                c.getLastTestMsg(),
                c.getLastTestAt() == null ? null : c.getLastTestAt().toString(),
                c.getRemark(),
                c.getUpdatedAt() == null ? null : c.getUpdatedAt().toString()
        );
    }
}
