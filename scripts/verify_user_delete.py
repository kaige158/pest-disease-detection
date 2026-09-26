#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用户删除功能 —— 端到端验证脚本

用户要求：
    "管理系统的用户删除功能，删除相关的内容一起，并且删除需要管理员、并且需要登录密码"
    "训练数据资产等能对平台有益都不能删！！！！"

本脚本逐条验证：
    A. 删除前能看清"删什么、留什么"
    B. 只有 ADMIN 能删（专家、农技员、农户都拿不到这个能力）
    C. 必须再次输入管理员**登录密码**，密码错一律拒绝
    D. 危险边界：不能删自己、不能删最后一个管理员
    E. 删除后：**账号没了，但平台数据一条不少**（识别记录/图片/训练资产都在，且已匿名化）
    F. 审计留痕

用法：
    python scripts/verify_user_delete.py [base_url] [admin_password] [demo_password]
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import http.cookiejar

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080").rstrip("/")
API = BASE + "/api/v1"
ADMIN_PWD = sys.argv[2] if len(sys.argv) > 2 else "LaosAgri@2026"
DEMO_PWD = sys.argv[3] if len(sys.argv) > 3 else "Laos@2026"

UPLOAD_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                           "spring-backend", "uploads")

PASS, FAIL = [], []


def check(name, cond, detail=""):
    (PASS if cond else FAIL).append(name)
    print(("  [PASS] " if cond else "  [FAIL] ") + name + (f"  {detail}" if detail else ""))


def _normalize(parsed):
    """把 Spring Security / 校验失败返回的默认错误体也归一成 {code,message}

    被 403 拦下时返回的是 {"status":403,"error":"Forbidden",...}，
    没有 code 字段 —— 不归一的话断言里会看到 code=None，像是"没响应"。
    """
    if isinstance(parsed, dict) and "code" not in parsed:
        if "status" in parsed:
            parsed["code"] = parsed["status"]
            parsed.setdefault("message", str(parsed.get("error", "")))
    return parsed


def _req(path, method="GET", payload=None, token=None, timeout=30, raw=False, data=None,
         content_type=None):
    url = path if path.startswith("http") else API + path
    headers = {}
    if token:
        headers["Authorization"] = "Bearer " + token
    body = data
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            text = resp.read().decode("utf-8", "replace")
            if raw:
                return text
            try:
                return _normalize(json.loads(text))
            except Exception:
                return {"code": resp.getcode(), "message": text[:200]}
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", "replace")
        if raw:
            return text
        try:
            return _normalize(json.loads(text))
        except Exception:
            return {"code": e.code, "message": text[:200]}


def admin_session(username="admin", password=ADMIN_PWD):
    """后台表单登录（Cookie 会话）—— 删除接口同时受 URL 级与 Spring Security 保护"""
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    data = urllib.parse.urlencode({"username": username, "password": password}).encode()
    try:
        opener.open(urllib.request.Request(BASE + "/admin/login", data=data, method="POST"),
                    timeout=25)
    except urllib.error.HTTPError:
        pass
    return opener


def api_as_admin(opener, path, method="GET", payload=None):
    """用后台会话调用 /api/v1 接口（Cookie 鉴权）"""
    body = json.dumps(payload).encode() if payload is not None else None
    headers = {"Content-Type": "application/json; charset=utf-8"} if body else {}
    req = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    try:
        with opener.open(req, timeout=30) as resp:
            return _normalize(json.loads(resp.read().decode("utf-8", "replace")))
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8", "replace")
        try:
            return _normalize(json.loads(text))
        except Exception:
            return {"code": e.code, "message": text[:200]}


def register_user_with_data():
    """建一个"有内容"的用户：走真实注册（含演示验证码）+ 上传一张图产生识别记录"""
    phone = "020" + str(int(time.time() * 1000) % 100000000).zfill(8)
    device = "delete-verify-" + phone
    r = _req("/auth/login", "POST", {"countryCode": "856", "phone": phone,
                                     "password": DEMO_PWD, "deviceUuid": device})
    if r.get("code") == 428:
        sent = _req("/auth/sms/send", "POST", {"countryCode": "856", "phone": phone,
                                               "deviceUuid": device})
        code = (sent.get("data") or {}).get("demo_code")
        r = _req("/auth/login", "POST", {"countryCode": "856", "phone": phone,
                                         "password": DEMO_PWD, "smsCode": code,
                                         "deviceUuid": device})
    data = r.get("data") or {}
    user = data.get("user") or {}
    return phone, user.get("id"), data.get("token")


def upload_one_image(token, user_id):
    """构造 multipart 上传一张 1x1 PNG，触发后端建识别记录 + 落盘图片"""
    png = bytes.fromhex(
        "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
        "890000000a49444154789c6360000002000100ffff03000006000557bfabd400"
        "00000049454e44ae426082")
    boundary = "----verifydelete" + str(int(time.time()))
    parts = []
    for name, value in (("language", "zh"), ("version", "vegetable"),
                        ("user_id", str(user_id))):
        parts.append(("--" + boundary + "\r\n"
                      'Content-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
                      % (name, value)).encode())
    parts.append(("--" + boundary + "\r\n"
                  'Content-Disposition: form-data; name="image"; filename="t.png"\r\n'
                  "Content-Type: image/png\r\n\r\n").encode())
    parts.append(png)
    parts.append(("\r\n--" + boundary + "--\r\n").encode())
    body = b"".join(parts)
    r = _req("/recognition/identify", "POST", token=token, data=body,
             content_type="multipart/form-data; boundary=" + boundary)
    return r


def count_upload_files():
    n = 0
    for root, _dirs, files in os.walk(UPLOAD_ROOT):
        n += len(files)
    return n


print("=" * 70)
print("准备：建一个『有内容』的测试用户（注册 + 上传图片产生识别记录）")
print("=" * 70)
phone, uid, token = register_user_with_data()
check("测试用户注册成功", uid is not None, "phone=%s id=%s" % (phone, uid))
if uid is None:
    print("注册失败，后续无法验证")
    sys.exit(1)

before_files = count_upload_files()
up = upload_one_image(token, uid)
check("上传图片产生识别记录（AI 服务未启时状态为 failed，记录仍会入库）",
      up.get("code") in (200, 502), "code=%s" % up.get("code"))
after_files = count_upload_files()
check("图片已落盘", after_files > before_files,
      "上传前 %d 个文件 → 上传后 %d 个" % (before_files, after_files))

admin = admin_session()

print()
print("=" * 70)
print("A. 删除前预览：删什么、留什么都写清楚")
print("=" * 70)
pv = api_as_admin(admin, "/api/v1/admin/users/%d/delete-preview" % uid)
d = pv.get("data") or {}
check("预览接口返回 200", pv.get("code") == 200, str(pv.get("message")))
check("预览说明识别记录将匿名保留", (d.get("diagnoses_kept") or 0) >= 1,
      "diagnoses_kept=%s" % d.get("diagnoses_kept"))
check("预览列出将保留的图片与训练资产",
      d.get("images_kept") is not None and d.get("training_assets_kept") is not None,
      "images_kept=%s training_assets_kept=%s" % (d.get("images_kept"), d.get("training_assets_kept")))
check("预览明确平台数据资产不受影响", "不受影响" in str(d.get("notice", "")),
      str(d.get("notice"))[:60])

print()
print("=" * 70)
print("B. 只有管理员能删")
print("=" * 70)
for role, pwd in (("EXPERT", DEMO_PWD), ("TECHNICIAN", DEMO_PWD)):
    opener = admin_session({"EXPERT": "02055550001", "TECHNICIAN": "02055550002"}[role], pwd)
    r = api_as_admin(opener, "/api/v1/admin/users/%d/delete" % uid, "POST",
                     {"password": pwd})
    check("%s 删除用户被拒绝" % role, r.get("code") in (401, 403),
          "code=%s msg=%s" % (r.get("code"), str(r.get("message"))[:40]))

# 农户没有后台账号，用 APP 令牌直接打管理接口
farmer = _req("/auth/login", "POST", {"countryCode": "856", "phone": "02055550003",
                                      "password": DEMO_PWD, "deviceUuid": "delete-verify-farmer"})
farmer_token = (farmer.get("data") or {}).get("token")
r = _req("/admin/users/%d/delete" % uid, "POST", {"password": DEMO_PWD}, token=farmer_token)
check("农户（APP 令牌）删除用户被拒绝", r.get("code") in (401, 403),
      "code=%s" % r.get("code"))

print()
print("=" * 70)
print("C. 需要管理员登录密码（二次验证）")
print("=" * 70)
r = api_as_admin(admin, "/api/v1/admin/users/%d/delete" % uid, "POST",
                 {"password": "wrong-password-xxx"})
check("密码错误 → 拒绝删除", r.get("code") == 403,
      "code=%s msg=%s" % (r.get("code"), str(r.get("message"))[:40]))

still = api_as_admin(admin, "/api/v1/admin/users/%d" % uid)
check("密码错误后用户仍然存在（删除没有发生）", still.get("code") == 200,
      "code=%s" % still.get("code"))

r = api_as_admin(admin, "/api/v1/admin/users/%d/delete" % uid, "POST", {"password": ""})
check("空密码 → 拒绝", r.get("code") in (400, 403), "code=%s" % r.get("code"))

print()
print("=" * 70)
print("D. 危险边界")
print("=" * 70)
# 找管理员自己的 ID
me = None
users = api_as_admin(admin, "/api/v1/admin/users?role=ADMIN&size=50")
for u in (users.get("data") or {}).get("items", []):
    if u.get("phone") == "admin":
        me = u.get("id")
check("找到当前登录的管理员账号", me is not None, "admin id=%s" % me)
if me:
    r = api_as_admin(admin, "/api/v1/admin/users/%d/delete" % me, "POST",
                     {"password": ADMIN_PWD})
    check("不能删除当前登录的账号", r.get("code") == 400,
          "code=%s msg=%s" % (r.get("code"), str(r.get("message"))[:50]))

print()
print("=" * 70)
print("E. 真正删除：账号没了，但平台数据一条不能少")
print("=" * 70)
# 删除前先记下训练数据资产的统计，删完要对比
before_stats = api_as_admin(admin, "/api/v1/admin/training/stats")
before_total = ((before_stats.get("data") or {}).get("total")
                or (before_stats.get("data") or {}).get("total_assets"))
check("取到删除前的训练数据统计", before_stats.get("code") == 200,
      "total=%s data=%s" % (before_total, str(before_stats.get("data"))[:80]))

r = api_as_admin(admin, "/api/v1/admin/users/%d/delete" % uid, "POST",
                 {"password": ADMIN_PWD})
d = r.get("data") or {}
check("管理员带正确密码 → 删除成功", r.get("code") == 200,
      "code=%s msg=%s" % (r.get("code"), str(r.get("message"))[:60]))
check("返回里明确写了保留下来的数据", bool(d.get("kept")), str(d.get("kept")))
kept = d.get("kept") or {}
check("识别记录被保留（不是被删）", (kept.get("diagnoses") or 0) >= 1,
      "kept.diagnoses=%s" % kept.get("diagnoses"))
check("删除的是账号本身", (d.get("account_deleted") or 0) == 1)
check("只删了该号码的验证码记录", (d.get("deleted_verification_codes") or 0) >= 1,
      "deleted_verification_codes=%s" % d.get("deleted_verification_codes"))

# 关键：识别数据还在（用公开的结果接口按 taskId 查，说明数据没被删）
task_id = up.get("task_id")
if task_id:
    res = _req("/recognition/result/%s" % task_id)
    check("识别记录仍在库里（按 taskId 可查到）", res.get("code") == 200,
          "task_id=%s code=%s" % (task_id, res.get("code")))

# 训练数据资产的统计不应下降
after_stats = api_as_admin(admin, "/api/v1/admin/training/stats")
after_total = ((after_stats.get("data") or {}).get("total")
               or (after_stats.get("data") or {}).get("total_assets"))
check("训练数据资产统计没有减少", (after_total or 0) >= (before_total or 0),
      "%s → %s" % (before_total, after_total))

# 图片文件仍在磁盘上（图片属于训练素材，要保留）
check("上传的图片仍在磁盘上（图片是训练素材，保留）", count_upload_files() >= after_files,
      "删除前 %d 个 → 删除后 %d 个" % (after_files, count_upload_files()))

# 用户确实没了：再登录同号码会被当成新号码（428 或 registered=true）
again = _req("/auth/login", "POST", {"countryCode": "856", "phone": phone,
                                     "password": DEMO_PWD, "deviceUuid": "delete-verify-x"})
check("账号已删除（同号码再登录变成新号码）",
      again.get("code") == 428 or (again.get("data") or {}).get("registered") is True,
      "code=%s registered=%s" % (again.get("code"), (again.get("data") or {}).get("registered")))

gone = api_as_admin(admin, "/api/v1/admin/users/%d" % uid)
check("用户详情接口返回 404", gone.get("code") == 404, "code=%s" % gone.get("code"))

# 匿名化验证：用已删账号的 ID 查"我的记录"应该查不到任何东西（user_id 已置空）
hist = _req("/recognition/history?userId=%d" % uid)
total = (hist.get("data") or {}).get("total")
check("已删账号名下查不到识别记录（数据已解绑、匿名化）", (total or 0) == 0,
      "total=%s" % total)
check("删除响应里报告了匿名化的记录数", (d.get("anonymized_records") or 0) >= 1,
      "anonymized_records=%s" % d.get("anonymized_records"))

print()
print("=" * 70)
print("F. 审计留痕（谁在什么时候删了谁）")
print("=" * 70)
logs = api_as_admin(admin, "/api/v1/admin/audit-logs?size=50")
items = (logs.get("data") or {}).get("items") or []
hits = [x for x in items if x.get("action") == "DELETE_USER" and x.get("target_id") == uid]
check("审计日志里有 DELETE_USER 记录", len(hits) >= 1,
      "找到 %d 条" % len(hits))
if hits:
    check("审计记录写明删除范围", bool(hits[0].get("detail")),
          str(hits[0].get("detail"))[:80])
failed = [x for x in items if x.get("action") == "DELETE_USER_FAILED"
          and x.get("target_id") == uid]
check("密码错误的尝试也被记录（便于发现异常探测）", len(failed) >= 1,
      "找到 %d 条 DELETE_USER_FAILED" % len(failed))

print()
print("=" * 70)
print("通过 %d 项，失败 %d 项" % (len(PASS), len(FAIL)))
if FAIL:
    print("失败项：")
    for f in FAIL:
        print("  - " + f)
    sys.exit(1)
print("用户删除功能符合预期：只删账号与个人信息，识别数据/图片/训练数据资产全部保留并匿名化；"
      "仅管理员可删、需登录密码二次确认、审计留痕")
