#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 6ps_lo 老挝语语料包打成 zip（送审用）。

做两件事：
  1. 生成两个 zip：
       6ps_lo_老挝语语料包_v1_YYYYMMDD.zip        发给老师（不含 _build 脚本）
       6ps_lo_老挝语语料包_v1_YYYYMMDD_含脚本.zip  内部留档（含 _build）
  2. 文件名编码处理 —— 老挝文文件名在邮件/网盘/解压时最易乱码，因此：
       * zip 内条目统一使用 UTF-8 并置 EFS 标志位（Python zipfile 默认行为）
       * 每个分类目录额外写入一份 list.txt 与 list_utf8.txt，
         文件名乱码时老师仍可按序号对应照片

用法:
    python raw_materials/6ps_lo/_build/make_zip.py            # 生成
    python raw_materials/6ps_lo/_build/make_zip.py --verify   # 生成后回读校验
"""
from __future__ import annotations

import argparse
import json
import sys
import zipfile
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PKG_ROOT = REPO_ROOT / "raw_materials" / "6ps_lo"
OUT_DIR = REPO_ROOT / "raw_materials"
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png"}


def build_list_files() -> tuple[int, int]:
    """在每个人工分类目录写一份清单，防止文件名乱码时无法对应。

    返回 (分类目录数, 图片数)。注意：只统计图片，
    list.txt / list_utf8.txt 是本函数自己写的，不计入。
    """
    folders = 0
    images = 0
    for folder in sorted(p for p in PKG_ROOT.iterdir() if p.is_dir() and not p.name.startswith("_")):
        files = sorted((f for f in folder.iterdir() if f.is_file()), key=lambda p: p.name)
        photos = [f for f in files if f.suffix.lower() in IMAGE_SUFFIXES]
        lines = [f"{folder.name}", "=" * 60, ""]
        for i, f in enumerate(photos, 1):
            lines.append(f"{i:02d}. {f.name}")
        lines += ["", f"共 {len(photos)} 张图片"]
        text = "\n".join(lines) + "\n"
        # 同一份内容写两个编码：无 BOM（UTF-8）与带 BOM（老挝文记事本友好）
        (folder / "list_utf8.txt").write_text(text, encoding="utf-8")
        (folder / "list.txt").write_text(text, encoding="utf-8-sig")
        folders += 1
        images += len(photos)
    return folders, images


def make_zip(zip_path: Path, include_build: bool) -> tuple[int, int]:
    entries = 0
    raw = 0
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for path in sorted(PKG_ROOT.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(PKG_ROOT)
            if "_build" in rel.parts and not include_build:
                continue
            arcname = str(Path("6ps_lo") / rel).replace("\\", "/")
            zf.write(path, arcname)
            entries += 1
            raw += path.stat().st_size
    return entries, raw


def verify(zip_path: Path) -> bool:
    ok = True
    with zipfile.ZipFile(zip_path) as zf:
        infos = zf.infolist()
        images = [i for i in infos if Path(i.filename).suffix.lower() in IMAGE_SUFFIXES]
        images = [i for i in images if "_build" not in i.filename]
        lao_named = [i for i in images if any(0x0E80 <= ord(c) <= 0x0EFF for c in i.filename)]
        broken = zf.testzip()
        print(f"  回读: 条目 {len(infos)} | 图片 {len(images)} | 文件名含老挝文 {len(lao_named)}")
        print(f"  完整性: {'损坏条目 ' + broken if broken else '全部 CRC 校验通过'}")
        if broken:
            ok = False
        if len(images) != 49:
            print(f"  [x] 图片数不是 49，而是 {len(images)}")
            ok = False
        if len(lao_named) != 49:
            print(f"  [x] 老挝文文件名不是 49，而是 {len(lao_named)}")
            ok = False
        # 抽查一条：确认老挝文能正确解码（对比 manifest）
        manifest = json.loads((PKG_ROOT / "_manifest_lo.json").read_text(encoding="utf-8"))
        sample = manifest["records"][0]
        want = "6ps_lo/" + sample["dst_path"].split("6ps_lo/", 1)[1]
        names = {i.filename for i in infos}
        if want not in names:
            print(f"  [x] 抽查条目缺失: {want}")
            ok = False
        else:
            print(f"  抽查条目 OK: {want}")
        if not any(i.filename.endswith("README.md") for i in infos):
            print("  [x] 缺少 README.md")
            ok = False
    return ok


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verify", action="store_true", help="生成后回读校验")
    args = ap.parse_args()

    if not PKG_ROOT.is_dir():
        print(f"语料包目录不存在: {PKG_ROOT}")
        return 1

    total_folders, total_images = build_list_files()
    print(f"已写入分类清单: {total_folders} 个目录 / {total_images} 张图片（各生成 list.txt + list_utf8.txt）")

    stamp = datetime.now().strftime("%Y%m%d")
    plain = OUT_DIR / f"6ps_lo_老挝语语料包_v1_{stamp}.zip"
    withbuild = OUT_DIR / f"6ps_lo_老挝语语料包_v1_{stamp}_含脚本.zip"

    results = []
    for path, include in ((plain, False), (withbuild, True)):
        entries, raw = make_zip(path, include)
        size = path.stat().st_size
        ratio = size / raw * 100 if raw else 0
        print(f"\n[OK] {path.name}")
        print(f"  条目 {entries} | 原始 {raw/1024/1024:.1f} MB → 压缩 {size/1024/1024:.1f} MB ({ratio:.0f}%)")
        if args.verify:
            if not verify(path):
                results.append(path)
    if results:
        print("\n校验未通过: " + ", ".join(p.name for p in results))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
