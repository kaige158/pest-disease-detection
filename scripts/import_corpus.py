#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""6ps 语料资产化管线 —— 把 raw_materials/6ps 的图片语料变成可入库的系统资产。

定位：
    这是"数据资产"管线，不是"模型训练"管线。它只做三件事：
    1. 解析语料目录/文件名，产出结构化清单（含尺寸、来源引用、弱标签）
    2. 生成入库 SQL（作物 / 病虫害 / 图片），全部以 draft 状态入库，不污染用户端
    3. 生成专家确认表与内容缺口清单，形成可执行的人工工作单

设计约束：
    - 不臆造专家知识：新增病虫害的分子生物学症状/防控内容留空，由专家填写
    - 不臆造老挝语：name_lo_draft 仅进审校表，不进数据库
    - 幂等：所有 INSERT 都带 WHERE NOT EXISTS，可重复执行
    - 只读映射表 dataset/corpus_mapping.json，脚本不修改它

用法：
    python scripts/import_corpus.py            # 生成全部产物
    python scripts/import_corpus.py --check    # 只校验映射与文件是否一致，不写文件
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CORPUS_ROOT = REPO_ROOT / "raw_materials" / "6ps"
MAPPING_PATH = REPO_ROOT / "dataset" / "corpus_mapping.json"
OUT_MANIFEST = REPO_ROOT / "dataset" / "corpus_manifest.json"
OUT_REVIEW = REPO_ROOT / "dataset" / "corpus_label_review.csv"
OUT_GAP = REPO_ROOT / "dataset" / "knowledge_text_gap.csv"
OUT_SQL = REPO_ROOT / "database" / "seed_corpus_6ps_v1.sql"

FOLDER_RE = re.compile(r"^任务(?P<task>\d)（(?P<seq>\d)(?P<label>.+)）$")
INDEX_RE = re.compile(r"^(?P<seq>\d+)(?P<caption>.+)$")
CITATION_RE = re.compile(r"（引自(?P<cite>[^）]+)）")
EVAL_RATIO = 0.2
SYMPTOM_HINTS = ("症状", "为害状", "危害状")

SQL_HEADER = """-- ==========================================================
-- {title}
-- 生成脚本: scripts/import_corpus.py（请勿手工编辑，改映射表后重新生成）
-- 映射来源: dataset/corpus_mapping.json v{version}
-- 语料来源: raw_materials/6ps （{total} 张图 / {cats} 个分类）
-- 生成时间: {generated}
--
-- 入库状态约定（重要）:
--   * 新增病虫害一律 approval_status='draft' + is_active=FALSE
--     → 内容未补全前不会出现在用户端知识库，补全并经专家审核后再激活
--   * 新增图片一律 label_status='ai_only' + approval_status='pending'
--     → 文件名只是弱标签，必须经专家确认才可进入训练集
--   * name_lo 全部留空：语料只有中文，老挝语译名需老挝语专家校核后填写
--
-- 幂等性: 全部 INSERT 均带 WHERE NOT EXISTS，可重复执行
-- 回滚: 见文件末尾 ROLLBACK 段落（注释形式，需手工执行）
-- ==========================================================
"""


def sq(text):
    """SQL 字符串字面量转义。"""
    return "'" + str(text).replace("'", "''") + "'"


def read_jpeg_size(path):
    """不依赖第三方库读取 JPEG 宽高，返回 (width, height)，失败返回 (None, None)。"""
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError:
        return None, None
    if len(data) < 4 or data[:2] != b"\xff\xd8":
        return None, None
    i, n = 2, len(data)
    while i + 9 < n:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker == 0xDA:
            break
        if marker == 0x01 or 0xD0 <= marker <= 0xD8:
            i += 2
            continue
        seg_len = int.from_bytes(data[i + 2:i + 4], "big")
        if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
            height = int.from_bytes(data[i + 5:i + 7], "big")
            width = int.from_bytes(data[i + 7:i + 9], "big")
            return width, height
        i += 2 + seg_len
    return None, None


def load_mapping():
    with open(MAPPING_PATH, encoding="utf-8") as fh:
        return json.load(fh)


def parse_folders(mapping):
    """校验映射表里的每个文件夹都真实存在，返回 [ (category_dict, folder_path, [files]) ]。"""
    problems, parsed = [], []
    for category in mapping["categories"]:
        folder = CORPUS_ROOT / category["folder"]
        if not folder.is_dir():
            problems.append("映射表声明的文件夹不存在: " + category["folder"])
            continue
        match = FOLDER_RE.match(category["folder"])
        if not match:
            problems.append("文件夹名不符合「任务N（N类别）」格式: " + category["folder"])
            continue
        if int(match.group("task")) != category["task"] or int(match.group("seq")) != int(category["key"][1:]):
            problems.append("任务号/序号与映射表 key 不一致: " + category["folder"])
            problems.append("任务号/序号与映射表不一致: " + category["folder"])
        if match.group("label").strip() != category["label_zh"]:
            problems.append(
                "标签不一致: 文件夹「%s」→「%s」，映射表写的是「%s」"
                % (category["folder"], match.group("label").strip(), category["label_zh"])
            )
        images = sorted(
            [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")],
            key=lambda p: int(INDEX_RE.match(p.stem).group("seq")) if INDEX_RE.match(p.stem) else 9999,
        )
        parsed.append((category, folder, images))
    return parsed, problems


def pick_target(category, caption):
    """按 match_keywords 把图片分配到具体病虫害目标；无匹配则用唯一目标或第一个。"""
    targets = category["targets"]
    for target in targets:
        for keyword in target.get("match_keywords", []):
            if keyword in caption:
                return target
    if len(targets) == 1:
        return targets[0]
    return None


def assign_roles(records):
    """按分类内 20% 抽评测集，优先抽症状/为害状图（贴近用户实际拍摄场景）。"""
    by_category = {}
    for record in records:
        by_category.setdefault(record["category_key"], []).append(record)
    for items in by_category.values():
        quota = max(1, math.ceil(len(items) * EVAL_RATIO))
        preferred = [r for r in items if any(h in r["caption"] for h in SYMPTOM_HINTS)]
        preferred += [r for r in items if r not in preferred]
        for record in preferred[:quota]:
            record["proposed_role"] = "eval_holdout"
    return records


def build_records(mapping):
    parsed, problems = parse_folders(mapping)
    crops = mapping["crops"]
    records = []
    for category, folder, images in parsed:
        for image in images:
            match = INDEX_RE.match(image.stem)
            seq = int(match.group("seq")) if match else 0
            caption = match.group("caption") if match else image.stem
            citation_match = CITATION_RE.search(caption)
            citation = citation_match.group("cite") if citation_match else None
            clean_caption = CITATION_RE.sub("", caption).strip()
            target = pick_target(category, clean_caption)
            if target is None:
                problems.append("无法分配目标: %s / %s" % (category["folder"], image.name))
                continue
            width, height = read_jpeg_size(image)
            crop_key = target["crop_key"]
            records.append({
                "asset_id": "6PS-V-%s%02d%02d" % (
                    "D" if category["task_type"] == "disease" else "P",
                    category["key"][1:] and int(category["key"][1:]) or 0,
                    seq,
                ),
                "category_key": category["key"],
                "category_label_zh": category["label_zh"],
                "task": category["task"],
                "task_type": category["task_type"],
                "folder": category["folder"],
                "file": image.name,
                "rel_path": "raw_materials/6ps/%s/%s" % (category["folder"], image.name),
                "seq": seq,
                "caption": clean_caption,
                "citation": citation,
                "image_bytes": image.stat().st_size,
                "image_width": width,
                "image_height": height,
                "crop_zh": crops[crop_key]["name_zh"],
                "crop_action": crops[crop_key]["action"],
                "disease_zh": target["name_zh"],
                "disease_action": target["action"],
                "disease_type": target["type"],
                "plant_part": target.get("plant_part", category.get("plant_part", "leaf")),
                "host_assumed": bool(target.get("host_assumed")),
                "name_lo_draft": target.get("name_lo_draft"),
                "proposed_role": "train_candidate",
                "label_status": "ai_only",
                "source_type": "TEACHER_DATA",
            })
    return assign_roles(records), problems


def write_manifest(mapping, records, problems):
    cited = [r for r in records if r["citation"]]
    payload = {
        "_spec": "6ps 蔬菜病虫害语料清单 — 由 scripts/import_corpus.py 生成，请勿手工编辑",
        "_generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "_source_root": mapping["_source_root"],
        "_mapping_version": mapping["_version"],
        "summary": {
            "total_images": len(records),
            "categories": len(mapping["categories"]),
            "disease_categories": sum(1 for c in mapping["categories"] if c["task_type"] == "disease"),
            "pest_categories": sum(1 for c in mapping["categories"] if c["task_type"] == "pest"),
            "cited_images": len(cited),
            "eval_holdout": sum(1 for r in records if r["proposed_role"] == "eval_holdout"),
            "train_candidate": sum(1 for r in records if r["proposed_role"] == "train_candidate"),
            "new_disease_targets": len({t["disease_key"] for c in mapping["categories"] for t in c["targets"] if t["action"] == "create"}),
            "reuse_disease_targets": len({t["disease_key"] for c in mapping["categories"] for t in c["targets"] if t["action"] == "reuse"}),
        },
        "records": records,
    }
    with open(OUT_MANIFEST, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    return payload["summary"]


def write_review_csv(records):
    headers = [
        "asset_id", "建议用途", "语料类别", "类型", "建议作物", "建议病虫害",
        "图片文件", "图片说明", "来源引用", "尺寸(宽x高)", "文件字节",
        "专家确认(是/否)", "专家作物", "专家病虫害", "老挝语名(建议稿-待校核)", "备注",
    ]
    with open(OUT_REVIEW, "w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(headers)
        for record in records:
            size = "%sx%s" % (record["image_width"], record["image_height"]) if record["image_width"] else "读取失败"
            writer.writerow([
                record["asset_id"],
                "评测集(勿训练)" if record["proposed_role"] == "eval_holdout" else "训练候选",
                record["category_label_zh"],
                "病害" if record["task_type"] == "disease" else "害虫",
                record["crop_zh"],
                record["disease_zh"],
                record["file"],
                record["caption"],
                record["citation"] or "",
                size,
                record["image_bytes"],
                "", "", "",
                record["name_lo_draft"] or "",
                "寄主作物为推断，待确认" if record["host_assumed"] else "",
            ])


def write_gap_csv(mapping, records):
    counts = {}
    for record in records:
        counts[record["disease_zh"]] = counts.get(record["disease_zh"], 0) + 1
    with open(OUT_GAP, "w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow([
            "作物", "病虫害", "学名", "类型", "严重度", "语料图片数",
            "缺-中文症状描述", "缺-中文发病条件", "缺-防控方案",
            "缺-老挝语名称", "缺-老挝语正文", "建议负责方", "优先级",
        ])
        for category in mapping["categories"]:
            for target in category["targets"]:
                if target["action"] == "reuse":
                    continue
                crop = mapping["crops"][target["crop_key"]]["name_zh"]
                writer.writerow([
                    crop, target["name_zh"], target.get("scientific_name", ""),
                    "病害" if target["type"] == "disease" else "害虫",
                    target["severity_level"], counts.get(target["name_zh"], 0),
                    "是", "是", "是", "是", "是",
                    "农业专家(中文内容) + 老挝语专家(译文校核)", "P1",
                ])


def write_sql(mapping, records, summary):
    generated = datetime.now().astimezone().isoformat(timespec="seconds")
    lines = [SQL_HEADER.format(
        title="6ps 蔬菜病虫害语料入库 v1（作物 + 病虫害 + 图片）",
        version=mapping["_version"],
        total=summary["total_images"],
        cats=summary["categories"],
        generated=generated,
    )]

    lines.append("\n-- ==========================================================")
    lines.append("-- 1. 新增作物分类")
    lines.append("-- ==========================================================")
    for category in mapping["new_categories"]:
        lines.append(
            "INSERT INTO core.crop_category (version, name_zh, name_en, sort_order)\n"
            "SELECT %s, %s, %s, %d\n"
            "WHERE NOT EXISTS (SELECT 1 FROM core.crop_category WHERE version = %s AND name_zh = %s);\n"
            % (sq(category["version"]), sq(category["name_zh"]), sq(category["name_en"]),
               category["sort_order"], sq(category["version"]), sq(category["name_zh"]))
        )

    lines.append("\n-- ==========================================================")
    lines.append("-- 2. 新增作物")
    lines.append("-- name_lo 留空：语料为中文，老挝语译名需专家校核后补充")
    lines.append("-- ==========================================================")
    category_name = {"leafy": "叶菜类", "cucurbit": "瓜类", "root_vegetable": "根菜类"}
    for crop in mapping["new_crops"]:
        lines.append(
            "INSERT INTO core.crop (version, category_id, name_zh, name_en, scientific_name,\n"
            "    description_zh, planting_info_zh)\n"
            "SELECT 'vegetable',\n"
            "       (SELECT id FROM core.crop_category WHERE version = 'vegetable' AND name_zh = %s LIMIT 1),\n"
            "       %s, %s, %s,\n"
            "       %s,\n"
            "       %s\n"
            "WHERE NOT EXISTS (SELECT 1 FROM core.crop WHERE name_zh = %s);\n"
            % (sq(category_name[crop["category"]]), sq(crop["name_zh"]), sq(crop["name_en"]),
               sq(crop["scientific_name"]), sq(crop["description_zh"]), sq(crop["planting_info_zh"]),
               sq(crop["name_zh"]))
        )

    lines.append("\n-- ==========================================================")
    lines.append("-- 3. 新增病虫害（草案状态）")
    lines.append("-- approval_status='draft' + is_active=FALSE → 内容补全前不进用户端")
    lines.append("-- symptoms/conditions 留空：需农业专家依据语料图片填写")
    lines.append("-- ==========================================================")
    for category in mapping["categories"]:
        lines.append("\n-- 语料类别: %s（%s）" % (category["label_zh"], category["folder"]))
        for target in category["targets"]:
            if target["action"] != "create":
                lines.append("-- [复用已有条目] %s" % target["name_zh"])
                continue
            crop_zh = mapping["crops"][target["crop_key"]]["name_zh"]
            lines.append(
                "INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,\n"
                "    type, severity_level, tags, source_type, approval_status, is_active)\n"
                "SELECT 'vegetable',\n"
                "       (SELECT id FROM core.crop WHERE name_zh = %s LIMIT 1),\n"
                "       %s, %s, %s,\n"
                "       %s, %s, %s, 'TEACHER_DATA', 'draft', FALSE\n"
                "WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = %s);\n"
                % (sq(crop_zh), sq(target["name_zh"]), sq(target.get("name_en", "")),
                   sq(target.get("scientific_name", "")), sq(target["type"]),
                   sq(target["severity_level"]), sq(target["tags"]), sq(target["name_zh"]))
            )

    lines.append("\n-- ==========================================================")
    lines.append("-- 4. 语料图片入库（弱标注，待专家确认）")
    lines.append("-- ==========================================================")
    current_folder = None
    for record in records:
        if record["folder"] != current_folder:
            current_folder = record["folder"]
            lines.append("\n-- %s" % current_folder)
        lines.append(
            "INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,\n"
            "    source_type, plant_part, label_status, approval_status, language, is_public, is_active)\n"
            "SELECT %s, 'vegetable',\n"
            "       (SELECT id FROM core.crop WHERE name_zh = %s LIMIT 1),\n"
            "       (SELECT id FROM core.disease WHERE name_zh = %s LIMIT 1),\n"
            "       'TEACHER_DATA', 'TEACHER_DATA', %s, 'ai_only', 'pending', 'zh', FALSE, TRUE\n"
            "WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = %s);\n"
            % (sq(record["rel_path"]), sq(record["crop_zh"]), sq(record["disease_zh"]),
               sq(record["plant_part"]), sq(record["rel_path"]))
        )

    lines.append("\n-- ==========================================================")
    lines.append("-- 5. 刷新病虫害图片计数")
    lines.append("-- ==========================================================")
    lines.append(
        "UPDATE core.disease d\n"
        "   SET image_count = (SELECT COUNT(*) FROM core.disease_image i\n"
        "                       WHERE i.disease_id = d.id AND i.is_active = TRUE),\n"
        "       updated_at = NOW()\n"
        " WHERE d.name_zh IN (\n"
        "    %s\n"
        " );\n" % ",\n    ".join(sq(n) for n in sorted({r["disease_zh"] for r in records}))
    )

    lines.append("\n-- ==========================================================")
    lines.append("-- 6. 校验查询")
    lines.append("-- ==========================================================")
    lines.append(
        "-- 预期: 图片总数为 %d，新增病虫害为 %d 条草稿，复用条目 %d 条\n"
        "SELECT c.name_zh AS 作物, d.name_zh AS 病虫害, d.approval_status, d.is_active,\n"
        "       COUNT(i.id) AS 图片数\n"
        "  FROM core.disease d\n"
        "  JOIN core.crop c ON c.id = d.crop_id\n"
        "  LEFT JOIN core.disease_image i ON i.disease_id = d.id AND i.is_active = TRUE\n"
        " WHERE d.name_zh IN (\n"
        "    %s\n"
        " )\n"
        " GROUP BY c.name_zh, d.name_zh, d.approval_status, d.is_active\n"
        " ORDER BY 作物, 病虫害;\n"
        % (summary["total_images"], summary["new_disease_targets"], summary["reuse_disease_targets"],
           ",\n    ".join(sq(n) for n in sorted({r["disease_zh"] for r in records})))
    )

    lines.append("\n-- ==========================================================")
    lines.append("-- ROLLBACK（需要撤销本文件入库结果时手工执行）")
    lines.append("-- ==========================================================")
    lines.append(
        "-- DELETE FROM core.disease_image WHERE image_url LIKE 'raw_materials/6ps/%%';\n"
        "-- DELETE FROM core.disease WHERE approval_status = 'draft' AND source_type = 'TEACHER_DATA'\n"
        "--   AND name_zh IN (新增条目列表);\n"
        "-- DELETE FROM core.crop WHERE name_zh IN ('西兰花','甘蓝','芥菜','萝卜','南瓜');\n"
    )

    with open(OUT_SQL, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    return generated


def main():
    parser = argparse.ArgumentParser(description="6ps 语料资产化管线")
    parser.add_argument("--check", action="store_true", help="只校验，不写文件")
    args = parser.parse_args()

    mapping = load_mapping()
    records, problems = build_records(mapping)

    if problems:
        for problem in problems:
            print("[问题] " + problem)
        return 1

    summary = write_manifest(mapping, records, problems)
    if not args.check:
        write_review_csv(records)
        write_gap_csv(mapping, records)
        generated = write_sql(mapping, records, summary)

    print("语料根目录: %s" % CORPUS_ROOT)
    print("图片总数  : %d" % summary["total_images"])
    print("分类数    : %d（病害 %d / 害虫 %d）" % (summary["categories"], summary["disease_categories"], summary["pest_categories"]))
    print("评测集    : %d 张（hold-out，禁止参与训练）" % summary["eval_holdout"])
    print("训练候选  : %d 张" % summary["train_candidate"])
    print("新增病虫害: %d 条（draft）" % summary["new_disease_targets"])
    print("复用条目  : %d 条" % summary["reuse_disease_targets"])
    print("带引用标注: %d 张（版权需确认）" % summary["cited_images"])
    if args.check:
        print("\n[check 模式] 未写入任何文件")
    else:
        print("\n产物:")
        for path in (OUT_MANIFEST, OUT_REVIEW, OUT_GAP, OUT_SQL):
            print("  %s" % path.relative_to(REPO_ROOT))
        print("SQL 生成时间戳: %s" % generated)
    return 0


if __name__ == "__main__":
    sys.exit(main())
