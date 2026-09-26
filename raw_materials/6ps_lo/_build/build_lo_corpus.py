#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""6ps 语料老挝语版打包脚本 —— 生成交付给老挝语专家审核的双语语料包。

产物（全部在 raw_materials/6ps_lo/ 下）:
    T1-01_ພະຍາດ.../01_....jpg     ← 与中文语料一一对应的照片，文件名用老挝语
    ...
    _index_lo.csv                   中老对照索引（按分类汇总，一页看完 49 条）
    _review_sheet.csv               审校工作单（老师逐行批注：确认/改译/备注）
    _glossary_lo.csv                术语词表（作物名 + 病虫害名 + 症状词，供老师统一口径）
    _manifest_lo.json               机读映射（asset_id ↔ 老挝语文件名 ↔ 中文原名）
    README.md                       交付说明（怎么审、怎么回填）

设计约束（与 scripts/import_corpus.py 保持一致）:
    1. 不臆造专家知识 —— 只翻译"名称"，不新增症状/防控内容
    2. 译名分三档来源，老师一眼能看出哪些是项目已有、哪些是本次新译
       A=项目数据库已有译名  B=沿用项目既有命名公式  C=本次新译，需重点确认
    3. 幂等 —— 可重复执行；不修改中文原始语料，只读取
    4. 照片用硬链接落盘（同盘 NTFS 秒级完成，不额外占空间）；失败自动退回复制
    5. 编号与中文语料/T1-01 一一对应，中文原文件名完整保留在索引里

用法:
    python raw_materials/6ps_lo/_build/build_lo_corpus.py            # 生成
    python raw_materials/6ps_lo/_build/build_lo_corpus.py --check    # 只校验，不落盘
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SRC_ROOT = REPO_ROOT / "raw_materials" / "6ps"
OUT_ROOT = REPO_ROOT / "raw_materials" / "6ps_lo"
MANIFEST_ZH = REPO_ROOT / "dataset" / "corpus_manifest.json"

LAO_RANGE = (0x0E80, 0x0EFF)

# ==========================================================================
# 一、术语词表
# ==========================================================================
# source: DB   = 项目数据库/离线库已有译名（seed_data_v1.sql / offline_knowledge.dart）
#         STD  = 农业植保通用术语，与项目既有命名公式一致
#         NEW  = 本次新译，需老师重点确认
# review: True = 建议老师逐字确认

TERMS = [
    # ---- 作物 ----
    ("辣椒",   "ໝາກເຜັດ",        "crop", "DB",  False),
    ("番茄",   "ໝາກເລັ່ນ",       "crop", "DB",  False),
    ("黄瓜",   "ໝາກແຕງ",         "crop", "DB",  False),
    ("白菜",   "ຜັກກາດຂາວ",      "crop", "DB",  False),
    ("大白菜", "ຜັກກາດຂາວ",      "crop", "DB",  False),
    ("茄子",   "ໝາກເຂືອ",        "crop", "DB",  False),
    ("南瓜",   "ໝາກອຶ",          "crop", "STD", True),
    ("西兰花", "ຜັກບຣັອກໂຄລີ",    "crop", "DB",  False),
    ("萝卜",   "ຫົວຜັກກາດ",      "crop", "STD", True),
    ("芥菜",   "ຜັກກາດເຂົ້າ",    "crop", "NEW", True),
    ("卷心菜", "ຜັກກາດຫົວ",      "crop", "STD", True),
    # ---- 病原 / 病害大类 ----
    ("腐霉菌属", "ເຊື້ອຣາ Pythium",             "pathogen", "NEW", True),
    ("猝倒病",   "ພະຍາດໂຄນເນົ່າ",              "disease",  "NEW", True),
    ("立枯病",   "ພະຍາດໂຄນແຫ້ງ",              "disease",  "NEW", True),
    ("霜霉病",   "ພະຍາດຂີ້ຝຸ່ນ",               "disease",  "DB",  False),
    ("白粉病",   "ພະຍາດຂີ້ຝຸ່ນຂາວ",            "disease",  "DB",  False),
    ("软腐病",   "ພະຍາດເນົ່າ",                 "disease",  "DB",  False),
    ("青枯病",   "ພະຍາດຫ່ຽວ",                  "disease",  "DB",  False),
    ("细菌性",   "ເຊື້ອແບັກທີເຣຍ",              "pathogen", "STD", False),
    ("病毒病",   "ພະຍາດຫຼອດໄສ້",               "disease",  "DB",  False),
    ("根结线虫病", "ພະຍາດໄສ້ກົ້ນຮາກ",           "disease",  "NEW", True),
    ("根结线虫", "ໄສ້ກົ້ນຮາກ",                 "pathogen", "NEW", True),
    ("黄萎病",   "ພະຍາດລຳຕົ້ນເນົ່າ",           "disease",  "DB",  False),
    # ---- 害虫 ----
    ("菜粉蝶",     "ຜີເສື້ອຂາວຜັກ",       "pest", "NEW", True),
    ("小菜蛾",     "ແມງກະຕູ້ຜັກ",         "pest", "NEW", True),
    ("黄曲条跳甲", "ແມງໝັດຕົ້ນຜັກ",       "pest", "NEW", True),
    ("温室白粉虱", "ແມງຫວີຂາວ",           "pest", "DB",  False),
    ("白粉虱",     "ແມງຫວີຂາວ",           "pest", "DB",  False),
    ("侧多食跗线螨", "ໄຮເມດ",             "pest", "NEW", True),
    ("螨",         "ໄຮເມດ",               "pest", "NEW", True),
    ("蚜虫",       "ເພີ້ຍ",                "pest", "DB",  False),
    # ---- 虫态 / 为害状 ----
    ("为害状", "ອາການທຳລາຍ", "symptom", "NEW", True),
    ("幼虫",   "ຕົວອ່ອນ",       "stage",   "STD", False),
    ("成虫",   "ຕົວເຕັມໄວ",    "stage",   "STD", False),
    ("虫卵",   "ໄຂ່",          "stage",   "STD", False),
    ("蛹",     "ດັກແດ້",       "stage",   "STD", False),
    # ---- 症状描述词 ----
    ("症状",       "ອາການ",           "symptom", "STD", False),
    ("叶片",       "ໃບ",              "symptom", "STD", False),
    ("叶子",       "ໃບ",              "symptom", "STD", False),
    ("幼苗",       "ຕົ້ນກ້າ",          "symptom", "STD", False),
    ("植株",       "ຕົ້ນ",            "symptom", "STD", False),
    ("根部",       "ຮາກ",             "symptom", "STD", False),
    ("茎秆",       "ລຳຕົ້ນ",           "symptom", "STD", False),
    ("维管束系统", "ລະບົບທໍ່ລຳລຽງ",     "symptom", "NEW", True),
    ("菌脓",       "ນ້ຳລົງຈາກເຊື້ອ",   "symptom", "NEW", True),
    ("变暗",       "ປ່ຽນເປັນສີເຂັ້ມ",   "symptom", "STD", False),
    ("严重",       "ຮຸນແຮງ",           "symptom", "STD", False),
    ("大面积",     "ພື້ນທີ່ກວ້າງ",      "symptom", "STD", False),
    ("感染",       "ຕິດເຊື້ອ",          "symptom", "STD", False),
    ("健康",       "ສຸຂະພາບດີ",         "symptom", "STD", False),
    ("渗出",       "ຮົ່ວອອກ",           "symptom", "NEW", True),
    ("雌成虫",     "ຕົວເຕັມໄວໂຕແມ່",   "stage",   "NEW", True),
    # ---- 分类名用词 ----
    ("蔬菜", "ພືດຜັກ",   "category", "STD", False),
    ("瓜类", "ໝາກແຕງ",  "category", "DB",  False),
    ("茄科", "ພືດຕະກຸນໝາກເລັ່ນ", "category", "NEW", True),
]

# ==========================================================================
# 二、分类与逐图译名
# ==========================================================================
# (code, 中文分类名, 老挝语分类名, task, task_type, 中文文件夹名, [(asset_id, 中文文件名, 老挝语文件名)])
CATEGORIES = [
    (
        "T1-01", "蔬菜猝倒、立枯病", "ພະຍາດໂຄນເນົ່າ ແລະ ໂຄນແຫ້ງຂອງພືດຜັກ", 1, "disease",
        "任务1（1蔬菜猝倒、立枯病）",
        [
            ("6PS-V-D0101", "1辣椒-腐霉菌属引起的猝倒病.jpg", "01_ພະຍາດໂຄນເນົ່າໝາກເຜັດ ເກີດຈາກເຊື້ອຣາ Pythium.jpg"),
            ("6PS-V-D0102", "2西兰花幼苗立枯病.jpg",          "02_ພະຍາດໂຄນແຫ້ງຂອງຕົ້ນກ້າຜັກບຣັອກໂຄລີ.jpg"),
        ],
    ),
    (
        "T1-02", "蔬菜霜霉病", "ພະຍາດຂີ້ຝຸ່ນຂອງພືດຜັກ", 1, "disease",
        "任务1（2蔬菜霜霉病）",
        [
            ("6PS-V-D0201", "1大白菜叶子霜霉病症状.jpg", "01_ອາການພະຍາດຂີ້ຝຸ່ນໃບຜັກກາດຂາວ.jpg"),
            ("6PS-V-D0202", "2卷心菜叶子霜霉病症状.jpg", "02_ອາການພະຍາດຂີ້ຝຸ່ນໃບຜັກກາດຫົວ.jpg"),
            ("6PS-V-D0203", "3卷心菜叶子霜霉病症状.jpg", "03_ອາການພະຍາດຂີ້ຝຸ່ນໃບຜັກກາດຫົວ.jpg"),
        ],
    ),
    (
        "T1-03", "瓜类白粉病", "ພະຍາດຂີ້ຝຸ່ນຂາວຂອງພືດຕະກຸນໝາກແຕງ", 1, "disease",
        "任务1（3瓜类白粉病）",
        [
            ("6PS-V-D0301", "1南瓜白粉病症状.jpg", "01_ອາການພະຍາດຂີ້ຝຸ່ນຂາວໝາກອຶ.jpg"),
            ("6PS-V-D0302", "2南瓜白粉病症状.jpg", "02_ອາການພະຍາດຂີ້ຝຸ່ນຂາວໝາກອຶ.jpg"),
        ],
    ),
    (
        "T1-04", "白菜软腐病", "ພະຍາດເນົ່າຂອງຜັກກາດຂາວ", 1, "disease",
        "任务1（4白菜软腐病）",
        [
            ("6PS-V-D0401", "1白菜软腐病症状.JPG", "01_ອາການພະຍາດເນົ່າຜັກກາດຂາວ.JPG"),
            ("6PS-V-D0402", "2白菜软腐病症状.JPG", "02_ອາການພະຍາດເນົ່າຜັກກາດຂາວ.JPG"),
            ("6PS-V-D0403", "3芥菜软腐病症状.JPG", "03_ອາການພະຍາດເນົ່າຜັກກາດເຂົ້າ.JPG"),
        ],
    ),
    (
        "T1-05", "茄科蔬菜青枯病", "ພະຍາດຫ່ຽວຂອງພືດຕະກຸນໝາກເລັ່ນ", 1, "disease",
        "任务1（5茄科蔬菜青枯病）",
        [
            ("6PS-V-D0501", "1番茄细菌性青枯病的严重症状.jpg",       "01_ອາການຮຸນແຮງຂອງພະຍາດຫ່ຽວເຊື້ອແບັກທີເຣຍໃນໝາກເລັ່ນ.jpg"),
            ("6PS-V-D0502", "2番茄细菌性青枯病症状.jpg",            "02_ອາການພະຍາດຫ່ຽວເຊື້ອແບັກທີເຣຍໃນໝາກເລັ່ນ.jpg"),
            ("6PS-V-D0503", "3大面积严重感染青枯病的番茄植株.jpg",    "03_ຕົ້ນໝາກເລັ່ນຕິດເຊື້ອພະຍາດຫ່ຽວຢ່າງຮຸນແຮງໃນພື້ນທີ່ກວ້າງ.jpg"),
            ("6PS-V-D0504", "4青枯病感染后番茄维管束系统变暗.jpg",    "04_ລະບົບທໍ່ລຳລຽງຂອງໝາກເລັ່ນປ່ຽນເປັນສີເຂັ້ມຫຼັງຕິດເຊື້ອພະຍາດຫ່ຽວ.jpg"),
            ("6PS-V-D0505", "5青枯病感染后的番茄茎秆渗出的菌脓.jpg",  "05_ນ້ຳລົງຈາກເຊື້ອທີ່ຮົ່ວອອກຈາກລຳຕົ້ນໝາກເລັ່ນຫຼັງຕິດເຊື້ອພະຍາດຫ່ຽວ.jpg"),
        ],
    ),
    (
        "T1-06", "蔬菜病毒病", "ພະຍາດຫຼອດໄສ້ຂອງພືດຜັກ", 1, "disease",
        "任务1（6蔬菜病毒病）",
        [
            ("6PS-V-D0601", "1番茄病毒病症状.jpg", "01_ອາການພະຍາດຫຼອດໄສ້ໝາກເລັ່ນ.jpg"),
            ("6PS-V-D0602", "2番茄病毒病症状.jpg", "02_ອາການພະຍາດຫຼອດໄສ້ໝາກເລັ່ນ.jpg"),
            ("6PS-V-D0603", "3萝卜病毒病症状.jpg", "03_ອາການພະຍາດຫຼອດໄສ້ຫົວຜັກກາດ.jpg"),
            ("6PS-V-D0604", "4萝卜病毒病症状.jpg", "04_ອາການພະຍາດຫຼອດໄສ້ຫົວຜັກກາດ.jpg"),
            ("6PS-V-D0605", "5南瓜病毒病症状.JPG", "05_ອາການພະຍາດຫຼອດໄສ້ໝາກອຶ.JPG"),
            ("6PS-V-D0606", "6南瓜病毒病症状.JPG", "06_ອາການພະຍາດຫຼອດໄສ້ໝາກອຶ.JPG"),
        ],
    ),
    (
        "T1-07", "蔬菜根结线虫病", "ພະຍາດໄສ້ກົ້ນຮາກຂອງພືດຜັກ", 1, "disease",
        "任务1（7蔬菜根结线虫病）",
        [
            ("6PS-V-D0701", "1番茄根结线虫病症状.jpg",                        "01_ອາການພະຍາດໄສ້ກົ້ນຮາກໝາກເລັ່ນ.jpg"),
            ("6PS-V-D0702", "2健康的番茄植株（左）与被根结线虫侵染的植株（右）.jpg", "02_ຕົ້ນໝາກເລັ່ນສຸຂະພາບດີ (ຊ້າຍ) ແລະ ຕົ້ນທີ່ຕິດເຊື້ອໄສ້ກົ້ນຮາກ (ຂວາ).jpg"),
            ("6PS-V-D0703", "3番茄根部的根结.jpg",                            "03_ປຸມຢູ່ຮາກໝາກເລັ່ນ.jpg"),
            ("6PS-V-D0704", "4根结线虫雌成虫.jpg",                            "04_ຕົວເຕັມໄວໂຕແມ່ຂອງໄສ້ກົ້ນຮາກ.jpg"),
        ],
    ),
    (
        "T2-01", "菜粉蝶", "ພະຍາດຜີເສື້ອຂາວຜັກ (ຂອງພືດຜັກ)", 2, "pest",
        "任务2（1菜粉蝶）",
        [
            ("6PS-V-P0101", "1菜粉蝶为害状.JPG", "01_ອາການທຳລາຍຂອງຜີເສື້ອຂາວຜັກ.JPG"),
            ("6PS-V-P0102", "2菜粉蝶为害状.JPG", "02_ອາການທຳລາຍຂອງຜີເສື້ອຂາວຜັກ.JPG"),
            ("6PS-V-P0103", "3菜粉蝶卵.JPG",     "03_ໄຂ່ຜີເສື້ອຂາວຜັກ.JPG"),
            ("6PS-V-P0104", "4菜粉蝶幼虫.JPG",   "04_ຕົວອ່ອນຜີເສື້ອຂາວຜັກ.JPG"),
            ("6PS-V-P0105", "5菜粉蝶蛹.JPG",     "05_ດັກແດ້ຜີເສື້ອຂາວຜັກ.JPG"),
            ("6PS-V-P0106", "6菜粉蝶成虫.JPG",   "06_ຕົວເຕັມໄວຜີເສື້ອຂາວຜັກ.JPG"),
        ],
    ),
    (
        "T2-02", "小菜蛾", "ພະຍາດແມງກະຕູ້ຜັກ (ຂອງພືດຜັກ)", 2, "pest",
        "任务2（2小菜蛾）",
        [
            ("6PS-V-P0201", "1小菜蛾为害状.jpg", "01_ອາການທຳລາຍຂອງແມງກະຕູ້ຜັກ.jpg"),
            ("6PS-V-P0202", "2小菜蛾幼虫.jpg",   "02_ຕົວອ່ອນແມງກະຕູ້ຜັກ.jpg"),
            ("6PS-V-P0203", "3小菜蛾蛹.jpg",     "03_ດັກແດ້ແມງກະຕູ້ຜັກ.jpg"),
            ("6PS-V-P0204", "4小菜蛾成虫.jpg",   "04_ຕົວເຕັມໄວແມງກະຕູ້ຜັກ.jpg"),
        ],
    ),
    (
        "T2-03", "黄曲条跳甲", "ພະຍາດແມງໝັດຕົ້ນຜັກ (ຂອງພືດຜັກ)", 2, "pest",
        "任务2（3黄曲条跳甲）",
        [
            ("6PS-V-P0301", "1黄曲条跳甲成虫为害状.JPG", "01_ອາການທຳລາຍຂອງຕົວເຕັມໄວແມງໝັດຕົ້ນຜັກ.JPG"),
            ("6PS-V-P0302", "2黄曲条跳甲成虫为害状.JPG", "02_ອາການທຳລາຍຂອງຕົວເຕັມໄວແມງໝັດຕົ້ນຜັກ.JPG"),
            ("6PS-V-P0303", "3黄曲条跳甲成虫为害状.jpg", "03_ອາການທຳລາຍຂອງຕົວເຕັມໄວແມງໝັດຕົ້ນຜັກ.jpg"),
            ("6PS-V-P0304", "4黄曲条跳甲成虫为害状.JPG", "04_ອາການທຳລາຍຂອງຕົວເຕັມໄວແມງໝັດຕົ້ນຜັກ.JPG"),
            ("6PS-V-P0305", "5黄曲条跳甲成虫为害状.jpg", "05_ອາການທຳລາຍຂອງຕົວເຕັມໄວແມງໝັດຕົ້ນຜັກ.jpg"),
            ("6PS-V-P0306", "6黄曲条跳甲幼虫为害状（引自王助引、于永浩，2016）.jpg", "06_ອາການທຳລາຍຂອງຕົວອ່ອນແມງໝັດຕົ້ນຜັກ (ອ້າງອີງ ຫວາງຈູອິນ, ອີຢົງຮ້າວ 2016).jpg"),
            ("6PS-V-P0307", "7黄曲条跳甲成虫（引自王助引、于永浩，2016）.jpg",     "07_ຕົວເຕັມໄວແມງໝັດຕົ້ນຜັກ (ອ້າງອີງ ຫວາງຈູອິນ, ອີຢົງຮ້າວ 2016).jpg"),
            ("6PS-V-P0308", "8黄曲条跳甲幼虫（引自王助引、于永浩，2016）.jpg",     "08_ຕົວອ່ອນແມງໝັດຕົ້ນຜັກ (ອ້າງອີງ ຫວາງຈູອິນ, ອີຢົງຮ້າວ 2016).jpg"),
        ],
    ),
    (
        "T2-04", "温室白粉虱", "ພະຍາດແມງຫວີຂາວ (ຂອງພືດຜັກ)", 2, "pest",
        "任务2（4温室白粉虱）",
        [
            ("6PS-V-P0401", "1温室白粉虱为害黄瓜.jpg", "01_ແມງຫວີຂາວທຳລາຍໝາກແຕງ.jpg"),
            ("6PS-V-P0402", "2温室白粉虱为害状（引自王助引、于永浩，2016）.jpg",     "02_ອາການທຳລາຍຂອງແມງຫວີຂາວ (ອ້າງອີງ ຫວາງຈູອິນ, ອີຢົງຮ້າວ 2016).jpg"),
            ("6PS-V-P0403", "3温室白粉虱成虫和卵（引自王助引、于永浩，2016）.jpg", "03_ຕົວເຕັມໄວ ແລະ ໄຂ່ຂອງແມງຫວີຂາວ (ອ້າງອີງ ຫວາງຈູອິນ, ອີຢົງຮ້າວ 2016).jpg"),
        ],
    ),
    (
        "T2-05", "侧多食跗线螨", "ພະຍາດໄຮເມດ (ຂອງພືດຜັກ)", 2, "pest",
        "任务2（5侧多食跗线螨）",
        [
            ("6PS-V-P0501", "1螨为害状.jpg", "01_ອາການທຳລາຍຂອງໄຮເມດ.jpg"),
            ("6PS-V-P0502", "2螨为害状.jpg", "02_ອາການທຳລາຍຂອງໄຮເມດ.jpg"),
            ("6PS-V-P0503", "3螨成虫.jpg",   "03_ຕົວເຕັມໄວຂອງໄຮເມດ.jpg"),
        ],
    ),
]


# ==========================================================================
# 三、生成逻辑
# ==========================================================================
def link_or_copy(src: Path, dst: Path) -> str:
    """优先硬链接（同盘不占空间），失败则复制。"""
    if dst.exists():
        return "exists"
    try:
        os.link(src, dst)
        return "link"
    except OSError:
        shutil.copy2(src, dst)
        return "copy"


def csv_write(path: Path, header, rows):
    with open(path, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只校验，不写文件")
    args = ap.parse_args()

    # ---- 0. 载入中文清单，做一致性校验 ----
    manifest_zh = json.loads(MANIFEST_ZH.read_text(encoding="utf-8"))
    zh_by_id = {r["asset_id"]: r for r in manifest_zh["records"]}

    problems, planned = [], []
    seen_ids = set()
    for code, cat_zh, cat_lo, task, ttype, folder_zh, items in CATEGORIES:
        src_dir = SRC_ROOT / folder_zh
        if not src_dir.is_dir():
            problems.append(f"中文语料目录不存在: {folder_zh}")
            continue
        for asset_id, name_zh, name_lo in items:
            if asset_id in seen_ids:
                problems.append(f"asset_id 重复: {asset_id}")
            seen_ids.add(asset_id)
            if asset_id not in zh_by_id:
                problems.append(f"asset_id 不在中文清单中: {asset_id}")
            src = src_dir / name_zh
            if not src.is_file():
                problems.append(f"源文件缺失: {folder_zh}\\{name_zh}")
            if not any(LAO_RANGE[0] <= ord(c) <= LAO_RANGE[1] for c in name_lo):
                problems.append(f"老挝语文件名不含老挝文字符: {asset_id} -> {name_lo}")
            if name_lo.lower().endswith((".jpg", ".jpeg")) and src.is_file():
                if src.suffix.lower() != Path(name_lo).suffix.lower():
                    problems.append(f"扩展名不一致: {asset_id} 源={src.suffix} 目标={Path(name_lo).suffix}")
            planned.append({
                "asset_id": asset_id,
                "category_code": code,
                "category_zh": cat_zh,
                "category_lo": cat_lo,
                "task": task,
                "task_type": ttype,
                "folder_zh": folder_zh,
                "file_zh": name_zh,
                "folder_lo": f"{code}_{cat_lo}",
                "file_lo": name_lo,
                "src_path": str(Path("raw_materials") / "6ps" / folder_zh / name_zh).replace("\\", "/"),
                "dst_path": str(Path("raw_materials") / "6ps_lo" / f"{code}_{cat_lo}" / name_lo).replace("\\", "/"),
                "citation": zh_by_id.get(asset_id, {}).get("citation"),
                "label_status": zh_by_id.get(asset_id, {}).get("label_status"),
                "proposed_role": zh_by_id.get(asset_id, {}).get("proposed_role"),
            })

    # 中文清单里是否有多余条目（本次未覆盖）
    missing = sorted(set(zh_by_id) - seen_ids)
    if missing:
        problems.append(f"中文清单中有 {len(missing)} 条未纳入本包: {', '.join(missing[:10])}")

    print(f"计划处理: {len(planned)} 张图 / {len(CATEGORIES)} 个分类")
    print(f"校验问题: {len(problems)}")
    for p in problems:
        print("  [x] " + p)
    if args.check:
        return 1 if problems else 0
    if problems:
        print("存在校验问题，已中止（不落盘）")
        return 1

    # ---- 1. 落盘：目录 + 照片 ----
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    stats = {"link": 0, "copy": 0, "exists": 0}
    for row in planned:
        (OUT_ROOT / row["folder_lo"]).mkdir(parents=True, exist_ok=True)
        src = REPO_ROOT / row["src_path"]
        dst = OUT_ROOT / row["folder_lo"] / row["file_lo"]
        stats[link_or_copy(src, dst)] += 1
        if dst.stat().st_size != src.stat().st_size:
            problems.append(f"落盘后大小不一致: {row['asset_id']}")

    # ---- 2. 索引（一页看完 49 条） ----
    csv_write(
        OUT_ROOT / "_index_lo.csv",
        ["序号", "分类编号", "分类_中文", "分类_老挝语", "源文件名_中文", "文件名_老挝语", "asset_id", "任务", "类型", "来源引用"],
        [[i + 1, r["category_code"], r["category_zh"], r["category_lo"], r["file_zh"], r["file_lo"],
          r["asset_id"], r["task"], r["task_type"], r["citation"] or ""] for i, r in enumerate(planned)],
    )

    # ---- 3. 审校工作单（老师填写） ----
    csv_write(
        OUT_ROOT / "_review_sheet.csv",
        ["序号", "老挝语文件名", "中文原名", "备注", "老师意见(确认/改译)", "老师修改后的老挝语", "老师补充说明"],
        [[i + 1, r["file_lo"], r["file_zh"], "", "", "", ""] for i, r in enumerate(planned)],
    )

    # ---- 4. 术语词表 ----
    csv_write(
        OUT_ROOT / "_glossary_lo.csv",
        ["序号", "中文术语", "老挝语译名", "类别", "来源", "是否需重点确认"],
        [[i + 1, zh, lo, kind, src, "是" if review else "否"] for i, (zh, lo, kind, src, review) in enumerate(TERMS)],
    )

    # ---- 5. 机读映射 ----
    payload = {
        "_spec": "6ps 语料老挝语版映射 — 由 raw_materials/6ps_lo/_build/build_lo_corpus.py 生成",
        "_generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "_source_zh_root": "raw_materials/6ps",
        "_status": "PENDING_EXPERT_REVIEW — 全部译名待老挝语专家审核，未审核前不得进入数据库或用户端",
        "summary": {
            "images": len(planned),
            "categories": len(CATEGORIES),
            "disease_categories": sum(1 for c in CATEGORIES if c[4] == "disease"),
            "pest_categories": sum(1 for c in CATEGORIES if c[4] == "pest"),
            "expert_review_required_terms": sum(1 for t in TERMS if t[4]),
        },
        "records": planned,
    }
    (OUT_ROOT / "_manifest_lo.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"落盘完成: 硬链接 {stats['link']} / 复制 {stats['copy']} / 已存在 {stats['exists']}")
    print(f"输出目录: {OUT_ROOT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
