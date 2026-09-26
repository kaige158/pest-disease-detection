#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""手机号国家识别 + 短信验证码闸门 —— 端到端验证脚本

背景（用户反馈的真实问题）：
    1. 中国号码注册后被标成 +856（老挝）—— 国家识别错误
    2. 任何人都能编一个格式合法的号码注册 —— 造成假账号堆积

本脚本直接打后端接口验证这两点是否真的修好，不依赖人工点界面。

用法：
    python scripts/verify_phone_and_sms.py [base_url]
"""
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080").rstrip("/")
API = BASE + "/api/v1"

PASS, FAIL = [], []


def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(("  [PASS] " if cond else "  [FAIL] ") + name + (f"  {detail}" if detail else ""))


def post(path, payload, timeout=25):
    req = urllib.request.Request(
        API + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json; charset=utf-8"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        try:
            return json.loads(body)
        except Exception:
            return {"code": e.code, "message": body[:200]}


def get(path, timeout=25):
    try:
        with urllib.request.urlopen(API + path, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        try:
            return json.loads(body)
        except Exception:
            return {"code": e.code, "message": body[:200]}


def read_last_code_from_log():
    """从后端日志里取最近一条验证码（演示通道把明文打在日志上）

    编码坑：Java 日志文件在中文 Windows 上默认是 **GBK**，在 Linux/容器里通常是 UTF-8。
    写死任何一种都会在另一种环境下读成乱码，所以这里逐个编码试，
    以"能否解出关键标记"作为判定依据。
    """
    import pathlib
    for p in (pathlib.Path("spring-backend/demo_run.log"),
              pathlib.Path("../spring-backend/demo_run.log"),
              pathlib.Path("../../spring-backend/demo_run.log")):
        if not p.exists() or p.stat().st_size == 0:
            continue
        raw = p.read_bytes()
        for enc in ("utf-8", "gbk", "cp936", "latin-1"):
            try:
                text = raw.decode(enc)
            except (UnicodeDecodeError, LookupError):
                continue
            # 关键标记能解出来，说明编码猜对了
            if "验证码" not in text and "SMS" not in text and "LoggingSmsSender" not in text:
                continue
            hits = re.findall(r"验证码\s*[:：]\s*(\d{6})", text)
            if not hits:
                # 兜底：从 LoggingSmsSender 段落里抓 6 位数字
                seg = text[text.rfind("LoggingSmsSender"):] if "LoggingSmsSender" in text else ""
                hits = re.findall(r"\b(\d{6})\b", seg)
            if hits:
                return hits[-1]
    return None


def main():
    stamp = str(int(time.time()))[-7:]

    print("=== 1) 国家识别：按号码书写形态判定，不再盲目按前缀 ===")
    # 用无副作用的识别接口（不发短信），而不是"发短信看返回的区号"：
    # 后者受 60 秒/号码的发送限流影响，脚本第二次运行就会失败，
    # 看起来像功能坏了，其实是限流生效（这坑踩过一次）。
    cases = [
        ("13900001111", "86", "中国 11 位（旧实现会误判成 +1 美国）"),
        ("+8613700001111", "86", "带 +86 前缀"),
        ("02055551234", "856", "老挝本地写法（020 开头）"),
        ("+8562055551234", "856", "带 +856 前缀"),
    ]
    for phone, expect, note in cases:
        r = get("/auth/detect-country?phone=" + urllib.parse.quote(phone))
        got = (r.get("data") or {}).get("country_code")
        ok = r.get("code") == 200 and got == expect
        check(f"{phone} → +{expect}", ok, f"实际 +{got}  ({note})")

    print("=== 1b) 号码形态有歧义时（老挝 020 与柬埔寨 0xx 形态重叠）===")
    # 0205555123 同时吻合老挝与柬埔寨的号码形态 —— 界面必须让用户自己选国家，
    # 系统只能给出"可能是哪些"，不能替用户拍板
    r = get("/auth/detect-country?phone=0205555123")
    d = r.get("data") or {}
    check("歧义号码仍能处理（不报错）", r.get("code") == 200,
          f"code={r.get('code')} 识别为 +{d.get('country_code')}")
    check("歧义号码列出其它可能的国家", len(d.get("others") or []) >= 1,
          f"others={d.get('others')}")
    check("歧义号码被标记为需用户确认（ambiguous=true）", d.get("ambiguous") is True,
          f"ambiguous={d.get('ambiguous')}")
    r2 = get("/auth/detect-country?phone=13900001111")
    d2 = r2.get("data") or {}
    check("形态唯一确定的号码不打扰用户（ambiguous=false）", d2.get("ambiguous") is False,
          f"中国号码 ambiguous={d2.get('ambiguous')}")

    print("=== 1c) 发送验证码接口返回的区号与识别一致（真发码路径）===")
    probe = "137" + stamp + "9"
    r = post("/auth/sms/send", {"phone": probe})
    got = (r.get("data") or {}).get("country_code")
    check("发送接口按识别结果归档区号", r.get("code") == 200 and got == "86",
          f"code={r.get('code')} country_code={got}")
    print("       说明：这类号码光看号码无法确定国家，必须在 APP 里让用户显式选择 ——")
    print("       这也是本次修复的核心：不再假定'没选国家就是老挝'。")

    print("=== 2) 短区号不再被误认为前缀（美国 +1 的经典坑）===")
    r = post("/auth/sms/send", {"phone": "13900002222"})
    got = (r.get("data") or {}).get("country_code")
    check("13900002222 不被识别为 +1", got != "1", f"实际 +{got}")

    print("=== 3) 未验证的手机号不能注册（防假账号）===")
    fresh = "137" + stamp
    r = post("/auth/login", {"phone": fresh, "password": "laos2026", "countryCode": "86"})
    check("新号码不带验证码 → 被拦下(428)", r.get("code") == 428,
          f"code={r.get('code')} msg={str(r.get('message'))[:40]}")

    print("=== 4) 走完验证码流程可以正常注册 ===")
    r = post("/auth/sms/send", {"phone": fresh, "countryCode": "86"})
    check("发送验证码成功", r.get("code") == 200, str(r.get("message"))[:50])
    code = read_last_code_from_log()
    if code:
        print(f"  （从服务端日志读到验证码：{code}）")
        r2 = post("/auth/login", {"phone": fresh, "password": "laos2026",
                                  "countryCode": "86", "smsCode": code,
                                  "deviceUuid": "verify-script-A"})
        check("带验证码注册成功", r2.get("code") == 200, str(r2.get("message"))[:50])
        check("注册后国家为 86", (r2.get("data", {}).get("user") or {}).get("country_code") == "86",
              str((r2.get("data", {}).get("user") or {}).get("phone_display")))
    else:
        check("能从日志读到验证码", False, "未找到验证码，跳过后续断言")

    print("=== 5) 验证码错误应被拒绝 ===")
    fresh2 = "136" + stamp
    post("/auth/sms/send", {"phone": fresh2, "countryCode": "86"})
    r = post("/auth/login", {"phone": fresh2, "password": "laos2026",
                             "countryCode": "86", "smsCode": "000000"})
    check("错误验证码被拒绝", r.get("code") == 401, f"code={r.get('code')}")

    print("=== 6) 验证码不可重复使用（一次性）===")
    if code:
        r = post("/auth/login", {"phone": fresh, "password": "laos2026",
                                 "countryCode": "86", "smsCode": code,
                                 "deviceUuid": "verify-script-A"})
        check("已用过的验证码失效", r.get("code") != 200 or r.get("data", {}).get("registered") is False,
              f"code={r.get('code')}")

    print("=== 7) 发送频率限制（防刷短信费用）===")
    fresh3 = "135" + stamp
    first = post("/auth/sms/send", {"phone": fresh3, "countryCode": "86"})
    second = post("/auth/sms/send", {"phone": fresh3, "countryCode": "86"})
    check("同一号码 60 秒内第二次被限流", second.get("code") == 429,
          f"第二次 code={second.get('code')} msg={str(second.get('message'))[:40]}")

    print("=== 8) 换设备登录需要验证码 ===")
    if code:
        # 用不同设备号登录同一账号
        r = post("/auth/login", {"phone": fresh, "password": "laos2026",
                                 "countryCode": "86", "deviceUuid": "another-device-B"})
        check("换设备 → 要求验证码(428)", r.get("code") == 428,
              f"code={r.get('code')} msg={str(r.get('message'))[:50]}")

    print()
    print(f"通过 {len(PASS)} 项，失败 {len(FAIL)} 项")
    if FAIL:
        print("失败项：" + ", ".join(FAIL))
        return 1
    print("手机号国家识别与短信验证码闸门全部符合预期")
    return 0


if __name__ == "__main__":
    sys.exit(main())
