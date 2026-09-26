#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把后台模板的侧边栏替换为 fragment 引用，并接入 i18n 标题。

背景：后台原先每个页面各自复制一份 <nav class="sidebar">，
新增"AI 配置中心/用户管理/语言切换"后要改 6 个文件，易漏。
统一抽成 admin/fragments.html 的 sidebar fragment 后，每个页面只剩一行。

本脚本是**一次性迁移工具**：把旧的内联侧边栏整块替换为 th:replace。
可重复执行（已迁移的文件不会再匹配到旧结构）。
"""
import re
import sys
from pathlib import Path

TEMPLATES = (Path(__file__).resolve().parents[1]
             / "spring-backend" / "src" / "main" / "resources" / "templates" / "admin")

# 匹配 <nav class="sidebar"> ... </nav>（含中间任意内容）
NAV_RE = re.compile(r'[ \t]*<nav class="sidebar">.*?</nav>\n', re.S)

# 页面 → (i18n 标题 key, emoji, currentPage)
PAGES = {
    "knowledge.html": ("knowledge.title", "📚", "knowledge"),
    "review.html": ("review.title", "🔍", "review"),
    "stats.html": ("stats.title", "📈", "stats"),
    "layout.html": ("dashboard.title", "📊", "dashboard"),
}


def migrate(path: Path, title_key: str, icon: str, current: str) -> bool:
    src = path.read_text(encoding="utf-8")
    m = NAV_RE.search(src)
    if not m:
        print(f"  [skip] {path.name}: 未找到内联侧边栏（可能已迁移）")
        return False

    replacement = f'    <nav th:replace="{{~{{admin/fragments :: sidebar(\'{current}\')}}}}"></nav>\n'
    out = src[:m.start()] + replacement + src[m.end():]

    # 顶部栏里写死的"老师"→ 真实账号；顺带补上改密提醒与通用样式
    out = re.sub(
        r'<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;">.*?</div>\s*</div>',
        '<div th:replace="~{admin/fragments :: topbar(#{' + title_key + '}, \'' + icon + '\')}"></div>\n'
        '        <div th:replace="~{admin/fragments :: passwordBanner}"></div>',
        out, count=1, flags=re.S)
    out = re.sub(r'<span style="font-size:13px;color:#666;">[^<]*老师[^<]*</span>', '', out)

    # 引入通用样式
    if 'admin/fragments :: adminStyles' not in out:
        out = out.replace('    <link rel="stylesheet" href="/css/admin.css">',
                          '    <link rel="stylesheet" href="/css/admin.css">\n'
                          '    <th:block th:replace="~{admin/fragments :: adminStyles}"></th:block>', 1)

    # 让 <html> 带上当前语言，便于 CSS/JS 判断
    out = out.replace('<html xmlns:th="http://www.thymeleaf.org">',
                      '<html xmlns:th="http://www.thymeleaf.org" th:lang="${#locale.language}">', 1)

    path.write_text(out, encoding="utf-8")
    print(f"  [ok] {path.name}: 侧边栏 → fragment，标题 → #{title_key}")
    return True


def main() -> int:
    if not TEMPLATES.is_dir():
        print(f"目录不存在: {TEMPLATES}")
        return 1
    changed = 0
    for name, (key, icon, cur) in PAGES.items():
        p = TEMPLATES / name
        if not p.exists():
            print(f"  [skip] {name}: 文件不存在")
            continue
        if migrate(p, key, icon, cur):
            changed += 1
    print(f"完成，迁移 {changed} 个模板")
    return 0


if __name__ == "__main__":
    sys.exit(main())
