"""端到端测试: API识别流程（模拟 /api/v1/recognition/identify）
用法:
    python test_e2e.py                    # 用测试图片
    python test_e2e.py --image 图片路径    # 用真实图片
"""
import asyncio
import base64
import io
import sys
import os
import time

# Windows终端UTF-8支持
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.ai_providers.factory import get_ai_provider
from app.services.ai_providers.parser import AIResponseParser
from app.core.config import settings


async def test_identify(image_bytes: bytes, crop_name: str = "", language: str = "zh", version: str = "vegetable"):
    """完全模拟 /api/v1/recognition/identify 的流程"""
    start_time = time.time()

    print(f"  图片大小: {len(image_bytes)//1024}KB")
    print(f"  作物提示: {crop_name or '(无)'}")
    print(f"  语言: {language} | 版本: {version}")

    # Step 1: 构建作物信息
    crop_info = None
    if crop_name:
        crop_info = {"crop_name": crop_name}

    # Step 2: 调用AI Provider
    print("  → 调用 Gemini API...")
    provider = get_ai_provider()
    print(f"  Provider: {provider.provider_name} | Model: {settings.ai_model}")

    results = await provider.identify_disease(
        image_bytes=image_bytes,
        crop_info=crop_info,
        language=language,
        version=version,
    )

    # Step 3: 解析（如果是原始文本）
    if results and isinstance(results[0], str):
        raw_text = "\n".join(results)
        results = AIResponseParser.parse(raw_text, provider.provider_name, language)

    # Step 4: 格式化输出
    elapsed_ms = int((time.time() - start_time) * 1000)

    if not results:
        print("  [FAIL] AI未能识别出病虫害")
        return None

    top = results[0]
    data = top.to_dict()
    data["total_time_ms"] = elapsed_ms

    return data


def print_result(data: dict):
    """美化打印识别结果"""
    print(f"\n{'='*60}")
    print(f"  识别结果")
    print(f"{'='*60}")
    print(f"  病虫害: {data.get('disease_name_zh', '?')}")
    print(f"  老挝语: {data.get('disease_name_lo', '?')}")
    print(f"  学名:   {data.get('scientific_name', '?')}")
    print(f"  类型:   {data.get('type', '?')}")
    print(f"  置信度: {data.get('confidence', 0)*100:.0f}%")
    print(f"  级别:   {data.get('confidence_level', '?')}")
    print(f"  严重度: {data.get('severity', '?')}")
    print(f"  症状:   {data.get('symptoms_zh', '?')[:120]}")
    print(f"  条件:   {data.get('conditions_zh', '?')[:120]}")
    print(f"  耗时:   {data.get('total_time_ms', 0)}ms")
    print(f"  Provider: {data.get('provider', '?')}")

    prevention = data.get('prevention', {})
    if prevention:
        chem = prevention.get('chemical', [])
        bio = prevention.get('biological', [])
        cult = prevention.get('cultivation', [])
        if chem:
            print(f"\n  [化学防治]")
            for c in chem[:3]:
                print(f"    - {c.get('method_zh', '')}: {c.get('details_zh', '')[:80]}")
        if bio:
            print(f"\n  [生物防治]")
            for b in bio[:3]:
                print(f"    - {b.get('method_zh', '')}: {b.get('details_zh', '')[:80]}")
        if cult:
            print(f"\n  [栽培管理]")
            for cu in cult[:3]:
                text = cu.get('method_zh', cu) if isinstance(cu, dict) else str(cu)
                print(f"    - {text[:120]}")

    print(f"{'='*60}")


async def main():
    print("\n" + "=" * 60)
    print("  端到端测试: Flutter拍照 → AI识别 → 标准化结果")
    print("=" * 60)
    print(f"  AI_PROVIDER: {settings.ai_provider}")
    print(f"  AI_MODEL:    {settings.ai_model}")
    print(f"  API Key:     {settings.ai_api_key[:8]}...{settings.ai_api_key[-4:]}")
    print("=" * 60)

    # 准备测试图片
    image_path = None
    if len(sys.argv) > 2 and sys.argv[1] == "--image":
        image_path = sys.argv[2]

    if image_path and os.path.exists(image_path):
        with open(image_path, "rb") as f:
            image_bytes = f.read()
        print(f"\n[测试] 真实图片: {image_path}")
    else:
        # 生成测试图片（模拟叶片）
        print(f"\n[测试] 无真实图片，生成模拟图片...")
        try:
            from PIL import Image, ImageDraw
            # 画一个简单的绿色叶片形状
            img = Image.new("RGB", (400, 300), color=(200, 220, 200))
            draw = ImageDraw.Draw(img)
            # 叶片椭圆
            draw.ellipse([50, 50, 350, 250], fill=(34, 139, 34), outline=(0, 100, 0), width=3)
            # 斑点（模拟病害）
            for x, y, r in [(150, 130, 15), (220, 160, 12), (180, 170, 10), (260, 140, 14)]:
                draw.ellipse([x-r, y-r, x+r, y+r], fill=(139, 69, 19), outline=(101, 67, 33))
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=90)
            image_bytes = buf.getvalue()
            print(f"  生成模拟叶片病害图片: {len(image_bytes)//1024}KB")
        except ImportError:
            print("  无PIL，用简单绿色方块")
            img = Image.new("RGB", (200, 200), color=(34, 139, 34))
            buf = io.BytesIO()
            img.save(buf, format="JPEG")
            image_bytes = buf.getvalue()

    # 测试1: 不带作物提示
    print(f"\n--- 测试A: 无作物提示 ---")
    try:
        result = await test_identify(image_bytes, crop_name="")
        if result:
            print_result(result)
    except Exception as e:
        print(f"  [FAIL] {e}")
        import traceback
        traceback.print_exc()

    # 测试2: 带作物提示
    print(f"\n--- 测试B: 作物提示=番茄 ---")
    try:
        result = await test_identify(image_bytes, crop_name="番茄")
        if result:
            print_result(result)
    except Exception as e:
        print(f"  [FAIL] {e}")

    # 测试3: 对话
    print(f"\n--- 测试C: AI对话 ---")
    try:
        provider = get_ai_provider()
        reply = await provider.chat(
            message="番茄叶片上出现褐色斑点，是什么病？怎么治？",
            history=[],
            language="zh",
            version="vegetable",
        )
        print(f"  问题: 番茄叶片上出现褐色斑点，是什么病？")
        print(f"  回答: {reply[:300]}")
    except Exception as e:
        print(f"  [FAIL] {e}")

    print(f"\n{'='*60}")
    print(f"  Sprint 10.1 第3步: 端到端测试完成!")
    print(f"{'='*60}")


if __name__ == "__main__":
    asyncio.run(main())
