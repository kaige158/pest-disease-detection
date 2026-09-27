"""图片质量检测器 — 农业图片前置校验

检测项: 模糊度(Laplacian方差) | 亮度 | 绿色区域占比 | 分辨率 | 文件大小

集成方式:
    from app.services.quality.image_quality_checker import image_quality_checker
    result = image_quality_checker.check(image_bytes)
    if not result.is_acceptable:
        return {"error": result.rejection_message, "suggestions": result.suggestions_zh}

⚠️ 关于内存（这里踩过一次代价很大的坑，务必看完再改）
------------------------------------------------------------------
原始实现直接对**原图**做 `list(img.getdata())`：

    pixels = list(img.getdata())          # 灰度图：每像素 1 个对象
    pixels = list(img.getdata())          # RGB 图：每像素 1 个 **三元组**

对一张 4000×3000（1200 万像素）的语料照片，RGB 那一句会瞬间构造
1200 万个 tuple（≈700MB~1GB），而 AI 容器只给了 700MB 内存 ——
结果是**每次上传真实照片，AI 服务进程就被内核打死**（客户端只看到
"Empty reply from server"，容器重启次数不断上涨），而小图/坏图测试全都正常。

所以这里的铁律：**任何逐像素的 Python 循环，只允许跑在缩略图上。**
质量检测根本不需要原图分辨率（模糊度、亮度、绿色占比都是统计量），
先缩到 ANALYSIS_SIDE 以内再算，结果几乎不变，内存从 GB 级降到 MB 级。
"""
import io
import logging
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)

#: 逐像素分析用的最大边长 —— 分析图越小越省内存，512 对统计量已足够
ANALYSIS_SIDE = 512

#: 绿色占比是纯采样统计，用更小的图就够
GREEN_ANALYSIS_SIDE = 128


class QualityGrade(str, Enum):
    GOOD = "good"
    ACCEPTABLE = "acceptable"
    POOR = "poor"
    REJECT = "reject"

    @staticmethod
    def worse(a: "QualityGrade", b: "QualityGrade") -> "QualityGrade":
        order = {"good": 0, "acceptable": 1, "poor": 2, "reject": 3}
        return b if order[b.value] > order[a.value] else a


@dataclass
class QualityReport:
    is_acceptable: bool
    grade: QualityGrade
    score: float             # 0-100
    sharpness_score: float   # 0-100
    brightness_score: float  # 0-100
    green_ratio: float       # 0-1
    width: int = 0
    height: int = 0
    file_size_kb: int = 0
    issues: list = field(default_factory=list)
    suggestions_zh: list = field(default_factory=list)
    suggestions_lo: list = field(default_factory=list)
    rejection_message: str = ""


class ImageQualityChecker:
    """农业图片质量检测器

    阈值:
        - 最小分辨率: 200×150px
        - 最小文件: 5KB
        - 清晰度: Laplacian方差 >= 30 (REJECT) / >= 120 (GOOD)
        - 亮度: 平均像素值 40-240
        - 植被占比: ExG>20 的像素比例，>= 10% 才算"拍到了植物"（不足以剔除，仅降级提示）
    """

    MIN_WIDTH = 200
    MIN_HEIGHT = 150
    MIN_FILE_SIZE_KB = 5
    SHARPNESS_THRESHOLD = 30   # 低于此→REJECT
    SHARPNESS_GOOD = 120       # 高于此→GOOD
    BRIGHTNESS_MIN = 40
    BRIGHTNESS_MAX = 240

    # ===== 植被判定：用 ExG（Excess Green = 2G-R-B）=====
    # 这里换过一次算法，原因值得记下来：
    #   旧规则是 `g > r and g > b and g/(r+b) > 1.1`（要求绿色分量超过红蓝之和），
    #   而实拍农业照片大多是灰绿叶、黄绿叶、带阴影的叶片 —— 用老师给的 117 张
    #   真实语料实测，旧规则算出的"绿色占比"中位数是 **0.00**，也就是
    #   几乎每张真实照片都会被判成"没拍到植物"。
    #   ExG 是农业图像里的经典植被指数，同一批语料的中位数是 77.6%，
    #   只有"根部特写 / 虫体特写"这类照片会低于 10% —— 这才是符合直觉的结果。
    EXG_THRESHOLD = 20         # 2G-R-B 大于该值视为植物像素
    GREEN_RATIO_MIN = 0.10     # 低于此→POOR（不阻断识别，只提示）
    GREEN_RATIO_MAX = 0.98     # 接近纯色→可能是绿幕/纯色图
    GREEN_RATIO_IDEAL = 0.75   # 实测中位数，作为满分基准

    def check(self, image_bytes: bytes) -> QualityReport:
        issues = []
        suggestions_zh = []
        suggestions_lo = []
        grade = QualityGrade.GOOD
        file_size_kb = len(image_bytes) // 1024

        # 加载图片
        try:
            from PIL import Image, ImageOps
            img = Image.open(io.BytesIO(image_bytes))
            img.load()
            # 手机竖拍照片带 EXIF 旋转标记，不摆正会让"绿色占比/清晰度"判断失准
            img = ImageOps.exif_transpose(img)
            width, height = img.size
        except Exception as e:
            logger.warning("图片解析失败: %s", e)
            return QualityReport(
                is_acceptable=False, grade=QualityGrade.REJECT, score=0,
                sharpness_score=0, brightness_score=0, green_ratio=0,
                issues=["无法解析图片"],
                rejection_message="图片格式无效，请重新拍摄"
            )

        # 逐像素统计一律在缩略图上做 —— 见文件头注释（原图做会打爆内存）
        try:
            small = self._shrink(img, ANALYSIS_SIDE)
        except Exception as e:
            # 缩略图都做不出来时，宁可放行也不要让识别流程崩掉
            logger.warning("生成分析缩略图失败，跳过质量检测: %s", e)
            return QualityReport(
                is_acceptable=True, grade=QualityGrade.ACCEPTABLE, score=60,
                sharpness_score=60, brightness_score=60, green_ratio=0.3,
                width=width, height=height, file_size_kb=file_size_kb,
                issues=[], rejection_message=""
            )

        # 1. 分辨率
        if width < self.MIN_WIDTH or height < self.MIN_HEIGHT:
            issues.append(f"分辨率过低({width}x{height})")
            suggestions_zh.append("请使用更高分辨率的相机拍摄")
            suggestions_lo.append("ກະລຸນາໃຊ້ກ້ອງທີ່ມີຄວາມລະອຽດສູງກວ່າ")
            grade = QualityGrade.worse(grade, QualityGrade.REJECT)

        # 2. 文件大小
        if file_size_kb < self.MIN_FILE_SIZE_KB:
            issues.append(f"文件过小({file_size_kb}KB)")
            suggestions_zh.append("图片可能不完整，请重新拍摄")
            grade = QualityGrade.worse(grade, QualityGrade.POOR)

        # 3. 清晰度 (Laplacian方差)
        sharpness = self._calc_sharpness(small)
        if sharpness < self.SHARPNESS_THRESHOLD:
            issues.append(f"图片模糊(清晰度{sharpness:.0f})")
            suggestions_zh.append("请对焦清晰后拍摄")
            suggestions_lo.append("ກະລຸນາໂຟກັສໃຫ້ຊັດເຈນ")
            grade = QualityGrade.worse(grade, QualityGrade.REJECT)
        elif sharpness < self.SHARPNESS_GOOD:
            suggestions_zh.append("图片略有模糊，建议稳定拍摄")
            grade = QualityGrade.worse(grade, QualityGrade.ACCEPTABLE)
        sharpness_score = min(100, sharpness / 2.5)  # 250+ → 100

        # 4. 亮度
        brightness = self._calc_brightness(small)
        if brightness < self.BRIGHTNESS_MIN:
            issues.append(f"图片过暗(亮度{brightness:.0f})")
            suggestions_zh.append("请在光线充足处拍摄")
            suggestions_lo.append("ກະລຸນາຖ່າຍໃນບ່ອນມີແສງ")
            grade = QualityGrade.worse(grade, QualityGrade.REJECT)
        elif brightness > self.BRIGHTNESS_MAX:
            issues.append(f"图片过曝(亮度{brightness:.0f})")
            suggestions_zh.append("请避免阳光直射镜头")
            suggestions_lo.append("ກະລຸນາຫຼີກເວັ້ນແສງແດດໂດຍກົງ")
            grade = QualityGrade.worse(grade, QualityGrade.REJECT)
        brightness_score = max(0, min(100, 100 - abs(brightness - 128) / 1.28))

        # 5. 植被区域占比（ExG）
        green_ratio = self._calc_green_ratio(small)
        if green_ratio < self.GREEN_RATIO_MIN:
            issues.append(f"未见明显植物区域(植被占比{green_ratio:.1%})")
            suggestions_zh.append("请尽量把病叶/病果拍进画面")
            suggestions_lo.append("ກະລຸນາຖ່າຍໃຫ້ເຫັນໃບ ຫຼື ໝາກທີ່ເປັນພະຍາດ")
            grade = QualityGrade.worse(grade, QualityGrade.POOR)
        if green_ratio > self.GREEN_RATIO_MAX:
            issues.append(f"植被占比异常({green_ratio:.1%})，可能非真实照片")
            grade = QualityGrade.worse(grade, QualityGrade.POOR)

        # 综合评分
        if green_ratio >= self.GREEN_RATIO_IDEAL:
            green_score = max(60.0, 100 - (green_ratio - self.GREEN_RATIO_IDEAL) * 160)
        else:
            green_score = max(0.0, green_ratio / self.GREEN_RATIO_IDEAL * 100)
        score = sharpness_score * 0.4 + brightness_score * 0.3 + green_score * 0.3
        score = max(0, min(100, score))

        is_acceptable = grade != QualityGrade.REJECT
        rejection_message = ""
        if not is_acceptable:
            rejection_message = "图片质量不合格: " + "; ".join(issues) + "。请重新拍摄。"

        return QualityReport(
            is_acceptable=is_acceptable, grade=grade, score=round(score, 1),
            sharpness_score=round(sharpness_score, 1),
            brightness_score=round(brightness_score, 1),
            green_ratio=round(green_ratio, 3),
            width=width, height=height, file_size_kb=file_size_kb,
            issues=issues, suggestions_zh=suggestions_zh,
            suggestions_lo=suggestions_lo, rejection_message=rejection_message,
        )

    # ====== 内部工具 ======

    @staticmethod
    def _shrink(img, max_side: int):
        """缩到长边不超过 max_side；原图本身够小就直接用"""
        from PIL import Image
        if max(img.size) <= max_side:
            return img
        copy = img.copy()
        copy.thumbnail((max_side, max_side), Image.LANCZOS)
        return copy

    # ====== 内部计算方法 ======
    # 传进来的都是缩略图（见 check()），这里的 list(...) 只会是几十万级、不会爆内存

    def _calc_sharpness(self, img) -> float:
        """Laplacian方差 — 模仿cv2.Laplacian().var()"""
        try:
            gray = img.convert("L")
            w, h = gray.size
            if w < 3 or h < 3:
                return 0
            pixels = list(gray.getdata())      # 缩略图：512×384 ≈ 20 万项，安全
            step = max(1, min(w, h) // 150)
            vals = []
            for y in range(1, h - 1, step):
                for x in range(1, w - 1, step):
                    c = pixels[y * w + x]
                    n = pixels[(y-1)*w+x] + pixels[(y+1)*w+x] + pixels[y*w+(x-1)] + pixels[y*w+(x+1)]
                    vals.append(4 * c - n)
            if len(vals) < 10:
                return 0
            m = sum(vals) / len(vals)
            return sum((v - m) ** 2 for v in vals) / len(vals)
        except Exception as e:
            logger.warning("清晰度计算失败: %s", e)
            return 0

    def _calc_brightness(self, img) -> float:
        try:
            from PIL import ImageStat
            # ImageStat 在 C 层统计直方图，不需要把像素搬进 Python 列表
            return float(ImageStat.Stat(img.convert("L")).mean[0])
        except Exception as e:
            logger.warning("亮度计算失败: %s", e)
            return 128

    def _calc_green_ratio(self, img) -> float:
        """植被占比 = ExG(2G-R-B) 超过阈值的像素比例（详见类常量处的说明）"""
        try:
            # 植被占比只是采样统计：先缩到 128px，再逐像素判断
            small = self._shrink(img, GREEN_ANALYSIS_SIDE)
            if small.mode != "RGB":
                small = small.convert("RGB")
            pixels = list(small.getdata())     # 128×96 ≈ 1.2 万项，安全
            total = len(pixels)
            if total == 0:
                return 0.1
            sample_rate = max(1, total // 10000)
            veg = 0
            sampled = 0
            for i in range(0, total, sample_rate):
                r, g, b = pixels[i]
                if 2 * g - r - b > self.EXG_THRESHOLD:
                    veg += 1
                sampled += 1
            return veg / max(sampled, 1)
        except Exception as e:
            logger.warning("植被占比计算失败: %s", e)
            return 0.1


image_quality_checker = ImageQualityChecker()
