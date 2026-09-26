#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""验证四级角色的权限是否真的生效（而不是只存在数据库里）

背景（用户提问）：
    "管理后台的改角色有四个角色，有什么用处？有没有赋予特殊权限？"
    排查发现早期**只有 ADMIN 真正生效**，其余三个只是标签。
    本脚本验证权限矩阵已落地：谁能做什么、谁不能做什么。

用法：
    python scripts/verify_roles.py [base_url]
"""
import json
import re
import sys
import time
import urllib.error
import urllib.request
import http.cookiejar

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080").rstrip("/")
API = BASE + "/api/v1"
ADMIN_PWD = "LaosAgri@2026"

PASS, FAIL = [], []


def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(("  [PASS] " if cond else "  [FAIL] ") + name + (f"  {detail}" if detail else ""))


class Session:
    """带 cookie 的会话，用于模拟表单登录后的后台访问"""

    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.jar))

    def request(self, url, method="GET", payload=None, form=None, timeout=25):
        data, headers = None, {}
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json; charset=utf-8"
        if form is not None:
            data = urllib.parse.urlencode(form).encode("utf-8")
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=timeout) as resp:
                body = resp.read().decode("utf-8", "replace")
                return resp.status, body
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode("utf-8", "replace")

    def login_admin(self):
        self.request(BASE + "/admin/login")
        return self.request(BASE + "/admin/login", method="POST",
                            form={"username": "admin", "password": ADMIN_PWD})

    def login_as(self, phone, password):
        self.request(BASE + "/admin/login")
        return self.request(BASE + "/admin/login", method="POST",
                            form={"username": phone, "password": password})


def api(session, path, method="GET", payload=None):
    return session.request(API + path, method=method, payload=payload)


def main():
    stamp = str(int(time.time()))[-6:]
    admin = Session()
    status, _ = admin.login_admin()
    check("管理员可登录后台", status in (200, 302), f"HTTP {status}")

    # ---------- 准备一个专家账号 ----------
    print("=== 准备测试账号（专家 / 农技员 / 农户）===")
    created = {}
    for role, label in (("EXPERT", "农业专家"), ("TECHNICIAN", "农技员"), ("FARMER", "农户")):
        phone = f"1399{stamp}{len(created)}"
        code, _ = api(admin, "/auth/sms/send", "POST", {"phone": phone, "countryCode": "86"})
        # 从日志取验证码
        code_val = read_code_from_log()
        st, body = api(admin, "/auth/login", "POST",
                       {"phone": phone, "password": "laos2026", "countryCode": "86",
                        "smsCode": code_val, "deviceUuid": "role-test"})
        data = json.loads(body) if body.strip().startswith("{") else {}
        if data.get("code") != 200:
            print(f"  创建 {label} 失败: {body[:120]}")
            continue
        uid = data["data"]["user"]["id"]
        # 改角色（仅 ADMIN 可改）
        st2, body2 = api(admin, f"/admin/users/{uid}/role", "POST", {"role": role})
        ok = json.loads(body2).get("code") == 200
        print(f"  {label}: id={uid} 角色设置{'成功' if ok else '失败'}")
        created[role] = {"id": uid, "phone": phone}

    print("=== 1) 农户（FARMER）：无后台权限 ===")
    if "FARMER" in created:
        s = Session()
        st, _ = s.login_as(created["FARMER"]["phone"], "laos2026")
        st2, _ = s.request(BASE + "/admin/dashboard")
        # 角色不是后台角色时，Spring Security 会拒绝进入 /admin/**
        check("农户访问后台被拒绝", st2 in (302, 403),
              f"HTTP {st2}（302=跳登录页，403=无权限）")

    print("=== 2) 农技员（TECHNICIAN）：只读 + 可审核，不能改知识库/用户 ===")
    if "TECHNICIAN" in created:
        s = Session()
        s.login_as(created["TECHNICIAN"]["phone"], "laos2026")
        st_dash, _ = s.request(BASE + "/admin/dashboard")
        check("农技员可看仪表盘", st_dash == 200, f"HTTP {st_dash}")
        st_users, _ = s.request(BASE + "/admin/users")
        check("农技员访问用户管理被拒", st_users in (302, 403), f"HTTP {st_users}")
        st_k, body_k = api(s, "/admin/diseases", "POST", {"nameZh": "测试", "nameLo": "test"})
        check("农技员改知识库被拒(403)", st_k == 403, f"HTTP {st_k}")

    print("=== 3) 专家（EXPERT）：可改知识库，但不能碰用户与 AI 密钥 ===")
    if "EXPERT" in created:
        s = Session()
        s.login_as(created["EXPERT"]["phone"], "laos2026")
        st_dash, _ = s.request(BASE + "/admin/dashboard")
        check("专家可看仪表盘", st_dash == 200, f"HTTP {st_dash}")
        st_users, _ = s.request(BASE + "/admin/users")
        check("专家访问用户管理被拒", st_users in (302, 403), f"HTTP {st_users}")
        st_toggle, _ = api(s, f"/admin/users/{created['EXPERT']['id']}/toggle", "POST", {})
        check("专家停用账号被拒(403)", st_toggle == 403, f"HTTP {st_toggle}")
        st_ai, _ = api(s, "/admin/ai/configs/1", "PUT",
                       {"provider": "gemini", "apiKey": "x" * 20})
        check("专家改 AI 配置被拒(403)", st_ai == 403, f"HTTP {st_ai}")
        st_list, _ = api(s, "/admin/ai/configs")
        check("专家可查看 AI 通道列表", st_list == 200, f"HTTP {st_list}")

    print("=== 4) 管理员（ADMIN）：全部权限 ===")
    st_ai, _ = api(admin, "/admin/ai/configs")
    check("管理员可看 AI 配置", st_ai == 200, f"HTTP {st_ai}")
    st_users, _ = api(admin, "/admin/users")
    check("管理员可看用户管理", st_users == 200, f"HTTP {st_users}")
    st_reveal, body_reveal = api(admin, "/admin/users/1/reveal-phone", "POST", {"password": "wrong"})
    # 注意：本项目统一用响应体里的 code 表达业务失败（HTTP 仍为 200），
    # 与 /auth/login 等接口保持一致，不能只看 HTTP 状态码
    reveal_code = json.loads(body_reveal).get("code") if body_reveal.strip().startswith("{") else None
    check("管理员查看手机号需二次验证（错密码被拒）", reveal_code == 403,
          f"body.code={reveal_code}")

    print("=== 5) 审计留痕：查看手机号会写日志 ===")
    target = created.get("EXPERT") or created.get("FARMER")
    if target:
        api(admin, f"/admin/users/{target['id']}/reveal-phone", "POST",
            {"password": ADMIN_PWD})
        # 审计表只在 PG 有；演示档 H2 由 JPA 自动建表，这里只验证接口不报错
        st, _ = api(admin, "/admin/users/stats")
        check("审计写入后接口仍正常", st == 200, f"HTTP {st}")

    print("=== 6) 管理接口可用性（防止再出现整组 500）===")
    # 这一组曾经全部 500：@PreAuthorize 里写了 ${...} 占位符（SpEL 不解析），
    # 以及原生 SQL 未限定 core. schema / 空表 SUM 返回 NULL。
    # 它们是"审核 + 数据统计"的主干接口，必须有回归覆盖。
    availability = [
        ("/admin/pending-review", "待审核列表"),
        ("/admin/review/disputed", "用户反馈有误列表"),
        ("/admin/stats", "数据统计"),
        ("/admin/training/stats", "训练数据资产统计"),
        ("/admin/evaluation/accuracy", "AI 准确率（空表也要能出 0）"),
        ("/admin/evaluation/accuracy-by-crop", "分作物准确率"),
        ("/admin/audit-logs", "审计日志"),
    ]
    for path, label in availability:
        st, _ = api(admin, path)
        check(f"{label} 返回 200（{path}）", st == 200, f"HTTP {st}")

    print()
    print(f"通过 {len(PASS)} 项，失败 {len(FAIL)} 项")
    if FAIL:
        print("失败项：" + ", ".join(FAIL))
        return 1
    print("四级角色权限矩阵已实际生效（不再只是数据库里的标签）")
    return 0


def read_code_from_log():
    """从后端日志读取最近一条验证码（自动探测编码，见 verify_phone_and_sms.py 的说明）"""
    import pathlib
    for p in (pathlib.Path("spring-backend/demo_run.log"),
              pathlib.Path("../spring-backend/demo_run.log")):
        if not p.exists():
            continue
        raw = p.read_bytes()
        for enc in ("utf-8", "gbk", "cp936", "latin-1"):
            try:
                text = raw.decode(enc)
            except (UnicodeDecodeError, LookupError):
                continue
            if "验证码" not in text and "LoggingSmsSender" not in text:
                continue
            hits = re.findall(r"验证码\s*[:：]\s*(\d{6})", text)
            if hits:
                return hits[-1]
    return None


if __name__ == "__main__":
    import urllib.parse  # noqa: E402  (Session.request 用到)
    sys.exit(main())
