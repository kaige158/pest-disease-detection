"""Provider 运行时配置注入测试 —— 不需要 pydantic/FastAPI 依赖

背景：本机 Python 3.8 环境未安装 ai-service 的依赖（pydantic_settings 等），
但「后台改配置 → AI 服务立即用新配置」是本项目的核心交付点，
必须能被验证。这里用最小桩替换 pydantic_settings，单独验证配置注入逻辑。

运行：
    cd ai-service
    python tests/test_provider_config.py
"""
import asyncio
import os
import sys
import types

# ---------- 最小桩：让 app.core.config / provider 能在无依赖环境导入 ----------
# 说明：本测试只验证「配置注入」，不发起任何网络请求。
# 若真实发出请求，httpx 桩会直接报错，不会出现"假通过"。
if "pydantic_settings" not in sys.modules:
    stub = types.ModuleType("pydantic_settings")

    class BaseSettings:  # noqa: D401 - 仅用于测试替身
        def __init__(self, **kwargs):
            pass

    stub.BaseSettings = BaseSettings
    sys.modules["pydantic_settings"] = stub

if "httpx" not in sys.modules:
    httpx_stub = types.ModuleType("httpx")

    class _NoNetworkClient:
        def __init__(self, *args, **kwargs):
            raise RuntimeError("本测试不发起网络请求（httpx 为测试桩）")

    httpx_stub.AsyncClient = _NoNetworkClient
    httpx_stub.RemoteProtocolError = type("RemoteProtocolError", (Exception,), {})
    httpx_stub.ConnectError = type("ConnectError", (Exception,), {})
    httpx_stub.ReadError = type("ReadError", (Exception,), {})
    sys.modules["httpx"] = httpx_stub

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.ai_providers.base import ProviderConfig, AIProvider  # noqa: E402
from app.services.ai_providers.factory import build_provider  # noqa: E402

PASS, FAIL = [], []


def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(("  [PASS] " if cond else "  [FAIL] ") + name + (f"  {detail}" if detail else ""))


def main():
    print("=== 1) 运行时配置覆盖 .env ===")
    cfg = ProviderConfig.from_dict({
        "provider": "gemini",
        "api_key": "AIzaTESTKEY123456",
        "model": "gemini-2.5-flash",
        "max_tokens": 1234,
        "temperature": 0.5,
        "timeout_seconds": 45,
    })
    p = build_provider(cfg)
    check("provider 类型正确", p.provider_name == "gemini", p.provider_name)
    check("api_key 来自后台配置", p.api_key == "AIzaTESTKEY123456", p.api_key[:8] + "...")
    check("model 来自后台配置", p.model == "gemini-2.5-flash", p.model)
    check("max_tokens 生效", p.max_tokens == 1234, str(p.max_tokens))
    check("temperature 生效", abs(p.temperature - 0.5) < 1e-6, str(p.temperature))
    check("timeout 生效", p.timeout_seconds == 45, str(p.timeout_seconds))

    print("=== 2) 空配置回退 .env（本地裸跑仍可用）===")
    p2 = build_provider(ProviderConfig.from_dict({}))
    check("未注入时仍能构建 provider", p2 is not None, p2.provider_name)
    check("未注入 model 时使用默认值", p2.model != "", repr(p2.model))

    print("=== 3) 切换通道：同一份代码换 provider 立即生效 ===")
    for name, model in (("kimi", "kimi-k2.6"), ("openai", "gpt-4o"), ("mock", "")):
        px = build_provider(ProviderConfig.from_dict({"provider": name, "api_key": "k", "model": model}))
        ok = px.provider_name == name
        check(f"切换到 {name}", ok, px.provider_name)

    print("=== 3b) DeepSeek / 自定义通道（OpenAI 兼容协议）===")
    from app.services.ai_providers.factory import SUPPORTED_PROVIDERS
    check("deepseek 在支持列表中", "deepseek" in SUPPORTED_PROVIDERS,
          ", ".join(SUPPORTED_PROVIDERS))

    ds = build_provider(ProviderConfig.from_dict({"provider": "deepseek", "api_key": "sk-test"}))
    check("deepseek 通道可构建", ds.provider_name == "deepseek", ds.provider_name)
    check("deepseek 有默认模型（未配置时不用手填）", ds.model != "", ds.model)
    ds_url = ds._endpoint(getattr(ds, "DEFAULT_URL", ""), "/v1/chat/completions")
    check("deepseek 默认地址是其官方地址", "deepseek.com" in ds_url, ds_url)

    # 关键回归：custom 早期是 NotImplementedError 空壳，导致后台选了也完全不可用
    cu = build_provider(ProviderConfig.from_dict(
        {"provider": "custom", "api_key": "sk-test", "model": "qwen-vl-max",
         "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"}))
    check("custom 通道可构建", cu.provider_name == "custom", cu.provider_name)
    check("custom 使用后台填写的完整地址",
          cu._endpoint("", "/v1/chat/completions")
          == "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
          cu._endpoint("", "/v1/chat/completions"))

    # 只填主机时要能自动补全路径
    cu2 = build_provider(ProviderConfig.from_dict(
        {"provider": "custom", "api_key": "sk-test", "base_url": "https://api.deepseek.com"}))
    check("custom 只填主机 → 自动补 /v1/chat/completions",
          cu2._endpoint("", "/v1/chat/completions") == "https://api.deepseek.com/v1/chat/completions",
          cu2._endpoint("", "/v1/chat/completions"))

    cu3 = build_provider(ProviderConfig.from_dict(
        {"provider": "custom", "api_key": "sk-test", "base_url": "https://api.deepseek.com/v1"}))
    check("custom 填到 /v1 → 补 /chat/completions",
          cu3._endpoint("", "/v1/chat/completions") == "https://api.deepseek.com/v1/chat/completions",
          cu3._endpoint("", "/v1/chat/completions"))

    print("=== 3c) 未填地址的自定义通道应给出明确报错（而不是静默失败）===")
    import asyncio as _asyncio
    cu4 = build_provider(ProviderConfig.from_dict({"provider": "custom", "api_key": "sk-test"}))
    try:
        _asyncio.get_event_loop().run_until_complete(
            cu4.identify_disease(b"\xff\xd8\xff" + b"0" * 100, None, "zh", "vegetable"))
        check("未填地址时报错", False, "竟然没有报错")
    except RuntimeError as e:
        check("未填地址时报错清晰", "接口地址" in str(e), str(e)[:60])
    except Exception as e:
        check("未填地址时报错清晰", False, f"异常类型不符: {type(e).__name__}: {e}")

    print("=== 4) 自定义/代理地址解析 ===")
    only_host = build_provider(ProviderConfig.from_dict(
        {"provider": "custom", "api_key": "k", "base_url": "https://proxy.example.com"}))
    check("只填主机 → 自动补路径",
          only_host._endpoint("https://api.openai.com/v1/chat/completions", "/v1/chat/completions")
          == "https://proxy.example.com/v1/chat/completions",
          only_host._endpoint("https://api.openai.com/v1/chat/completions", "/v1/chat/completions"))

    full = build_provider(ProviderConfig.from_dict(
        {"provider": "custom", "api_key": "k", "base_url": "https://proxy.example.com/v1/chat/completions"}))
    check("填完整地址 → 原样使用",
          full._endpoint("https://api.openai.com/v1/chat/completions", "/v1/chat/completions")
          == "https://proxy.example.com/v1/chat/completions",
          full._endpoint("https://api.openai.com/v1/chat/completions", "/v1/chat/completions"))

    none = build_provider(ProviderConfig.from_dict({"provider": "openai", "api_key": "k"}))
    check("不填地址 → 用官方默认",
          none._endpoint("https://api.openai.com/v1/chat/completions", "/v1/chat/completions")
          == "https://api.openai.com/v1/chat/completions",
          none._endpoint("https://api.openai.com/v1/chat/completions", "/v1/chat/completions"))

    print("=== 5) Mock 通道端到端可用（无需密钥/网络）===")
    mock = build_provider(ProviderConfig.from_dict({"provider": "mock"}))
    results = asyncio.get_event_loop().run_until_complete(
        mock.identify_disease(b"\xff\xd8\xff" + b"0" * 200, None, "zh", "vegetable"))
    check("mock 返回识别结果", bool(results), f"{len(results)} 条")
    if results:
        check("结果含中文病名", bool(getattr(results[0], "disease_name_zh", "")),
              getattr(results[0], "disease_name_zh", ""))
        check("结果含置信度", 0 <= float(results[0].confidence) <= 1,
              str(results[0].confidence))

    reply = asyncio.get_event_loop().run_until_complete(
        mock.chat("你好", [], "zh", "vegetable"))
    check("mock 支持文本对话", isinstance(reply, str) and len(reply) > 0, reply[:40])

    print()
    print(f"通过 {len(PASS)} 项，失败 {len(FAIL)} 项")
    if FAIL:
        print("失败项：" + ", ".join(FAIL))
        return 1
    print("全部通过：后台改 AI 配置后，AI 服务可在不重启的情况下立即使用新通道")
    return 0


if __name__ == "__main__":
    sys.exit(main())
