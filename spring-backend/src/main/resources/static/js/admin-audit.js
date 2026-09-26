// 审计日志页面 —— 只读列表（文案由 #i18n 的 data-* 注入）
(function () {
    'use strict';

    var T = {};
    (function loadI18n() {
        var el = document.getElementById('i18n');
        if (!el) return;
        ['page', 'totalCount', 'noData', 'loading', 'failed'].forEach(function (k) {
            var attr = 'data-' + k.replace(/[A-Z]/g, function (m) { return '-' + m.toLowerCase(); });
            T[k] = el.getAttribute(attr) || '';
        });
        var missing = Object.keys(T).filter(function (k) { return !T[k]; });
        if (missing.length) {
            console.error('[admin-audit] i18n 键未取到文案:', missing);
        }
    })();

    var page = 0, size = 50, total = 0;

    function esc(s) {
        return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function fmt(tpl, val) { return String(tpl || '').replace('{0}', val); }

    /**
     * 操作名归类着色 —— 危险操作要能一眼看见
     * 规则集中在这里，新增操作类型时只加一行
     */
    function actClass(action) {
        if (/DELETE|FAILED|BLOCKED|REVEAL/.test(action)) {
            return /FAILED|BLOCKED/.test(action) ? 'act act-warn' : 'act act-danger';
        }
        return 'act';
    }

    function load() {
        fetch('/api/v1/admin/audit-logs?page=' + page + '&size=' + size,
              { credentials: 'same-origin' })
            .then(function (res) { return res.json(); })
            .then(function (json) {
                if (json.code !== 200) throw new Error(json.message || 'HTTP error');
                var d = json.data || {};
                total = d.total || 0;
                var rows = d.items || [];
                document.getElementById('rows').innerHTML = rows.length ? rows.map(function (a) {
                    return '<tr>' +
                        '<td>' + a.id + '</td>' +
                        '<td>' + esc(String(a.created_at || '').replace('T', ' ').slice(0, 19)) + '</td>' +
                        '<td><span class="' + actClass(String(a.action || '')) + '">' +
                            esc(a.action) + '</span></td>' +
                        '<td>' + esc(a.actor_phone || ('#' + a.actor_id)) + '</td>' +
                        '<td>' + esc(a.target_type) + ' #' + esc(a.target_id) + '</td>' +
                        '<td class="detail">' + esc(a.detail) + '</td>' +
                        '<td>' + esc(a.client_ip) + '</td>' +
                        '</tr>';
                }).join('') : '<tr><td colspan="7" class="empty">' + esc(T.noData) + '</td></tr>';
                document.getElementById('pageInfo').textContent = fmt(T.page, page + 1);
                document.getElementById('totalInfo').textContent = fmt(T.totalCount, total);
            })
            .catch(function (e) {
                document.getElementById('rows').innerHTML =
                    '<tr><td colspan="7" class="empty">' + esc(T.failed + ': ' + e.message) + '</td></tr>';
            });
    }

    window.prevPage = function () { if (page > 0) { page--; load(); } };
    window.nextPage = function () { if ((page + 1) * size < total) { page++; load(); } };

    load();
})();
