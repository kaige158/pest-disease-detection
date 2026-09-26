#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""修正迁移脚本产生的双花括号错误。

migrate_admin_templates.py 里 f-string 的花括号转义写错，导致生成的
th:replace 变成 `{{~{admin/fragments :: ...}}`，Thymeleaf 会当成模板名
`{~{admin/fragments` 去解析而报错。

用法：python scripts/fix_double_brace.py
"""
import sys
from pathlib import Path

ADMIN = (Path(__file__).resolve().parents[1]
         / "spring-backend" / "src" / "main" / "resources" / "templates" / "admin")

BAD = "{{~{admin/fragments ::"
GOOD = "{~{admin/fragments ::"


def main() -> int:
    if not ADMIN.is_dir():
        print(f"目录不存在: {ADMIN}")
        return 1

    fixed = 0
    for path in sorted(ADMIN.glob("*.html")):
        text = path.read_text(encoding="utf-8")
        if BAD not in text:
            continue
        path.write_text(text.replace(BAD, GOOD), encoding="utf-8")
        print(f"  [fixed] {path.name}")
        fixed += 1

    print(f"共修正 {fixed} 个模板")

    # 复核：不应再有任何双花括号的 fragment 引用
    remain = [p.name for p in ADMIN.glob("*.html")
              if BAD in p.read_text(encoding="utf-8")]
    if remain:
        print("仍有问题：" + ", ".join(remain))
        return 1
    print("复核通过：无残留双花括号")
    return 0


if __name__ == "__main__":
    sys.exit(main())
