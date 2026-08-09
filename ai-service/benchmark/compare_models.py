"""多模型对比评估 — Sprint 11

对同一测试集用不同模型评估，输出对比报告
用法: python -m benchmark.compare_models
"""
import asyncio
import json
import sys
import time
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from benchmark.evaluate import AgriBenchmark
from app.core.config import settings

# 可对比的模型列表
COMPARABLE_MODELS = [
    {"name": "gemini-3.6-flash", "config": "gemini"},
    {"name": "gemini-2.5-pro", "config": "gemini"},
    {"name": "kimi-k2.6", "config": "kimi"},
]


async def compare(models: list = None):
    """多模型对比评估"""
    if models is None:
        models = COMPARABLE_MODELS

    print(f"\n{'='*60}")
    print(f"  多模型对比评估 — {len(models)} 个模型")
    print(f"  测试集: 共用同一份 labels.json")
    print(f"{'='*60}\n")

    all_reports = []

    for i, model_info in enumerate(models):
        print(f"[{i+1}/{len(models)}] 评估 {model_info['name']} ...")

        # 临时切换 Provider
        original_provider = settings.ai_provider
        original_model = settings.ai_model

        try:
            settings.ai_provider = model_info["config"]
            settings.ai_model = model_info["name"]

            bm = AgriBenchmark()
            cases = bm.load_test_cases()
            real = [c for c in cases if not c.get("id", "").startswith("example")]

            if not real:
                print(f"   ⚠️ 无真实测试用例，跳过")
                continue

            await bm.run_benchmark(limit=min(len(real), 10))
            report = bm.generate_report()
            report["model"] = model_info["name"]
            report["provider_config"] = model_info["config"]
            all_reports.append(report)

            # 简要输出
            s = report.get("summary", {})
            print(f"   Top1: {s.get('top1_accuracy', '?')}% | "
                  f"Top3: {s.get('top3_accuracy', '?')}% | "
                  f"平均: {s.get('avg_time_ms', '?')}ms")

        finally:
            settings.ai_provider = original_provider
            settings.ai_model = original_model

        if i < len(models) - 1:
            await asyncio.sleep(3)

    # 对比总结
    print(f"\n{'='*60}")
    print(f"  模型对比总结")
    print(f"{'='*60}")
    print(f"  {'模型':<25s} {'Top1':>8s} {'Top3':>8s} {'耗时':>8s}")
    print(f"  {'-'*50}")

    for report in all_reports:
        s = report.get("summary", {})
        print(f"  {report['model']:<25s} "
              f"{str(s.get('top1_accuracy','?'))+'%':>8s} "
              f"{str(s.get('top3_accuracy','?'))+'%':>8s} "
              f"{str(s.get('avg_time_ms','?'))+'ms':>8s}")

    # 保存对比报告
    report_path = Path(__file__).resolve().parent.parent.parent / "dataset" / "model_comparison.json"
    comparison = {
        "timestamp": datetime.now().isoformat(),
        "models_compared": len(all_reports),
        "results": all_reports,
    }
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(comparison, f, ensure_ascii=False, indent=2)
    print(f"\n对比报告已保存: {report_path}")

    # 最佳模型推荐
    if all_reports:
        best = max(all_reports, key=lambda r: r.get("summary", {}).get("top1_accuracy", 0))
        print(f"\n🏆 推荐模型: {best['model']} "
              f"(Top1={best['summary']['top1_accuracy']}%)")

    return comparison


if __name__ == "__main__":
    asyncio.run(compare())
