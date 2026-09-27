"""用真实语料照片跑一遍质量检测 —— 校准阈值 + 验证内存安全

为什么需要这个工具：
    质量检测的阈值（清晰度 30/120、亮度 40-240、绿色占比 3%-95%）原先只在
    合成小图上试过，从没在老师给的真实照片上验证过。而"清晰度"这类指标
    与图片分辨率强相关，缩略图分析会改变它的绝对值 —— 不校准的话，
    完全可能出现"好照片被判成模糊、直接不给识别"这种最糟的体验。

用法（在生产服务器上，用同一镜像起一次性容器，不碰正在跑的服务）：

    docker run --rm --memory 700m -v /opt/laos-cn-APP/raw_materials:/corpus:ro \
        laos-agri/ai:latest python3 tools/check_corpus_quality.py /corpus

    # 只看前 50 张、按清晰度排序
    docker run --rm -v /opt/laos-cn-APP/raw_materials:/corpus:ro \
        laos-agri/ai:latest python3 tools/check_corpus_quality.py /corpus --limit 50
"""
import argparse
import os
import sys
import time

try:                        # resource 只有 Linux/macOS 有；Windows 上跳过内存统计
    import resource
except ImportError:         # pragma: no cover
    resource = None

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.quality.image_quality_checker import image_quality_checker  # noqa: E402

EXTS = (".jpg", ".jpeg", ".png", ".webp", ".bmp")


def collect(root: str, limit: int = 0):
    found = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in sorted(filenames):
            if name.lower().endswith(EXTS):
                found.append(os.path.join(dirpath, name))
    found.sort()
    return found[:limit] if limit else found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("root", help="语料目录")
    ap.add_argument("--limit", type=int, default=0, help="最多处理多少张（0=全部）")
    args = ap.parse_args()

    paths = collect(args.root, args.limit)
    if not paths:
        print(f"[!] {args.root} 下没找到图片")
        return 1

    print(f"共 {len(paths)} 张，开始检测（容器内存上限应设为 700m 以复现生产环境）\n")
    print(f"{'清晰度':>8} {'亮度':>6} {'绿色':>6} {'等级':>10} {'耗时ms':>7}  文件")
    print("-" * 100)

    sharpness_values = []
    grade_count = {}
    failed = []
    t_all = time.time()

    for p in paths:
        try:
            with open(p, "rb") as f:
                data = f.read()
            t0 = time.time()
            r = image_quality_checker.check(data)
            ms = int((time.time() - t0) * 1000)
            sharpness_values.append(r.sharpness_score)
            grade_count[r.grade.value] = grade_count.get(r.grade.value, 0) + 1
            name = os.path.basename(p)
            if len(name) > 46:
                name = name[:22] + "…" + name[-22:]
            print(f"{r.sharpness_score:8.1f} {r.brightness_score:6.1f} {r.green_ratio:6.2f} "
                  f"{r.grade.value:>10} {ms:7d}  {name}")
        except Exception as e:      # 单张失败不能影响整体统计
            failed.append((p, repr(e)))
            print(f"{'ERR':>8} {'':>6} {'':>6} {'':>10} {'':>7}  {os.path.basename(p)} -> {e}")

    peak_mb = (resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024) if resource else -1
    print("-" * 100)
    if peak_mb >= 0:
        print(f"总耗时 {time.time() - t_all:.1f}s   进程内存峰值 {peak_mb:.0f} MB（容器上限 700MB）")
    else:
        print(f"总耗时 {time.time() - t_all:.1f}s   （当前系统不支持内存统计）")
    if sharpness_values:
        s = sorted(sharpness_values)
        print(f"清晰度得分: 最低 {s[0]:.1f} / 中位 {s[len(s)//2]:.1f} / 最高 {s[-1]:.1f}")
        print("等级分布: " + ", ".join(f"{k}={v}" for k, v in sorted(grade_count.items())))
        rejected = grade_count.get("reject", 0)
        if rejected:
            print(f"\n⚠ 有 {rejected} 张被判为 reject（不会送去识别）。"
                  f"若其中包含肉眼清晰的正常照片，说明清晰度阈值需要下调。")
    if failed:
        print(f"\n⚠ {len(failed)} 张处理失败（不应出现，请把文件名报给开发）：")
        for p, err in failed[:10]:
            print("   ", os.path.basename(p), err)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
