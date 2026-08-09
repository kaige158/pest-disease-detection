"""Gemini Provider 连通性测试脚本

用法:
    cd ai-service
    python test_gemini.py                    # 基础文本对话测试
    python test_gemini.py --image 图片路径    # 图片识别测试
"""
import asyncio
import sys
import os
import io

# Windows终端UTF-8支持
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.ai_providers.gemini_provider import GeminiProvider
from app.services.ai_providers.base import ChatMessage
from app.core.config import settings


async def test_chat():
    """测试文本对话"""
    print("=" * 60)
    print("[测试1] Gemini 文本对话")
    print(f"   Provider: {settings.ai_provider}")
    print(f"   Model: {settings.ai_model}")
    api_key = settings.ai_api_key
    if len(api_key) > 12:
        print(f"   API Key: {api_key[:8]}...{api_key[-4:]}")
    else:
        print(f"   API Key: {api_key[:10]}...")
    print("=" * 60)

    provider = GeminiProvider()

    try:
        result = await provider.chat(
            message="请用一句话介绍你自己",
            history=[],
            language="zh",
            version="vegetable",
        )
        print(f"[OK] 对话成功!")
        print(f"   回复: {result[:300]}")
        return True
    except Exception as e:
        print(f"[FAIL] 对话失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def test_identify_disease(image_path: str = None):
    """测试图片识别"""
    print("\n" + "=" * 60)
    print("[测试2] Gemini 图片识别")
    print("=" * 60)

    provider = GeminiProvider()

    if image_path and os.path.exists(image_path):
        with open(image_path, "rb") as f:
            image_bytes = f.read()
        print(f"   使用图片: {image_path} ({len(image_bytes)//1024}KB)")
    else:
        print("   无真实图片，生成测试用绿色方块图片...")
        try:
            from PIL import Image
            img = Image.new("RGB", (200, 200), color="green")
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=85)
            image_bytes = buf.getvalue()
        except ImportError:
            print("   [SKIP] 需要PIL来生成测试图片，跳过图片识别测试")
            return None

    try:
        results = await provider.identify_disease(
            image_bytes=image_bytes,
            crop_info={"crop_name": "番茄"},
            language="zh",
            version="vegetable",
        )
        if results:
            print(f"[OK] 识别成功! 返回 {len(results)} 个结果:")
            for r in results:
                name = r.disease_name_zh[:80] if r.disease_name_zh else "(空)"
                print(f"   - {name}")
                print(f"     置信度: {r.confidence}")
                print(f"     级别: {r.confidence_level.value}")
                print(f"     类型: {r.disease_type}")
                if r.prevention_plan and r.prevention_plan.chemical:
                    print(f"     化学防治建议: {len(r.prevention_plan.chemical)}条")
            return True
        else:
            print("[WARN] 识别返回空结果")
            return False
    except Exception as e:
        print(f"[FAIL] 识别失败: {e}")
        import traceback
        traceback.print_exc()
        return False


async def main():
    print("\n=== 中老双语农业病虫害防控 -- Gemini Provider 测试 ===\n")

    # 检查配置
    if not settings.ai_api_key or "your-api-key" in settings.ai_api_key.lower():
        print("=" * 60)
        print("[WARN] 请先配置 Gemini API Key!")
        print("=" * 60)
        print("\n获取步骤:")
        print("1. 打开 https://aistudio.google.com/apikey")
        print("2. 登录Google账号 -> Create API Key")
        print("3. 复制Key (格式: AIza...)")
        print(f"4. 修改 {os.path.join(os.path.dirname(__file__), '.env')} 中的 AI_API_KEY")
        print(f"\n当前配置:")
        print(f"   AI_PROVIDER = {settings.ai_provider}")
        print(f"   AI_API_KEY  = {settings.ai_api_key[:20]}...")
        print(f"   AI_MODEL    = {settings.ai_model}")
        return

    # 测试1: 文本对话
    chat_ok = await test_chat()

    # 测试2: 图片识别
    image_path = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == "--image" else None
    image_ok = await test_identify_disease(image_path)

    # 总结
    print("\n" + "=" * 60)
    print("[测试总结]")
    chat_status = "PASS" if chat_ok else "FAIL"
    if image_ok is True:
        img_status = "PASS"
    elif image_ok is False:
        img_status = "FAIL"
    else:
        img_status = "SKIP"
    print(f"   文本对话: {chat_status}")
    print(f"   图片识别: {img_status}")

    if chat_ok and image_ok is not False:
        print("\n[SUCCESS] Gemini Provider 工作正常!")
    else:
        print("\n[WARN] 部分测试失败，请检查API Key和网络连接。")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
