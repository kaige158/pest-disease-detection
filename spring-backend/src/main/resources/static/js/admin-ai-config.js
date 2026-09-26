// AI 配置中心交互 —— 文案全部从页面 #i18n 的 data-* 读取（服务端按当前语言渲染）
// 这样切语言只需要改 messages_*.properties，不需要动 JS。
(function () {
    'use strict';

    var T = {};
    (function loadI18n() {
        var el = document.getElementById('i18n');
        if (!el) return;
        ['newTitle', 'editPrefix', 'badgeNone', 'badgeConfigured', 'badgeActive', 'badgeOk',
         'badgeFail', 'keyNone', 'keyCurrent', 'keyKeep', 'keyNew', 'confirmActivate',
         'confirmDelete', 'testing', 'saveOk', 'activateOk', 'noChannel', 'noActive',
         'activeLine', 'configured', 'notConfigured'].forEach(function (k) {
            var attr = 'data-' + k.replace(/[A-Z]/g, function (m) { return '-' + m.toLowerCase(); });
            T[k] = el.getAttribute(attr) || '';
        });
    })();

    var channels = [];
    var providers = [];
    var selectedId = null;
    /** 是否正在新增（true 时禁止异步回调覆盖表单） */
    var editingNew = false;

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

    /** 加载可选通道类型（后端下发，新增厂商无需改前端） */
    function loadProviders() {
        return api('/api/v1/admin/ai/providers').then(function (list) {
            providers = list || [];
            var sel = document.getElementById('f-provider');
            sel.innerHTML = providers.map(function (p) {
                return '<option value="' + esc(p.value) + '">' + esc(p.label) + '</option>';
            }).join('');
            // 选项就绪后重新同步一次说明与预设：
            // 否则用户点「新增」时若接口还没返回，预设会完全填不上
            onProviderChange();
        }).catch(function () { /* 下拉为空时保持模板里的保底选项 */ });
    }

    function currentProvider() {
        var v = document.getElementById('f-provider').value;
        return providers.filter(function (p) { return p.value === v; })[0] || null;
    }

    /** 记住上一个厂商，用于判断"模型名是自动填的还是用户手填的" */
    var lastProvider = '';
    /** 上一次预填进去的模型名 —— 若当前值仍是它，说明用户没改过，可以安全替换 */
    var lastPresetModel = '';

    /**
     * 切换通道类型时：更新说明文字，并用厂商预设预填地址 / 模型。
     *
     * 取值规则（避免出现"选 DeepSeek 却留着 gpt-4o"这类错误配置）：
     *   · 地址：用该厂商预设覆盖（除非用户自己改过，即当前值不等于任何已知预设）
     *   · 模型：只在"当前值是上一个厂商的预设值"或为空时才替换，
     *          用户手填过的模型不会被覆盖
     */
    function onProviderChange() {
        var sel = document.getElementById('f-provider').value;
        var p = providers.filter(function (x) { return x.value === sel; })[0] || null;

        // 说明文字优先用接口返回的 note；providers 还没加载时至少把选中值记为已知
        document.getElementById('providerNote').textContent = p ? (p.note || '') : '';

        var preset = (p && p.preset) || {};
        var baseUrlEl = document.getElementById('f-baseUrl');
        var modelEl = document.getElementById('f-model');

        if (p) {
            if (preset.baseUrl) {
                var knownPresets = providers.map(function (x) {
                    return ((x.preset || {}).baseUrl) || '';
                }).filter(Boolean);
                var cur = baseUrlEl.value.trim();
                // 空值，或当前值就是某个厂商的预设 → 直接换成目标厂商的
                if (!cur || knownPresets.indexOf(cur) >= 0) {
                    baseUrlEl.value = preset.baseUrl;
                }
            }
            if (preset.model) {
                var curModel = modelEl.value.trim();
                if (!curModel || curModel === lastPresetModel) {
                    modelEl.value = preset.model;
                }
                lastPresetModel = preset.model;
            }
            lastProvider = sel;
        }
    }

    function loadChannels() {
        return api('/api/v1/admin/ai/configs').then(function (data) {
            channels = data || [];
            var box = document.getElementById('channelList');
            if (!channels.length) {
                box.innerHTML = '<div style="color:#999;font-size:13px;">' + esc(T.noChannel) + '</div>';
                return;
            }
            box.innerHTML = channels.map(function (c) {
                var badge = '<span class="badge badge-none">' + esc(T.badgeNone) + '</span>';
                if (c.active) badge = '<span class="badge badge-active">' + esc(T.badgeActive) + '</span>';
                else if (c.lastTestOk === true) badge = '<span class="badge badge-ok">' + esc(T.badgeOk) + '</span>';
                else if (c.lastTestOk === false) badge = '<span class="badge badge-fail">' + esc(T.badgeFail) + '</span>';
                else if (c.hasApiKey) badge = '<span class="badge badge-none">' + esc(T.badgeConfigured) + '</span>';
                return '<div class="channel' + (c.id === selectedId ? ' selected' : '') + '" onclick="selectChannel(' + c.id + ')">' +
                    '<div style="flex:1;min-width:0;">' +
                    '<div class="name">' + esc(c.displayName || c.provider) + '</div>' +
                    '<div class="meta">' + esc(c.provider) + ' · ' + esc(c.model || '') +
                    (c.apiKeyMasked ? ' · ' + esc(c.apiKeyMasked) : '') + '</div>' +
                    '</div>' + badge + '</div>';
            }).join('');
        }).catch(function (e) {
            document.getElementById('channelList').innerHTML =
                '<div style="color:#c62828;font-size:13px;">' + esc(e.message) + '</div>';
        });
    }

    function selectChannel(id) {
        var c = channels.filter(function (x) { return x.id === id; })[0];
        if (!c) return;
        // 用户正在填新增表单时，不要被自动选中逻辑打断
        if (editingNew) return;
        selectedId = id;
        document.getElementById('editor').style.display = 'block';
        document.getElementById('editorTitle').textContent = T.editPrefix + ' ' + (c.displayName || c.provider);
        document.getElementById('f-provider').value = c.provider;
        document.getElementById('f-displayName').value = c.displayName || '';
        document.getElementById('f-apiKey').value = '';
        document.getElementById('f-model').value = c.model || '';
        document.getElementById('f-baseUrl').value = c.baseUrl || '';
        document.getElementById('f-maxTokens').value = c.maxTokens || 2000;
        document.getElementById('f-temperature').value = c.temperature != null ? c.temperature : 0.3;
        document.getElementById('f-remark').value = c.remark || '';
        document.getElementById('keyHint').textContent = c.hasApiKey
            ? (T.keyCurrent + ' ' + c.apiKeyMasked + ' ' + T.keyKeep)
            : T.keyNone;
        document.getElementById('btnActivate').style.display = c.active ? 'none' : 'inline-block';
        document.getElementById('btnDelete').style.display = c.active ? 'none' : 'inline-block';
        document.getElementById('testResult').style.display = 'none';
        onProviderChange();   // 同步厂商说明文字
        loadChannels();
    }

    function newChannel() {
        selectedId = null;
        // 标记"正在新增"：避免首页自动选中生效通道的回调异步跑回来后
        // 把用户正在填的新增表单覆盖掉（这个竞态会导致模型名被写成上一个通道的值）
        editingNew = true;
        // 新增是全新开始：清掉"上一个厂商预设值"的标记，
        // 否则 onProviderChange 会误判成"用户手填过"而拒绝预填模型
        lastPresetModel = '';
        lastProvider = '';
        document.getElementById('editor').style.display = 'block';
        document.getElementById('editorTitle').textContent = T.newTitle;
        document.getElementById('f-provider').value = 'gemini';
        document.getElementById('f-displayName').value = '';
        document.getElementById('f-apiKey').value = '';
        document.getElementById('f-model').value = '';
        document.getElementById('f-baseUrl').value = '';
        document.getElementById('f-maxTokens').value = 2000;
        document.getElementById('f-temperature').value = 0.3;
        document.getElementById('f-remark').value = '';
        document.getElementById('keyHint').textContent = T.keyNew;
        document.getElementById('btnActivate').style.display = 'none';
        document.getElementById('btnDelete').style.display = 'none';
        document.getElementById('testResult').style.display = 'none';
        onProviderChange();   // 预填该厂商的官方地址与推荐模型
        loadChannels();
    }

    function formBody() {
        return {
            provider: document.getElementById('f-provider').value,
            displayName: document.getElementById('f-displayName').value,
            apiKey: document.getElementById('f-apiKey').value,
            model: document.getElementById('f-model').value,
            baseUrl: document.getElementById('f-baseUrl').value,
            maxTokens: parseInt(document.getElementById('f-maxTokens').value, 10) || 2000,
            temperature: parseFloat(document.getElementById('f-temperature').value),
            remark: document.getElementById('f-remark').value
        };
    }

    function showResult(ok, text) {
        var el = document.getElementById('testResult');
        el.className = 'result-box ' + (ok ? 'result-ok' : 'result-fail');
        el.textContent = text;
        el.style.display = 'block';
    }

    function saveChannel() {
        var body = formBody();
        var req = selectedId
            ? api('/api/v1/admin/ai/configs/' + selectedId, { method: 'PUT', body: JSON.stringify(body) })
            : api('/api/v1/admin/ai/configs', { method: 'POST', body: JSON.stringify(body) });

        req.then(function (saved) {
            selectedId = saved.id;
            editingNew = false;   // 已保存，退出"新增中"状态
            return loadChannels().then(function () {
                selectChannel(saved.id);
                showResult(true, T.saveOk);
            });
        }).catch(function (e) {
            showResult(false, e.message);
        });
    }

    function testDraft() {
        showResult(true, T.testing);
        var body = formBody();
        body.id = selectedId;
        api('/api/v1/admin/ai/test', { method: 'POST', body: JSON.stringify(body) })
            .then(function (r) {
                showResult(!!r.ok, (r.ok ? '✅ ' : '❌ ') + (r.message || '') + ' (' + (r.elapsed_ms || 0) + ' ms)');
                return loadChannels();
            })
            .catch(function (e) { showResult(false, e.message); });
    }

    function activateChannel() {
        if (!selectedId) return;
        if (!confirm(T.confirmActivate)) return;
        api('/api/v1/admin/ai/configs/' + selectedId + '/activate', { method: 'POST', body: '{}' })
            .then(function () {
                return loadChannels().then(function () {
                    selectChannel(selectedId);
                    loadActive();
                    showResult(true, T.activateOk);
                });
            })
            .catch(function (e) { showResult(false, e.message); });
    }

    function deleteChannel() {
        if (!selectedId) return;
        if (!confirm(T.confirmDelete)) return;
        api('/api/v1/admin/ai/configs/' + selectedId, { method: 'DELETE' })
            .then(function () {
                selectedId = null;
                document.getElementById('editor').style.display = 'none';
                document.getElementById('editorTitle').textContent = '';
                return loadChannels();
            })
            .catch(function (e) { showResult(false, e.message); });
    }

    function loadActive() {
        api('/api/v1/admin/ai/active').then(function (a) {
            document.getElementById('activeInfo').innerHTML =
                '<b>' + esc(a.provider) + '</b> · ' + esc(a.model || '') + ' · ' +
                (a.configured ? esc(T.configured) + ' ✅' : esc(T.notConfigured) + ' ⚠️');
        }).catch(function () {
            document.getElementById('activeInfo').textContent = T.noActive;
        });
    }

    // 暴露给 HTML 里的 onclick
    window.newChannel = newChannel;
    // 列表点击属于"显式选择"，应退出新增态
    window.selectChannel = function (id) {
        editingNew = false;
        selectChannel(id);
    };
    window.saveChannel = saveChannel;
    window.testDraft = testDraft;
    window.activateChannel = activateChannel;
    window.deleteChannel = deleteChannel;
    window.onProviderChange = onProviderChange;

    // 先取到通道类型，再渲染表单，避免下拉为空
    loadProviders().then(function () {
        return loadChannels();
    }).then(function () {
        // 首次进入自动展示当前生效通道；但若用户已经点了「新增」则尊重用户操作
        if (editingNew) return;
        var active = channels.filter(function (c) { return c.active; })[0];
        if (active) selectChannel(active.id);
    });
    loadActive();
})();
