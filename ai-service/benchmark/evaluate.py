"""农业AI Benchmark — 批量测试→准确率报告

用法:
    cd ai-service
    python -m benchmark.evaluate                          # 用 labels.json
    python -m benchmark.evaluate --single ../图片.jpg      # 单张测试
    python -m benchmark.evaluate --limit 10               # 限10张

输出: Top1/Top3准确率、按作物/按病害/按置信度分析、错误案例
"""
import asyncio
import base64
import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime
from typing import List, Dict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.ai_providers.factory import get_ai_provider
from app.core.config import settings


class BenchmarkResult:
    def __init__(self, test_case: dict):
        self.case_id = test_case.get("id", "")
        self.image = test_case.get("image", "")
        self.crop = test_case.get("crop", "")
        self.expert_label = test_case.get("expert_label", "")
        self.ai_prediction = ""
        self.ai_confidence = 0.0
        self.ai_top3 = []
        self.is_correct = False
        self.is_top3_correct = False
        self.processing_time_ms = 0
        self.error = ""


class AgriBenchmark:
    """农业AI评估器"""

    def __init__(self, labels_path: str = None, image_dir: str = None):
        self.labels_path = labels_path or str(
            Path(__file__).resolve().parent.parent.parent / "dataset" / "labels.json"
        )
        self.image_dir = image_dir or str(Path(self.labels_path).parent / "raw_images")
        self.results: List[BenchmarkResult] = []
        self.provider = get_ai_provider()

    def load_test_cases(self) -> List[dict]:
        if not os.path.exists(self.labels_path):
            print(f"[WARN] 标签文件不存在: {self.labels_path}")
            return self._example_cases()
        with open(self.labels_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        cases = data.get("test_cases", [])
        real = [c for c in cases if not c.get("id", "").startswith("example")]
        if not real:
            print("[INFO] 当前只有示例条目，添加真实数据到 dataset/labels.json")
        return cases

    def _example_cases(self) -> List[dict]:
        return [{"id": "example_001", "image": "example_001.jpg", "crop": "番茄", "expert_label": "番茄晚疫病"}]

    async def run_single(self, image_path: str, crop: str = "", expert_label: str = "") -> BenchmarkResult:
        result = BenchmarkResult({"id": os.path.basename(image_path), "image": image_path, "crop": crop, "expert_label": expert_label})
        if not os.path.exists(image_path):
            result.error = f"图片不存在"
            return result
        try:
            with open(image_path, "rb") as f:
                image_bytes = f.read()
            crop_info = {"crop_name": crop} if crop else None
            start = time.time()
            ai_results = await self.provider.identify_disease(image_bytes=image_bytes, crop_info=crop_info, language="zh", version="vegetable")
            result.processing_time_ms = int((time.time() - start) * 1000)
            if ai_results:
                top = ai_results[0]
                result.ai_prediction = top.disease_name_zh
                result.ai_confidence = top.confidence
                result.is_correct = self._match(result.ai_prediction, expert_label)
                if len(ai_results) >= 3:
                    result.ai_top3 = [r.disease_name_zh for r in ai_results[:3]]
                else:
                    result.ai_top3 = [r.disease_name_zh for r in ai_results]
                result.is_top3_correct = any(self._match(n, expert_label) for n in result.ai_top3)
        except Exception as e:
            result.error = str(e)[:200]
        return result

    async def run_benchmark(self, limit: int = None) -> List[BenchmarkResult]:
        cases = self.load_test_cases()
        if limit:
            cases = cases[:limit]
        print(f"\n{'='*60}\n  农业AI Benchmark — {settings.ai_provider}/{settings.ai_model}\n  测试集: {len(cases)} 张\n{'='*60}\n")
        for i, case in enumerate(cases):
            img = case.get("image", "")
            img_path = os.path.join(self.image_dir, img) if not os.path.isabs(img) else img
            print(f"  [{i+1}/{len(cases)}] {case.get('id', img)} ... ", end="", flush=True)
            result = await self.run_single(img_path, case.get("crop", ""), case.get("expert_label", ""))
            self.results.append(result)
            mark = "V" if result.is_correct else "X"
            if result.error:
                print(f"ERR: {result.error[:50]}")
            else:
                print(f"{mark} AI={result.ai_prediction[:25]} | 标签={case.get('expert_label','')[:25]} | {result.ai_confidence:.0%}")
            if i < len(cases) - 1:
                await asyncio.sleep(1.5)
        return self.results

    def generate_report(self) -> dict:
        valid = [r for r in self.results if not r.error]
        if not valid:
            return {"error": "无有效测试结果"}
        total = len(valid)
        correct_top1 = sum(1 for r in valid if r.is_correct)
        correct_top3 = sum(1 for r in valid if r.is_top3_correct)

        # 按作物
        by_crop = {}
        for r in valid:
            c = r.crop or "未知"
            if c not in by_crop: by_crop[c] = {"total": 0, "correct": 0}
            by_crop[c]["total"] += 1
            if r.is_correct: by_crop[c]["correct"] += 1

        # 按病害
        by_disease = {}
        for r in valid:
            d = r.expert_label or "未知"
            if d not in by_disease: by_disease[d] = {"total": 0, "correct": 0}
            by_disease[d]["total"] += 1
            if r.is_correct: by_disease[d]["correct"] += 1

        # 置信度分析
        high = [r for r in valid if r.ai_confidence >= 0.90]
        mid = [r for r in valid if 0.70 <= r.ai_confidence < 0.90]
        low = [r for r in valid if r.ai_confidence < 0.70]

        return {
            "benchmark_time": datetime.now().isoformat(),
            "provider": settings.ai_provider,
            "model": settings.ai_model,
            "summary": {
                "total_tested": len(self.results),
                "valid_results": total,
                "errors": len(self.results) - total,
                "top1_accuracy": round(correct_top1 / total * 100, 1),
                "top3_accuracy": round(correct_top3 / total * 100, 1),
                "avg_time_ms": round(sum(r.processing_time_ms for r in valid) / total, 0),
            },
            "by_crop": {c: {"total": d["total"], "correct": d["correct"], "accuracy": round(d["correct"]/max(d["total"],1)*100,1)} for c, d in sorted(by_crop.items())},
            "by_disease": {d: {"total": v["total"], "correct": v["correct"], "accuracy": round(v["correct"]/max(v["total"],1)*100,1)} for d, v in sorted(by_disease.items(), key=lambda x: -x[1]["total"])[:20]},
            "confidence_reliability": {
                "high_conf_accuracy": round(sum(1 for r in high if r.is_correct)/max(len(high),1)*100, 1),
                "mid_conf_accuracy": round(sum(1 for r in mid if r.is_correct)/max(len(mid),1)*100, 1),
                "low_conf_accuracy": round(sum(1 for r in low if r.is_correct)/max(len(low),1)*100, 1),
                "high_count": len(high), "mid_count": len(mid), "low_count": len(low),
            },
            "wrong_cases": [{"id": r.case_id, "crop": r.crop, "expert": r.expert_label, "ai_predicted": r.ai_prediction, "confidence": round(r.ai_confidence,4)} for r in valid if not r.is_correct][:20],
        }

    def print_report(self, report: dict):
        s = report["summary"]
        print(f"\n{'='*60}\n  AI准确率报告\n{'='*60}")
        print(f"  Provider: {report['provider']}/{report['model']}")
        print(f"  测试: {s['total_tested']} (有效{s['valid_results']}) | 平均{s['avg_time_ms']}ms")
        print(f"\n  Top1准确率: {s['top1_accuracy']}%")
        print(f"  Top3准确率: {s['top3_accuracy']}%\n")
        by_crop = report.get("by_crop", {})
        if by_crop:
            print("  [按作物]")
            for crop, d in by_crop.items():
                bar = "#" * int(d["accuracy"] / 10) + "-" * (10 - int(d["accuracy"] / 10))
                print(f"    {crop:12s} {bar} {d['accuracy']}% ({d['correct']}/{d['total']})")
        cr = report.get("confidence_reliability", {})
        print(f"\n  [置信度可靠性]")
        print(f"    高(>=90%): {cr['high_conf_accuracy']}% ({cr['high_count']}条)")
        print(f"    中(70-90%): {cr['mid_conf_accuracy']}% ({cr['mid_count']}条)")
        print(f"    低(<70%): {cr['low_conf_accuracy']}% ({cr['low_count']}条)")
        wrong = report.get("wrong_cases", [])
        if wrong:
            print(f"\n  [错误案例 TOP{min(len(wrong),5)}]")
            for w in wrong[:5]:
                print(f"    {w['crop']}: AI[{w['ai_predicted']}] != 标签[{w['expert']}]")
        print(f"{'='*60}")

    def save_report(self, report: dict, path: str = None):
        path = path or str(Path(self.labels_path).parent / "benchmark_report.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        print(f"  报告已保存: {path}")

    @staticmethod
    def _match(ai_name: str, expert_name: str) -> bool:
        if not ai_name or not expert_name: return False
        a, e = ai_name.strip().lower(), expert_name.strip().lower()
        if a == e or e in a or a in e: return True
        a2 = a.replace("病","").replace("虫","")
        e2 = e.replace("病","").replace("虫","")
        return a2 == e2 or e2 in a2 or a2 in e2


async def main():
    import argparse
    p = argparse.ArgumentParser(description="农业AI Benchmark")
    p.add_argument("--labels", help="labels.json路径")
    p.add_argument("--image-dir", help="图片目录")
    p.add_argument("--limit", type=int, help="限制数量")
    p.add_argument("--single", help="单张图片测试")
    p.add_argument("--crop", default="", help="作物名")
    p.add_argument("--expert", default="", help="专家标签")
    p.add_argument("--output", help="报告输出路径")
    args = p.parse_args()

    bm = AgriBenchmark(labels_path=args.labels, image_dir=args.image_dir)
    if args.single:
        print(f"单张测试: {args.single}")
        r = await bm.run_single(args.single, args.crop, args.expert)
        print(f"  AI: {r.ai_prediction} | 置信度: {r.ai_confidence:.0%} | {'正确' if r.is_correct else '错误'} | {r.processing_time_ms}ms")
        if r.error: print(f"  错误: {r.error}")
        return
    await bm.run_benchmark(limit=args.limit)
    report = bm.generate_report()
    bm.print_report(report)
    bm.save_report(report, args.output)

if __name__ == "__main__":
    asyncio.run(main())
