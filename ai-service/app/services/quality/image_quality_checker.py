"""图片质量检测器 — 农业图片前置校验

检测项: 模糊度(Laplacian方差) | 亮度 | 绿色区域占比 | 分辨率 | 文件大小

集成方式:
    from app.services.quality.image_quality_checker import image_quality_checker
    result = image_quality_checker.check(image_bytes)
    if not result.is_acceptable:
        return {"error": result.rejection_message, "suggestions": result.suggestions_zh}
"""
import io
from dataclasses import dataclass, field
from enum import Enum


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
        - 绿色占比: 3%-95%
    """

    MIN_WIDTH = 200
    MIN_HEIGHT = 150
    MIN_FILE_SIZE_KB = 5
    SHARPNESS_THRESHOLD = 30   # 低于此→REJECT
    SHARPNESS_GOOD = 120       # 高于此→GOOD
    BRIGHTNESS_MIN = 40
    BRIGHTNESS_MAX = 240
    GREEN_RATIO_MIN = 0.03
    GREEN_RATIO_MAX = 0.95     # 超过95%绿色→异常

    def check(self, image_bytes: bytes) -> QualityReport:
        issues = []
        suggestions_zh = []
        suggestions_lo = []
        grade = QualityGrade.GOOD
        file_size_kb = len(image_bytes) // 1024

        # 加载图片
        try:
            from PIL import Image
            img = Image.open(io.BytesIO(image_bytes))
            width, height = img.size
        except Exception:
            return QualityReport(
                is_acceptable=False, grade=QualityGrade.REJECT, score=0,
                sharpness_score=0, brightness_score=0, green_ratio=0,
                issues=["无法解析图片"],
                rejection_message="图片格式无效，请重新拍摄"
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
        sharpness = self._calc_sharpness(img)
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
        brightness = self._calc_brightness(img)
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

        # 5. 绿色区域占比
        green_ratio = self._calc_green_ratio(img)
        if green_ratio < self.GREEN_RATIO_MIN:
            issues.append(f"绿色区域不足({green_ratio:.1%})")
            suggestions_zh.append("请确保拍摄到植物的叶片或果实部位")
            suggestions_lo.append("ກະລຸນາຖ່າຍໃຫ້ເຫັນໃບ ຫຼື ໝາກຂອງພືດ")
            grade = QualityGrade.worse(grade, QualityGrade.POOR)
        if green_ratio > self.GREEN_RATIO_MAX:
            issues.append(f"绿色占比异常({green_ratio:.1%})，可能非真实照片")
            grade = QualityGrade.worse(grade, QualityGrade.POOR)

        # 综合评分
        green_score = 100 - abs(green_ratio - 0.35) * 200  # 35%绿色最优
        green_score = max(0, min(100, green_score))
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

    # ====== 内部计算方法 ======

    def _calc_sharpness(self, img) -> float:
        """Laplacian方差 — 模仿cv2.Laplacian().var()"""
        try:
            gray = img.convert("L")
            w, h = gray.size
            if w < 3 or h < 3:
                return 0
            pixels = list(gray.getdata())
            step = max(1, min(w, h) // 150)
            vals = []
            for y in range(1, h - 1, step):
                for x in range(1, w - 1, step):
                    c = pixels[y * w + x]
                    n = pixels[(y-1)*w+x] + pixels[(y+1)*w+x] + pixels[y*w+(x-1)] + pixels[y*w+(x+1)]
                    vals.append(4 * c - n)
            if len(vals) < 10: return 0
            m = sum(vals) / len(vals)
            return sum((v - m) ** 2 for v in vals) / len(vals)
        except Exception:
            return 0

    def _calc_brightness(self, img) -> float:
        try:
            gray = img.convert("L")
            pixels = list(gray.getdata())
            return sum(pixels) / len(pixels) if pixels else 128
        except Exception:
            return 128

    def _calc_green_ratio(self, img) -> float:
        try:
            if img.mode != "RGB":
                img = img.convert("RGB")
            pixels = list(img.getdata())
            total = len(pixels)
            sample_rate = max(1, total // 10000)
            green = 0
            sampled = 0
            for i in range(0, total, sample_rate):
                r, g, b = pixels[i]
                if g > r and g > b and g > 60 and (r + b) > 0 and g / (r + b) > 1.1:
                    green += 1
                sampled += 1
            return green / max(sampled, 1)
        except Exception:
            return 0.1


image_quality_checker = ImageQualityChecker()
