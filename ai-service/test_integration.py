"""Sprint 10.3 全链路端到端集成测试 (用Mock避开API限流)"""
import sys, io, base64, time, json, asyncio, random

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.path.insert(0, '.')

async def main():
    print('=== 识别管线集成测试 (Mock Provider) ===\n')
    random.seed(123)

    # 1. 生成模拟病害图片
    from PIL import Image, ImageDraw
    img = Image.new('RGB', (500, 400), color=(70, 110, 50))
    draw = ImageDraw.Draw(img)
    draw.ellipse([80, 40, 420, 360], fill=(40, 120, 40), outline=(20, 70, 20), width=4)
    for _ in range(15):
        x = random.randint(120, 380); y = random.randint(80, 320)
        r = random.randint(6, 20)
        draw.ellipse([x-r, y-r, x+r, y+r], fill=(100, 60, 30))
    buf = io.BytesIO(); img.save(buf, format='JPEG', quality=85)
    image_bytes = buf.getvalue()
    print(f'[1/5] 图片: 500x400 JPEG {len(image_bytes)//1024}KB')

    # 2. 图片质量检测 — Sprint 10.3
    from app.services.quality.image_quality_checker import image_quality_checker
    quality = image_quality_checker.check(image_bytes)
    print(f'[2/5] 质量检测: {quality.grade.value} | 清晰度{quality.sharpness_score} | 亮度{quality.brightness_score} | 绿色{quality.green_ratio:.1%}')
    assert quality.is_acceptable, '质量检测失败!'

    # 3. AI识别 — Mock Provider (避免Gemini限流)
    from app.services.ai_providers.mock_provider import MockAIProvider
    mock = MockAIProvider()
    results = await mock.identify_disease(
        image_bytes=image_bytes, crop_info={'crop_name': '番茄'},
        language='zh', version='vegetable'
    )
    top = results[0]
    print(f'[3/5] Mock AI: {top.disease_name_zh} | 置信度{top.confidence:.0%}')
    assert results and len(results) > 0

    # 4. 置信度策略 — Sprint 10.3
    from app.services.quality.confidence_manager import confidence_manager
    decision = confidence_manager.decide(
        confidence=top.confidence, top_result_name=top.disease_name_zh,
        alternatives=[r.disease_name_zh for r in results[1:4]] if len(results)>1 else [],
        language='zh'
    )
    print(f'[4/5] 策略: {decision.action.value} | 直接返回={decision.can_direct_return} | 需审核={decision.need_expert_review}')

    # 5. 组装完整响应 + 入库记录
    response = top.to_dict()
    response = confidence_manager.enrich_api_response(response, decision)
    response['image_quality'] = {'score': quality.score, 'grade': quality.grade.value}
    record = {
        'task_id': f'rec_{int(time.time())}',
        'disease_name_zh': response.get('disease_name_zh'),
        'disease_name_lo': response.get('disease_name_lo'),
        'confidence': response.get('confidence'),
        'confidence_level': response.get('confidence_level'),
        'confidence_action': response.get('confidence_action'),
        'provider_used': 'mock',
        'need_expert_review': response.get('need_expert_review'),
        'user_hint_zh': response.get('user_hint_zh', '')[:60],
        'image_quality_score': quality.score,
    }
    print(f'[5/5] 入库记录: {json.dumps(record, ensure_ascii=False, indent=2)[:300]}')

    # 全字段验证
    required = ['task_id', 'disease_name_zh', 'confidence', 'provider_used', 'need_expert_review']
    for f in required:
        assert f in record and record[f] is not None, f'缺少字段: {f}'

    print('\n=== 全链路测试通过! ===')

    # 也验证坏图被拒绝
    print('\n--- 补充: 坏图拒绝测试 ---')
    img2 = Image.new('RGB', (40, 40), color=(5, 5, 5))
    buf2 = io.BytesIO(); img2.save(buf2, format='JPEG', quality=20)
    q2 = image_quality_checker.check(buf2.getvalue())
    assert not q2.is_acceptable, '坏图应被拒绝'
    print(f'坏图: 接受={q2.is_acceptable} 问题={q2.issues}')

    print('\n=== Sprint 10.3 端到端验证: 全部通过! ===')

asyncio.run(main())
