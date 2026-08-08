#!/usr/bin/env python3
"""图片数据导入脚本 — 将老师的语料图片批量导入数据库"""
import os
import sys
import hashlib
import argparse
from pathlib import Path

# 添加项目路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ai-service'))

def sha256_file(filepath):
    """计算文件SHA256"""
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()

def find_images(root_dir, extensions=('.jpg', '.jpeg', '.png', '.webp')):
    """递归查找所有图片文件"""
    images = []
    for ext in extensions:
        images.extend(Path(root_dir).rglob(f'*{ext}'))
        images.extend(Path(root_dir).rglob(f'*{ext.upper()}'))
    return sorted(set(images))

def parse_crop_disease_from_path(filepath, base_dir):
    """从文件路径解析作物名和病虫害名
    期望结构: base_dir/version/作物名/病虫害名/image.jpg
    """
    rel = Path(filepath).relative_to(base_dir)
    parts = rel.parts
    version = 'vegetable' if 'vegetable' in str(filepath).lower() else 'fruit'
    crop_name = None
    disease_name = None
    if len(parts) >= 3:
        crop_name = parts[-3] if parts[-3] not in ('vegetable', 'fruit') else parts[-2]
        disease_name = parts[-2]
    return version, crop_name, disease_name

def generate_sql_inserts(images, base_dir, source_type='TEACHER_DATA'):
    """生成SQL INSERT语句"""
    sql_statements = []

    for img_path in images:
        filepath = str(img_path)
        sha256 = sha256_file(filepath)
        size = os.path.getsize(filepath)
        version, crop_name, disease_name = parse_crop_disease_from_path(filepath, base_dir)

        # TODO: 根据crop_name和disease_name查询数据库获取ID
        # 暂时生成占位SQL，需要配合数据库查询脚本使用

        sql = f"""-- {crop_name} / {disease_name}
INSERT INTO disease_image (version, image_url, image_hash, file_size_bytes, source_type, label_status, is_usable)
VALUES ('{version}', '{filepath}', '{sha256}', {size}, '{source_type}', 'ai_only', TRUE)
ON CONFLICT (image_hash) DO NOTHING;
"""
        sql_statements.append(sql)

    return sql_statements

def main():
    parser = argparse.ArgumentParser(description='导入农业病虫害图片到数据库')
    parser.add_argument('--image-dir', required=True, help='图片根目录')
    parser.add_argument('--version', default='vegetable', choices=['vegetable', 'fruit'])
    parser.add_argument('--source', default='TEACHER_DATA', help='数据来源')
    parser.add_argument('--output', default='import_images.sql', help='输出SQL文件路径')
    parser.add_argument('--dry-run', action='store_true', help='仅扫描不生成SQL')

    args = parser.parse_args()
    image_dir = args.image_dir

    if not os.path.isdir(image_dir):
        print(f"错误: 目录不存在: {image_dir}")
        sys.exit(1)

    images = find_images(image_dir)
    print(f"找到 {len(images)} 张图片")

    if args.dry_run:
        for img in images[:10]:
            print(f"  {img}")
        if len(images) > 10:
            print(f"  ... 还有 {len(images) - 10} 张")
        return

    # 按版本和作物分组统计
    from collections import Counter
    crop_stats = Counter()
    for img in images:
        _, crop, _ = parse_crop_disease_from_path(str(img), image_dir)
        crop_stats[crop] += 1

    print("\n按作物统计:")
    for crop, count in crop_stats.most_common():
        print(f"  {crop}: {count}张")

    sql_statements = generate_sql_inserts(images, image_dir, args.source)

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(f"-- 自动生成: {len(images)}张图片导入SQL\n")
        f.write(f"-- 来源: {args.source}\n\n")
        f.writelines(sql_statements)

    print(f"\nSQL已生成: {args.output} ({len(images)}条INSERT)")
    print("请检查SQL后运行: psql -U postgres -d laos_agri -f import_images.sql")

if __name__ == '__main__':
    main()
