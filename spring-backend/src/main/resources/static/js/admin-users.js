// 用户管理交互 —— 文案由页面 #i18n 的 data-* 注入（服务端按当前语言渲染）
(function () {
    'use strict';

    var T = {};
    (function loadI18n() {
        var el = document.getElementById('i18n');
        if (!el) return;
        // 注意：这里的键必须与 users.html 里 #i18n 的 data-* 完全对应。
        // 漏一个键不会报错，只会让对应按钮/提示显示空白 —— 所以下面加了自检。
        ['total', 'page', 'totalCount', 'resetPwdTitle', 'resetPwdHint', 'resetPwdUser',
         'resetPwdDone', 'roleTitle', 'roleHint', 'roleDone', 'noData', 'loading',
         'disable', 'enable', 'changeRole', 'resetPassword',
         'enabled', 'disabled',
         'revealTitle', 'revealUser', 'revealSubmit', 'revealFailed', 'revealPhone',
         'revealPwdEmpty',
         'disableConfirm', 'enableConfirm', 'toggleDone',
         'roleFarmer', 'roleTechnician', 'roleExpert', 'roleAdmin',
         'roleCurrent', 'roleSecurityNote', 'rolePasswordPlaceholder', 'rolePasswordEmpty',
         'resetPwdTooShort', 'failed',
         'delete', 'deleteTitle', 'deleteUser', 'deleteWillDelete', 'deleteWillKeep',
         'deleteAccount', 'deleteDiag', 'deleteImages',
         'deleteAssets', 'deleteAssetsReady', 'deleteCodes', 'deleteAuditKept',
         'deletePwdPlaceholder', 'deleteConfirm', 'deletePwdEmpty', 'deleteDone',
         'deleteFailed', 'deleteBlocked', 'deleteLoading'].forEach(function (k) {
            var attr = 'data-' + k.replace(/[A-Z]/g, function (m) { return '-' + m.toLowerCase(); });
            T[k] = el.getAttribute(attr) || '';
        });

        // 自检：任何文案为空都说明键名写错了，直接在控制台报出来，
        // 避免出现"按钮是空的但没人发现"这种问题
        var missing = Object.keys(T).filter(function (k) { return !T[k]; });
        if (missing.length) {
            console.error('[admin-users] 以下 i18n 键未取到文案，请检查 users.html 的 data-* 定义：',
                missing.map(function (k) {
                    return 'data-' + k.replace(/[A-Z]/g, function (m) { return '-' + m.toLowerCase(); });
                }));
        }
    })();

    var page = 0, size = 20, total = 0, currentUser = null;

    function api(path, options) {
        return fetch(path, Object.assign({
            headers: { 'Content-Type': 'application/json' },
            credentials: 'same-origin'
        }, options || {})).then(function (res) {
            return res.json().catch(function () {
                return { code: res.status, message: 'HTTP ' + res.status };
            }).then(function (json) {
                if (json.code !== 200) throw new Error(json.message || ('HTTP ' + res.status));
                return json.data;
            });
        });
    }

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function fmt(tpl, val) {
        return String(tpl || '').replace('{0}', val);
    }

    function fmtTime(t) {
        return t ? String(t).replace('T', ' ').slice(0, 16) : '—';
    }

    function roleLabel(role) {
        if (role === 'ADMIN') return T.roleAdmin;
        if (role === 'EXPERT') return T.roleExpert;
        if (role === 'TECHNICIAN') return T.roleTechnician;
        return T.roleFarmer;
    }

    function loadStats() {
        api('/api/v1/admin/users/stats').then(function (s) {
            var r = s.by_role || {};
            document.getElementById('stats').innerHTML =
                '<div>' + esc(T.total) + '<b>' + s.total + '</b></div>' +
                '<div>' + esc(T.roleFarmer) + '<b>' + (r.FARMER || 0) + '</b></div>' +
                '<div>' + esc(T.roleTechnician) + '<b>' + (r.TECHNICIAN || 0) + '</b></div>' +
                '<div>' + esc(T.roleExpert) + '<b>' + (r.EXPERT || 0) + '</b></div>' +
                '<div>' + esc(T.roleAdmin) + '<b>' + (r.ADMIN || 0) + '</b></div>';
        }).catch(function (e) {
            document.getElementById('stats').innerHTML = '<div>' + esc(e.message) + '</div>';
        });
    }

    function load() {
        var kw = document.getElementById('q-keyword').value.trim();
        var role = document.getElementById('q-role').value;
        var qs = new URLSearchParams({ page: page, size: size });
        if (kw) qs.set('keyword', kw);
        if (role) qs.set('role', role);

        api('/api/v1/admin/users?' + qs.toString()).then(function (d) {
            total = d.total;
            var rows = d.items || [];
            document.getElementById('rows').innerHTML = rows.length ? rows.map(function (u) {
                var role = esc(u.role);
                // 带区号展示手机号，便于区分不同国家的用户
                var phone = u.country_code
                    ? ('+' + esc(u.country_code) + ' ' + esc(u.phone))
                    : esc(u.phone);
                return '<tr>' +
                    '<td>' + u.id + '</td>' +
                    '<td>' + phone + '</td>' +
                    '<td>' + esc(u.nickname) + '</td>' +
                    '<td><span class="role-tag role-' + role + '">' + esc(roleLabel(u.role)) + '</span></td>' +
                    // 状态列：正常 / 已停用（早期这里把 class 和文案拼成了一个字符串，导致显示空白）
                    '<td class="' + (u.is_active ? 'state-on' : 'state-off') + '">' +
                    esc(u.is_active ? T.enabled : T.disabled) + '</td>' +
                    '<td>' + fmtTime(u.last_login_at) + '</td>' +
                    '<td>' + (u.login_count || 0) + '</td>' +
                    // 操作列走事件委托（data-act / data-id），不用内联 onclick ——
                    // 内联写法在字符串拼接 + IIFE 作用域下容易把 id 传成字符串 "null"
                    '<td class="row-actions">' +
                    '<button data-act="toggle" data-id="' + u.id + '">' +
                    esc(u.is_active ? T.disable : T.enable) + '</button>' +
                    '<button data-act="role" data-id="' + u.id + '" data-role="' + role +
                    '" data-name="' + esc(u.nickname) + '">' +
                    esc(T.changeRole) + '</button>' +
                    '<button data-act="pwd" data-id="' + u.id + '">' + esc(T.resetPassword) + '</button>' +
                    '<button data-act="reveal" data-id="' + u.id + '" data-name="' + esc(u.nickname) + '">' +
                    esc(T.revealPhone) + '</button>' +
                    // 删除按钮用红色区分：不可恢复操作不能和普通按钮长得一样
                    '<button class="danger" data-act="delete" data-id="' + u.id +
                    '" data-name="' + esc(u.nickname) + '">' + esc(T.delete) + '</button>' +
                    '</td></tr>';
            }).join('') : '<tr><td colspan="8" style="text-align:center;color:#999;">' + esc(T.noData) + '</td></tr>';
            document.getElementById('pageInfo').textContent = fmt(T.page, page + 1);
            document.getElementById('totalInfo').textContent = fmt(T.totalCount, total);
        }).catch(function (e) {
            document.getElementById('rows').innerHTML =
                '<tr><td colspan="8" style="text-align:center;color:#c62828;">' + esc(e.message) + '</td></tr>';
        });
    }

    function search() { page = 0; load(); }
    function resetSearch() {
        document.getElementById('q-keyword').value = '';
        document.getElementById('q-role').value = '';
        page = 0;
        load();
    }
    function prevPage() { if (page > 0) { page--; load(); } }
    function nextPage() { if ((page + 1) * size < total) { page++; load(); } }

    function toggleUser(id) {
        var row = null;
        api('/api/v1/admin/users/' + id).then(function (u) {
            row = u;
            var msg = u.is_active ? T.disableConfirm : T.enableConfirm;
            if (!confirm(msg)) return null;
            return api('/api/v1/admin/users/' + id + '/toggle', { method: 'POST', body: '{}' })
                .then(function (r) {
                    alert(r.message || T.toggleDone);
                    load();
                    loadStats();
                });
        }).catch(function (e) { alert(T.failed + ': ' + e.message); });
    }

    function openPwd(id) {
        currentUser = id;
        document.getElementById('pwdUser').textContent = T.resetPwdUser + ' ' + id;
        document.getElementById('pwdNew').value = '';
        document.getElementById('pwdMask').style.display = 'flex';
    }
    function closePwd() { document.getElementById('pwdMask').style.display = 'none'; }

    function doResetPwd() {
        var pwd = document.getElementById('pwdNew').value;
        if (pwd.length < 6) { alert(T.resetPwdTooShort); return; }
        api('/api/v1/admin/users/' + currentUser + '/reset-password',
            { method: 'POST', body: JSON.stringify({ newPassword: pwd }) })
            .then(function (r) {
                alert(r.message || T.resetPwdDone);
                closePwd();
                load();
            })
            .catch(function (e) { alert(T.failed + ': ' + e.message); });
    }

    /**
     * 打开改角色弹窗
     *
     * @param id         目标用户 ID
     * @param role       该用户当前角色 —— 预选上，避免管理员"手滑改成别的角色"
     * @param nickname   昵称，显示出来避免改错人
     */
    function openRole(id, role, nickname) {
        currentUser = id;
        document.getElementById('roleUser').textContent = 'ID: ' + id +
            (nickname ? '（' + nickname + '）' : '') +
            (role ? ' · ' + T.roleCurrent + ' ' + roleLabel(role) : '');
        var sel = document.getElementById('roleNew');
        if (role) sel.value = role;
        // 每次打开都清空密码与上一次的错误提示
        document.getElementById('rolePwd').value = '';
        var res = document.getElementById('roleResult');
        res.style.display = 'none';
        res.textContent = '';
        showRoleDetail();
        document.getElementById('roleMask').style.display = 'flex';
    }
    function closeRole() { document.getElementById('roleMask').style.display = 'none'; }

    /**
     * 显示当前选中角色的权限明细（可以做 / 不可以做）
     *
     * 明细由服务端按 Permission 矩阵渲染，这里只切换显示哪一块 ——
     * 保证界面说明与后端真实拦截规则永远一致。
     */
    function showRoleDetail() {
        var role = document.getElementById('roleNew').value;
        var blocks = document.querySelectorAll('#roleDetail .role-detail');
        for (var i = 0; i < blocks.length; i++) {
            blocks[i].style.display = blocks[i].getAttribute('data-role') === role ? 'block' : 'none';
        }
    }

    /**
     * 提交改角色
     *
     * 必须带管理员自己的登录密码：改角色等于"授权"，只靠"已登录"不够
     * （管理员离开座位时浏览器可能还开着）。后端会校验，密码错一律拒绝并写审计。
     */
    function doChangeRole() {
        var role = document.getElementById('roleNew').value;
        var pwd = document.getElementById('rolePwd').value;
        var resultEl = document.getElementById('roleResult');
        if (!pwd) {
            resultEl.style.display = 'block';
            resultEl.style.color = '#B71C1C';
            resultEl.textContent = T.rolePasswordEmpty;
            return;
        }
        api('/api/v1/admin/users/' + currentUser + '/role',
            { method: 'POST', body: JSON.stringify({ role: role, password: pwd }) })
            .then(function (r) {
                alert(r.message || T.roleDone);
                closeRole();
                load();
                loadStats();
            })
            .catch(function (e) {
                resultEl.style.display = 'block';
                resultEl.style.color = '#B71C1C';
                resultEl.textContent = e.message;
            })
            .then(function () {
                document.getElementById('rolePwd').value = '';
            });
    }

    // ==================== 查看完整手机号（二次验证 + 审计）====================

    var revealTargetId = null;

    function openReveal(id, nickname) {
        revealTargetId = id;
        document.getElementById('revealUser').textContent = T.revealUser + ' ' + id +
            (nickname ? '（' + nickname + '）' : '');
        document.getElementById('revealPwd').value = '';
        document.getElementById('revealResult').style.display = 'none';
        document.getElementById('revealBtn').disabled = false;
        document.getElementById('revealMask').style.display = 'flex';
        setTimeout(function () { document.getElementById('revealPwd').focus(); }, 100);
    }

    function closeReveal() {
        document.getElementById('revealMask').style.display = 'none';
        revealTargetId = null;
    }

    /**
     * 提交二次验证密码并显示完整手机号
     *
     * 安全说明：密码错误时后端一律拒绝，且失败尝试也会写入审计日志，
     * 便于发现"有人反复试探管理员密码"这类异常。
     */
    function doReveal() {
        var pwd = document.getElementById('revealPwd').value;
        var resultEl = document.getElementById('revealResult');
        if (!pwd) {
            resultEl.style.display = 'block';
            resultEl.style.background = '#FFEBEE';
            resultEl.style.borderColor = '#EF9A9A';
            resultEl.style.color = '#B71C1C';
            resultEl.textContent = T.revealPwdEmpty;
            return;
        }

        var btn = document.getElementById('revealBtn');
        btn.disabled = true;
        btn.textContent = T.loading;

        api('/api/v1/admin/users/' + revealTargetId + '/reveal-phone',
            { method: 'POST', body: JSON.stringify({ password: pwd }) })
            .then(function (d) {
                resultEl.style.display = 'block';
                resultEl.style.background = '#E8F5E9';
                resultEl.style.borderColor = '#A5D6A7';
                resultEl.style.color = '#1B5E20';
                resultEl.textContent = d.phone_full || d.phone_raw || '';
            })
            .catch(function (e) {
                resultEl.style.display = 'block';
                resultEl.style.background = '#FFEBEE';
                resultEl.style.borderColor = '#EF9A9A';
                resultEl.style.color = '#B71C1C';
                resultEl.textContent = T.revealFailed + '：' + e.message;
            })
            .then(function () {
                btn.disabled = false;
                btn.textContent = T.revealSubmit;
                document.getElementById('revealPwd').value = '';
            });
    }

    // ==================== 删除用户（不可恢复 / 二次验证 / 预览影响范围）====================

    var deleteTargetId = null;

    /**
     * 打开删除弹窗：先拉"删除影响预览"
     *
     * 界面上必须把「删什么」和「留什么」分开写清楚：
     * 管理员最担心的是"删了这个人会不会把平台的数据资产也删掉"，
     * 所以保留项单独用绿色区块展示，且写明是匿名保留。
     */
    function openDelete(id, nickname) {
        deleteTargetId = id;
        document.getElementById('delUser').textContent =
            (T.deleteUser || '') + ' ' + id + (nickname ? '（' + nickname + '）' : '');
        document.getElementById('delPwd').value = '';
        document.getElementById('delPreview').textContent = T.deleteLoading || '...';
        document.getElementById('delKeep').textContent = T.deleteLoading || '...';
        document.getElementById('delBlocked').style.display = 'none';
        document.getElementById('delResult').style.display = 'none';
        document.getElementById('delBtn').disabled = false;
        document.getElementById('delBtn').textContent = T.deleteConfirm;
        document.getElementById('delMask').style.display = 'flex';

        api('/api/v1/admin/users/' + id + '/delete-preview').then(function (p) {
            // 删：只有账号本身与该号码的验证码记录
            var del = [
                '• ' + T.deleteAccount,
                '• ' + T.deleteCodes + '：' + p.verification_codes
            ];
            document.getElementById('delPreview').innerHTML =
                del.map(function (l) { return esc(l); }).join('<br>');

            // 留：平台数据资产，明细列出条数，让管理员点确认时心里有数
            var keep = [
                '• ' + T.deleteDiag + '：' + p.diagnoses_kept,
                '• ' + T.deleteImages + '：' + p.images_kept,
                '• ' + T.deleteAssets + '：' + p.training_assets_kept +
                    (p.training_ready_kept > 0
                        ? '（' + T.deleteAssetsReady + ' ' + p.training_ready_kept + '）' : ''),
                '• ' + T.deleteAuditKept
            ];
            document.getElementById('delKeep').innerHTML =
                keep.map(function (l) { return esc(l); }).join('<br>');

            // 不允许删除的情形（删自己 / 最后一个管理员）→ 直接禁用按钮并说明原因
            if (p.deletable === false) {
                var box = document.getElementById('delBlocked');
                box.style.display = 'block';
                box.textContent = (T.deleteBlocked || '') + '：' + (p.blockers || []).join('；');
                document.getElementById('delBtn').disabled = true;
            } else {
                setTimeout(function () { document.getElementById('delPwd').focus(); }, 100);
            }
        }).catch(function (e) {
            document.getElementById('delPreview').textContent = e.message;
            document.getElementById('delKeep').textContent = '';
            document.getElementById('delBtn').disabled = true;
        });
    }

    function closeDelete() {
        document.getElementById('delMask').style.display = 'none';
        deleteTargetId = null;
    }

    function doDelete() {
        var pwd = document.getElementById('delPwd').value;
        var resultEl = document.getElementById('delResult');
        if (!pwd) {
            resultEl.style.display = 'block';
            resultEl.style.color = '#B71C1C';
            resultEl.textContent = T.deletePwdEmpty;
            return;
        }
        var btn = document.getElementById('delBtn');
        btn.disabled = true;
        btn.textContent = T.deleteLoading;

        api('/api/v1/admin/users/' + deleteTargetId + '/delete',
            { method: 'POST', body: JSON.stringify({ password: pwd }) })
            .then(function (r) {
                alert(r.message || T.deleteDone);
                closeDelete();
                load();
                loadStats();
            })
            .catch(function (e) {
                resultEl.style.display = 'block';
                resultEl.style.color = '#B71C1C';
                resultEl.textContent = T.deleteFailed + '：' + e.message;
            })
            .then(function () {
                btn.disabled = false;
                btn.textContent = T.deleteConfirm;
                document.getElementById('delPwd').value = '';
            });
    }

    // ==================== 操作列事件委托 ====================
    // 表格内容每次重建，用委托绑定在容器上，避免给每个按钮挂 onclick
    (function bindRowActions() {
        var tbody = document.getElementById('rows');
        if (!tbody) return;
        tbody.addEventListener('click', function (e) {
            var btn = e.target.closest ? e.target.closest('button[data-act]') : null;
            if (!btn) return;
            var id = parseInt(btn.getAttribute('data-id'), 10);
            if (!id || isNaN(id)) {
                console.error('[admin-users] 按钮缺少有效 data-id:', btn.outerHTML.slice(0, 120));
                return;
            }
            switch (btn.getAttribute('data-act')) {
                case 'toggle': toggleUser(id); break;
                case 'role': openRole(id, btn.getAttribute('data-role') || '', btn.getAttribute('data-name') || ''); break;
                case 'pwd': openPwd(id); break;
                case 'reveal': openReveal(id, btn.getAttribute('data-name') || ''); break;
                case 'delete': openDelete(id, btn.getAttribute('data-name') || ''); break;
            }
        });
    })();

    // 暴露给 HTML 里的 onclick（弹窗内按钮）
    window.search = search;
    window.resetSearch = resetSearch;
    window.prevPage = prevPage;
    window.nextPage = nextPage;
    window.toggleUser = toggleUser;
    window.openPwd = openPwd;
    window.closePwd = closePwd;
    window.doResetPwd = doResetPwd;
    window.openRole = openRole;
    window.closeRole = closeRole;
    window.showRoleDetail = showRoleDetail;
    window.doChangeRole = doChangeRole;
    window.openReveal = openReveal;
    window.closeReveal = closeReveal;
    window.doReveal = doReveal;
    window.openDelete = openDelete;
    window.closeDelete = closeDelete;
    window.doDelete = doDelete;

    loadStats();
    load();
})();
