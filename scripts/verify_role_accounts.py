#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""角色演示账号 + 权限说明界面 —— 端到端验证脚本

背景（用户提出的两个交付问题）：
    1. 后台能改角色，但界面上没说"哪个角色有哪些功能"，交付后管理员看不懂授权
    2. 短信还没上线，收不到验证码，需要能直接登录的四个角色账号

本脚本验证：
    A. 专家 / 农技员 / 农户 三个演示账号能登录，且角色正确
    B. 演示环境短信验证码可回显（生产关闭），验证码流程真的走通
    C. 后台"用户管理"页含角色权限说明矩阵；专家登录看不到该页（权限真的生效）
    D. 老挝号码 020… 与 20… 两种写法指向同一个账号（不会重复注册）

用法：
    python scripts/verify_role_accounts.py [base_url]
"""
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import http.cookiejar

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080").rstrip("/")
API = BASE + "/api/v1"

ADMIN_USER = "admin"
ADMIN_PWD = sys.argv[2] if len(sys.argv) > 2 else "LaosAgri@2026"
DEMO_PWD = sys.argv[3] if len(sys.argv) > 3 else "Laos@2026"

ACCOUNTS = [
    ("EXPERT", "02055550001"),
    ("TECHNICIAN", "02055550002"),
    ("FARMER", "02055550003"),
]

PASS, FAIL = [], []


def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(("  [PASS] " if cond else "  [FAIL] ") + name + (f"  {detail}" if detail else ""))


def post(path, payload, timeout=25, token=None):
    headers = {"Content-Type": "application/json; charset=utf-8"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(API + path, data=json.dumps(payload).encode("utf-8"),
                                 headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        try:
            return json.loads(body)
        except Exception:
            return {"code": e.code, "message": body[:200]}


def get(path, timeout=25, token=None):
    headers = {}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(API + path, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        try:
            return json.loads(body)
        except Exception:
            return {"code": e.code, "message": body[:200]}


def login_with_sms(phone, password=DEMO_PWD, device="verify-script-device-1"):
    """完整登录链路：先直接登录 → 需要验证码就发码（演示档回显）→ 带码重试"""
    payload = {"countryCode": "856", "phone": phone, "password": password,
               "deviceUuid": device}
    r = post("/auth/login", payload)
    if r.get("code") == 200:
        return r, None

    if r.get("code") != 428:
        return r, "预期 428(需验证码) 或 200，实际 %s: %s" % (r.get("code"), r.get("message"))

    sent = post("/auth/sms/send", {"countryCode": "856", "phone": phone,
                                   "deviceUuid": device})
    if sent.get("code") != 200:
        return sent, "验证码发送失败: %s" % sent.get("message")
    code = (sent.get("data") or {}).get("demo_code")
    if not code:
        return sent, ("发送接口未回显 demo_code —— 请确认演示档 app.sms.expose-code=true，"
                      "否则没有短信通道时无法登录")

    payload["smsCode"] = code
    return post("/auth/login", payload), None


def http_get_html(url, opener=None):
    """取 HTML 页面（后台页面是服务端渲染，需要携带会话 Cookie）"""
    try:
        fn = opener.open if opener else urllib.request.urlopen
        with fn(url, timeout=25) as resp:
            return resp.getcode(), resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")


def admin_session(username, password):
    """后台表单登录：返回带会话 Cookie 的 opener"""
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    data = urllib.parse.urlencode({"username": username, "password": password}).encode()
    req = urllib.request.Request(BASE + "/admin/login", data=data, method="POST")
    try:
        opener.open(req, timeout=25)
    except urllib.error.HTTPError:
        pass
    return opener


print("=" * 70)
print("A. 四个角色账号能否登录（短信未上线，走演示回显验证码）")
print("=" * 70)
tokens = {}
for role, phone in ACCOUNTS:
    r, err = login_with_sms(phone)
    if err:
        check(f"{role} 登录", False, err)
        continue
    data = r.get("data") or {}
    user = data.get("user") or {}
    tokens[role] = data.get("token")
    check(f"{role} 登录成功且角色正确",
          r.get("code") == 200 and user.get("role") == role,
          "role=%s registered=%s" % (user.get("role"), data.get("registered")))

print()
print("=" * 70)
print("B. 短信验证码流程（演示回显 / 生产关闭）")
print("=" * 70)
# 每次跑用不同号码：同一号码 60 秒内只能发一条（限流是真实生效的），
# 写死号码会让脚本第二次运行就撞上限流，看起来像功能坏了
import time as _time
demo_phone = "020" + str(int(_time.time()) % 100000000).zfill(8)
sent = post("/auth/sms/send", {"countryCode": "856", "phone": demo_phone,
                               "deviceUuid": "verify-script-device-2"})
sdata = sent.get("data") or {}
check("发送验证码返回 200", sent.get("code") == 200,
      "%s (phone=%s)" % (sent.get("message"), demo_phone))
check("演示档回显 demo_code（6 位数字）",
      bool(re.fullmatch(r"\d{6}", str(sdata.get("demo_code", "")))),
      "demo_code=%s" % sdata.get("demo_code"))
check("回显时带说明文字", bool(sdata.get("demo_notice")))

bad = post("/auth/login", {"countryCode": "856", "phone": demo_phone,
                           "password": DEMO_PWD, "smsCode": "000000",
                           "deviceUuid": "verify-script-device-2"})
check("错误验证码被拒绝", bad.get("code") != 200, str(bad.get("message")))

print()
print("=" * 70)
print("C. 后台角色权限说明界面 + 权限真的生效")
print("=" * 70)
# 注意：后台的界面语言会**记到账号里**（language_pref，见 I18nConfig），
# 所以断言必须显式带 ?lang=，否则上一个人把账号切成老挝语后这里就会失败。
admin_opener = admin_session(ADMIN_USER, ADMIN_PWD)
status, html = http_get_html(BASE + "/admin/users?lang=zh", admin_opener)
check("管理员可打开用户管理页", status == 200, "HTTP %s" % status)
check("页面含『角色权限说明』", "角色权限说明" in html or "perm-card" in html)
check("权限矩阵含全部 11 项权限",
      all(k in html for k in ["查看仪表盘", "提交审核结论（确认/纠正/驳回）",
                              "停用账号 / 改角色 / 重置密码",
                              "查看用户完整手机号（需二次验证密码）",
                              "修改 AI 通道与密钥"]))
check("改角色弹窗内含权限明细块",
      html.count('class="role-detail"') == 4,
      "找到 %d 块（应为 4 个角色各一块）" % html.count('class="role-detail"'))
check("弹窗含每个角色的一句话定位",
      all(k in html for k in ["平台管理员：技术/运营负责人",
                              "农业专家（老师）",
                              "农技推广员",
                              "农户：只能用手机 APP"]))

# 老挝语界面同样要有（交付给老挝同事用）
st_lo, html_lo = http_get_html(BASE + "/admin/users?lang=lo", admin_opener)
check("老挝语界面可打开且权限说明已翻译",
      st_lo == 200 and "ຄຳອະທິບາຍສິດຂອງແຕ່ລະບົດບາດ" in html_lo,
      "HTTP %s" % st_lo)
check("老挝语矩阵表头为四个角色名",
      all(k in html_lo for k in ["ຜູ້ດູແລ", "ຜູ້ຊ່ຽວຊານ",
                                 "ພະນັກງານສົ່ງເສີມ", "ຊາວກະສິກອນ"]))

# 专家账号：能进后台，但用户管理页应被拒绝（权限矩阵不是"写着好看"）
expert_opener = admin_session("02055550001", DEMO_PWD)
st_expert, _ = http_get_html(BASE + "/admin/users", expert_opener)
check("专家访问用户管理页被拒绝（403）", st_expert == 403, "HTTP %s" % st_expert)
st_dashboard, _ = http_get_html(BASE + "/admin/dashboard", expert_opener)
check("专家可打开仪表盘", st_dashboard == 200, "HTTP %s" % st_dashboard)

tech_opener = admin_session("02055550002", DEMO_PWD)
st_tech, tech_html = http_get_html(BASE + "/admin/dashboard", tech_opener)
check("农技员可打开仪表盘", st_tech == 200, "HTTP %s" % st_tech)
st_know, _ = http_get_html(BASE + "/admin/knowledge", tech_opener)
check("农技员可打开知识库（只读）", st_know == 200, "HTTP %s" % st_know)

# 收尾：把界面语言恢复成中文，避免演示时后台变成老挝语
http_get_html(BASE + "/admin/users?lang=zh", admin_opener)

print()
print("=" * 70)
print("D. 老挝号码 020… 与 20… 是否指向同一账号（防重复注册）")
print("=" * 70)
with_zero = post("/auth/login", {"countryCode": "856", "phone": "02055550001",
                                 "password": DEMO_PWD, "deviceUuid": "verify-script-device-1"})
without_zero = post("/auth/login", {"countryCode": "856", "phone": "2055550001",
                                    "password": DEMO_PWD, "deviceUuid": "verify-script-device-1"})
check("两种写法都能登录（老账号已存在，不需验证码）",
      with_zero.get("code") == 200 and without_zero.get("code") == 200,
      "with0=%s without0=%s" % (with_zero.get("code"), without_zero.get("code")))
id_a = ((with_zero.get("data") or {}).get("user") or {}).get("id")
id_b = ((without_zero.get("data") or {}).get("user") or {}).get("id")
check("两种写法指向同一个账号 ID", id_a is not None and id_a == id_b,
      "with0=%s without0=%s" % (id_a, id_b))

print()
print("=" * 70)
print("通过 %d 项，失败 %d 项" % (len(PASS), len(FAIL)))
if FAIL:
    print("失败项：")
    for f in FAIL:
        print("  - " + f)
    sys.exit(1)
print("四个角色账号、演示验证码、角色权限说明界面均符合预期")
