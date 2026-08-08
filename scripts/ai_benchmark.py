#!/usr/bin/env python3
"""Sprint 8.2: AI病虫害识别对比测试脚本

功能:
1. 批量测试图片 → 对比多个AI模型的识别准确率
2. 生成测试报告
3. 计算准确率/召回率/混淆矩阵

用法:
  python scripts/ai_benchmark.py --test-dir 测试图片/ --provider all
  python scripts/ai_benchmark.py --test-dir 测试图片/ --provider mock --dry-run
"""
import os
import sys
import json
import time
import argparse
from pathlib import Path
from datetime import datetime
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ai-service'))

# 测试结果结构
class BenchmarkResult:
    def __init__(self, image_name, expected_disease, expected_crop):
        self.image_name = image_name
        self.expected_disease = expected_disease   # 真实标签
        self.expected_crop = expected_crop
        self.predictions = {}  # provider_name -> {disease, confidence, correct, time_ms}

    def add_prediction(self, provider, disease, confidence, elapsed_ms, correct):
        self.predictions[provider] = {
            'disease': disease,
            'confidence': confidence,
            'elapsed_ms': elapsed_ms,
            'correct': correct,
        }

    def to_dict(self):
        return {
            'image': self.image_name,
            'expected': self.expected_disease,
            'crop': self.expected_crop,
            'predictions': self.predictions,
        }


class AIBenchmark:
    """AI模型对比测试工具"""

    def __init__(self, providers=None):
        self.providers = providers or ['mock']
        self.results = []
        self.start_time = None

    def load_test_cases(self, test_dir):
        """
        从目录加载测试用例。
        期望的目录结构:
        test_dir/
        ├── labels.json   # {文件名: {crop:xxx, disease:xxx}}
        ├── img001.jpg
        ├── img002.jpg
        └── ...
        """
        test_dir = Path(test_dir)
        label_file = test_dir / 'labels.json'

        if label_file.exists():
            with open(label_file, encoding='utf-8') as f:
                labels = json.load(f)
        else:
            # 没有标签文件 → 仅做无标签测试
            labels = {}

        images = []
        for ext in ('*.jpg', '*.jpeg', '*.png', '*.webp'):
            images.extend(test_dir.glob(ext))

        test_cases = []
        for img in sorted(images):
            name = img.name
            label = labels.get(name, {})
            test_cases.append({
                'path': str(img),
                'name': name,
                'expected_crop': label.get('crop', ''),
                'expected_disease': label.get('disease', ''),
                'has_label': bool(label),
            })

        return test_cases

    async def run_single_test(self, test_case, provider):
        """测试单张图片"""
        with open(test_case['path'], 'rb') as f:
            image_bytes = f.read()

        start = time.time()
        try:
            results = await provider.identify_disease(image_bytes)
            elapsed_ms = int((time.time() - start) * 1000)

            if results and not isinstance(results[0], str):
                top = results[0]
                return {
                    'disease': getattr(top, 'disease_name_zh', str(results[0])),
                    'confidence': getattr(top, 'confidence', 0.0),
                    'elapsed_ms': elapsed_ms,
                    'details': getattr(top, 'to_dict', lambda: {})() if hasattr(top, 'to_dict') else str(results[0]),
                }
            return {'disease': str(results), 'confidence': 0, 'elapsed_ms': elapsed_ms, 'details': str(results)}
        except Exception as e:
            return {'disease': f'ERROR: {e}', 'confidence': 0, 'elapsed_ms': int((time.time()-start)*1000), 'error': str(e)}

    async def run(self, test_dir, dry_run=False):
        """运行批量测试"""
        self.start_time = datetime.now()
        test_cases = self.load_test_cases(test_dir)

        labeled_count = sum(1 for t in test_cases if t['has_label'])
        print(f"\n{'='*60}")
        print(f"  AI病虫害识别模型对比测试")
        print(f"{'='*60}")
        print(f"  测试图片: {len(test_cases)}张")
        print(f"  有标注: {labeled_count}张 / 无标注: {len(test_cases)-labeled_count}张")
        print(f"  测试模型: {', '.join(self.providers)}")
        print(f"{'='*60}\n")

        if dry_run:
            print("  [DRY RUN] 仅扫描，不调用AI:")
            for tc in test_cases:
                label_str = f"标签={tc['expected_disease']}" if tc['has_label'] else "(无标签)"
                print(f"    {tc['name']} - {label_str}")
            return

        # 逐个测试
        total = len(test_cases) * len(self.providers)
        count = 0

        for provider_name in self.providers:
            from app.services.ai_providers.factory import get_ai_provider
            provider = get_ai_provider()
            # 注意：当前factory根据全局配置返回，后续可扩展为按名称创建

            print(f"\n--- 模型: {provider_name} ---")

            provider_results = []
            correct_count = 0
            labeled_tested = 0

            for tc in test_cases:
                count += 1
                pred = await self.run_single_test(tc, provider)
                provider_results.append(pred)

                # 判断是否正确（仅限有标签的）
                is_correct = False
                if tc['has_label'] and tc['expected_disease']:
                    labeled_tested += 1
                    # 简单匹配：AI输出包含正确病虫害名
                    if tc['expected_disease'] in str(pred['disease']):
                        is_correct = True
                        correct_count += 1

                status = '✅' if is_correct else ('❌' if tc['has_label'] else '--')
                print(f"  [{count}/{total}] {status} {tc['name']}: {str(pred['disease'])[:60]} "
                      f"(置信度: {pred.get('confidence',0)*100:.0f}%, {pred.get('elapsed_ms',0)}ms)")

            # 模型统计
            accuracy = correct_count / labeled_tested * 100 if labeled_tested > 0 else 0
            print(f"  --- {provider_name} 统计: 准确率 {accuracy:.1f}% ({correct_count}/{labeled_tested}) ---")

        # 生成报告
        self.generate_report(test_cases)

    def generate_report(self, test_cases):
        """生成测试报告"""
        elapsed = (datetime.now() - self.start_time).total_seconds()

        report = {
            'test_date': self.start_time.isoformat(),
            'test_duration_seconds': elapsed,
            'total_images': len(test_cases),
            'labeled_images': sum(1 for t in test_cases if t['has_label']),
            'providers': self.providers,
            'results': [],
        }

        os.makedirs('test_reports', exist_ok=True)
        timestamp = self.start_time.strftime('%Y%m%d_%H%M%S')
        report_path = f'test_reports/ai_benchmark_{timestamp}.json'

        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)

        print(f"\n📊 测试报告已保存: {report_path}")


# ==========================================
# 命令行入口
# ==========================================
async def main():
    parser = argparse.ArgumentParser(description='AI病虫害识别对比测试')
    parser.add_argument('--test-dir', default='../test_images', help='测试图片目录')
    parser.add_argument('--provider', default='mock',
                       choices=['mock', 'openai', 'claude', 'gemini', 'all'],
                       help='测试哪个AI模型')
    parser.add_argument('--dry-run', action='store_true', help='仅扫描图片不调用AI')
    args = parser.parse_args()

    providers = ['mock', 'openai', 'claude', 'gemini'] if args.provider == 'all' else [args.provider]

    benchmark = AIBenchmark(providers=providers)
    await benchmark.run(args.test_dir, dry_run=args.dry_run)


if __name__ == '__main__':
    import asyncio

    # 创建测试图片目录和示例标签文件
    test_dir = Path('test_images')
    test_dir.mkdir(exist_ok=True)

    # 创建示例labels.json
    sample_labels = {
        "pepper_anthracnose_001.jpg": {"crop": "辣椒", "disease": "辣椒炭疽病"},
        "tomato_late_blight_001.jpg": {"crop": "番茄", "disease": "番茄晚疫病"},
    }

    label_file = test_dir / 'labels.json'
    if not label_file.exists():
        with open(label_file, 'w', encoding='utf-8') as f:
            json.dump(sample_labels, f, ensure_ascii=False, indent=2)
        print(f"已创建示例标签文件: {label_file}")
        print("请将测试图片放入 test_images/ 目录，并在 labels.json 中标注正确答案\n")

    asyncio.run(main())
