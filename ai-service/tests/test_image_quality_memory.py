"""图片质量检测器回归测试 —— 重点是**内存**，不是准确率

背景（真实事故）：
    质量检测器早期实现直接对原图做 `list(img.getdata())`（RGB 图 = 每像素一个元组），
    一张 4000×3000 的语料照片会瞬间申请 700MB~1GB，而 AI 容器内存上限是 700MB ——
    结果是**每次上传真实照片，AI 服务进程就被打死**（客户端只看到
    "Empty reply from server"，容器重启次数一路上涨），
    而所有用小图/坏图做的测试都是绿的。所以这里专门加了一条内存红线测试。

运行：
    pytest ai-service/tests/test_image_quality_memory.py -v
    （没有 pytest 时也可直接 `python test_image_quality_memory.py`）
"""
import importlib.util
import io
import os
import tracemalloc

from PIL import Image, ImageDraw

#: 逐像素分析阶段允许的 Python 内存峰值 —— 正常应在 10MB 上下，
#: 一旦有人又把 list(img.getdata()) 用在原图上，这里会立刻爆掉（几百 MB）
MAX_PEAK_MB = 60


def _load_checker():
    """直接按文件加载被测模块，避免拉起整个 app 包（测试要能独立跑）"""
    path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "app", "services", "quality", "image_quality_checker.py",
    )
    spec = importlib.util.spec_from_file_location("iqc_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.image_quality_checker


def _make_photo(width=3000, height=2000, green=True) -> bytes:
    """造一张"像照片"的大图：有绿色区域 + 细节纹理（避免被当成纯色图）"""
    img = Image.new("RGB", (width, height), (120, 120, 120))
    draw = ImageDraw.Draw(img)
    if green:
        draw.ellipse([width * 0.1, height * 0.1, width * 0.9, height * 0.9],
                     fill=(60, 150, 60))
    # 加纹理，保证清晰度不是 0
    for i in range(0, width, 37):
        draw.line([(i, 0), (i, height)], fill=(200, 200, 200), width=3)
    for j in range(0, height, 41):
        draw.line([(0, j), (width, j)], fill=(30, 30, 30), width=3)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


def test_large_photo_memory_stays_low():
    """3000×2000（600万像素）真实尺寸照片：峰值内存必须远低于容器上限"""
    checker = _load_checker()
    data = _make_photo(3000, 2000)
    assert len(data) > 100 * 1024, "测试图应该是一张像样的照片"

    tracemalloc.start()
    report = checker.check(data)
    _, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()

    peak_mb = peak / 1024 / 1024
    assert peak_mb < MAX_PEAK_MB, (
        f"质量检测峰值内存 {peak_mb:.1f}MB 超过红线 {MAX_PEAK_MB}MB —— "
        f"是不是又把 list(img.getdata()) 用在原图上了？"
    )
    # 报告里的分辨率必须是**原图**尺寸（缩略图只用于统计，不能影响对外信息）
    assert (report.width, report.height) == (3000, 2000)
    assert report.file_size_kb > 5


def test_blurry_is_rejected_or_lower_scored():
    """模糊图清晰度必须明显低于清晰图（阈值判别仍要有效）"""
    checker = _load_checker()
    sharp = _make_photo(1200, 900)
    blur = io.BytesIO()
    Image.open(io.BytesIO(sharp)).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(12)) \
        .save(blur, format="JPEG", quality=85)

    r_sharp = checker.check(sharp)
    r_blur = checker.check(blur.getvalue())
    assert r_blur.sharpness_score < r_sharp.sharpness_score


def test_broken_bytes_rejected():
    checker = _load_checker()
    r = checker.check(b"not an image at all")
    assert r.is_acceptable is False
    assert "无法解析图片" in r.issues


def test_blank_gray_photo_flagged():
    """纯灰图（无绿色区域）应被判为较差，而不是报错崩掉"""
    checker = _load_checker()
    buf = io.BytesIO()
    Image.new("RGB", (800, 600), (128, 128, 128)).save(buf, format="JPEG", quality=85)
    r = checker.check(buf.getvalue())
    assert r.is_acceptable in (True, False)   # 关键是不抛异常
    assert r.green_ratio <= 0.05


if __name__ == "__main__":
    for fn in (test_large_photo_memory_stays_low, test_blurry_is_rejected_or_lower_scored,
               test_broken_bytes_rejected, test_blank_gray_photo_flagged):
        fn()
        print("PASS", fn.__name__)
    print("全部通过")
