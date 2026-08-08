// 农业AI平台 — 专家后台交互脚本

// ===== Toast通知 =====
function showToast(message, type) {
    const toast = document.createElement('div');
    toast.className = 'toast ' + (type || 'success');
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 3000);
}

// ===== AI审核 =====
function quickApprove(id) {
    if (!confirm('确认AI识别结果正确?')) return;
    fetch('/api/v1/admin/review/' + id, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({action: 'verified'})
    })
    .then(r => r.json())
    .then(data => {
        if (data.code === 200) {
            showToast('已确认', 'success');
            setTimeout(() => location.reload(), 500);
        } else {
            showToast(data.message || '操作失败', 'error');
        }
    })
    .catch(() => showToast('网络错误', 'error'));
}

function openReview(id) {
    const notes = prompt('请输入审核备注(可选):');
    if (notes === null) return;
    const action = confirm('AI结果是否正确?\n"确定"=正确, "取消"=需修正')
        ? 'verified' : 'corrected';

    let correctedId = null;
    if (action === 'corrected') {
        correctedId = prompt('请输入正确的病虫害ID:');
        if (!correctedId) return;
    }

    fetch('/api/v1/admin/review/' + id, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            action: action,
            notes: notes,
            corrected_disease_id: correctedId ? parseInt(correctedId) : null
        })
    })
    .then(r => r.json())
    .then(data => {
        if (data.code === 200) {
            showToast('审核完成', 'success');
            setTimeout(() => location.reload(), 500);
        } else {
            showToast(data.message || '操作失败', 'error');
        }
    })
    .catch(() => showToast('网络错误', 'error'));
}

function batchApproveHighConfidence() {
    if (!confirm('一键通过所有置信度≥90%的结果?')) return;
    // 获取页面上所有置信度≥90%的记录
    const rows = document.querySelectorAll('tbody tr');
    let count = 0;
    const promises = [];
    rows.forEach(row => {
        const confCell = row.querySelector('.confidence');
        if (confCell && confCell.classList.contains('high')) {
            // 简单匹配（实际应从data属性获取ID）
            count++;
        }
    });
    showToast('批量确认功能开发中，请逐条审核', 'error');
}

// ===== 知识库管理 =====
function showAddDiseaseForm() {
    document.getElementById('modalTitle').textContent = '新增病虫害';
    document.getElementById('diseaseForm').reset();
    document.getElementById('diseaseId').value = '';
    document.getElementById('diseaseModal').style.display = 'flex';
}

function editDisease(id) {
    fetch('/api/v1/knowledge/diseases/' + id)
        .then(r => r.json())
        .then(data => {
            if (data.code !== 200) { showToast('加载失败', 'error'); return; }
            const d = data.data;
            document.getElementById('modalTitle').textContent = '编辑: ' + d.nameZh;
            document.getElementById('diseaseId').value = d.id;
            document.getElementById('nameZh').value = d.nameZh || '';
            document.getElementById('nameLo').value = d.nameLo || '';
            document.getElementById('scientificName').value = d.scientificName || '';
            document.getElementById('type').value = d.type || 'disease';
            document.getElementById('version').value = d.version || 'vegetable';
            document.getElementById('cropId').value = d.cropId || '';
            document.getElementById('symptomsZh').value = d.symptomsZh || '';
            document.getElementById('symptomsLo').value = d.symptomsLo || '';
            document.getElementById('conditionsZh').value = d.conditionsZh || '';
            document.getElementById('severityLevel').value = d.severityLevel || 'moderate';
            document.getElementById('tags').value = d.tags || '';
            document.getElementById('diseaseModal').style.display = 'flex';
        })
        .catch(() => showToast('网络错误', 'error'));
}

function editPrevention(id) {
    showToast('防控方案编辑功能开发中 — 请通过API接口操作', 'error');
}

function closeModal() {
    document.getElementById('diseaseModal').style.display = 'none';
}

function saveDisease(event) {
    event.preventDefault();
    const id = document.getElementById('diseaseId').value;
    const method = id ? 'PUT' : 'POST';
    const url = id ? '/api/v1/admin/diseases/' + id : '/api/v1/admin/diseases';

    const body = {
        nameZh: document.getElementById('nameZh').value,
        nameLo: document.getElementById('nameLo').value,
        scientificName: document.getElementById('scientificName').value,
        type: document.getElementById('type').value,
        version: document.getElementById('version').value,
        cropId: parseInt(document.getElementById('cropId').value) || null,
        symptomsZh: document.getElementById('symptomsZh').value,
        symptomsLo: document.getElementById('symptomsLo').value,
        conditionsZh: document.getElementById('conditionsZh').value,
        severityLevel: document.getElementById('severityLevel').value,
        tags: document.getElementById('tags').value,
        sourceType: 'TEACHER_DATA',
        approvalStatus: 'approved'
    };

    fetch(url, {
        method: method,
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    })
    .then(r => r.json())
    .then(data => {
        if (data.code === 200) {
            showToast('保存成功', 'success');
            closeModal();
            setTimeout(() => location.reload(), 500);
        } else {
            showToast(data.message || '保存失败', 'error');
        }
    })
    .catch(() => showToast('网络错误', 'error'));
}

function searchDiseases() {
    const q = document.getElementById('searchInput').value;
    const version = document.getElementById('versionFilter').value;
    let url = '/api/v1/knowledge/search?q=' + encodeURIComponent(q || '');
    if (version) url += '&version=' + version;

    fetch(url)
        .then(r => r.json())
        .then(data => {
            if (data.code !== 200) return;
            const tbody = document.getElementById('diseaseTableBody');
            tbody.innerHTML = data.data.map(d => `
                <tr>
                    <td>${d.id}</td>
                    <td style="font-weight:600;">${d.nameZh || '-'}</td>
                    <td style="font-size:12px;color:#666;">${d.nameLo || '-'}</td>
                    <td>${d.cropId || '-'}</td>
                    <td><span class="badge ${d.type === 'disease' ? 'badge-info' : 'badge-warning'}">${d.type === 'disease' ? '病害' : '虫害'}</span></td>
                    <td>${d.version}</td>
                    <td>${d.imageCount || 0}张</td>
                    <td>
                        <button class="btn btn-outline btn-sm" onclick="editDisease(${d.id})">✏️</button>
                        <button class="btn btn-outline btn-sm" onclick="editPrevention(${d.id})">💊</button>
                    </td>
                </tr>
            `).join('');
        });
}
