const fileInput = document.getElementById('fileInput');
const uploadArea = document.getElementById('uploadArea');
const statusDiv = document.getElementById('status');
const previewImg = document.getElementById('preview');
const previewContainer = document.getElementById('previewContainer');
const fileInfo = document.getElementById('fileInfo');
const uploadBtn = document.getElementById('uploadBtn');

// Drag & Drop effects
['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
    uploadArea.addEventListener(eventName, preventDefaults, false);
});

function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

['dragenter', 'dragover'].forEach(eventName => {
    uploadArea.addEventListener(eventName, highlight, false);
});

['dragleave', 'drop'].forEach(eventName => {
    uploadArea.addEventListener(eventName, unhighlight, false);
});

function highlight() {
    uploadArea.classList.add('dragover');
}

function unhighlight() {
    uploadArea.classList.remove('dragover');
}

uploadArea.addEventListener('drop', handleDrop, false);
fileInput.addEventListener('change', handleFiles, false);

function handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;
    fileInput.files = files; // Sync with input
    handleFiles();
}

function handleFiles() {
    const file = fileInput.files[0];
    if (file) {
        fileInfo.textContent = `선택된 파일: ${file.name} (${formatBytes(file.size)})`;
        statusDiv.className = '';
        statusDiv.textContent = '';
        uploadBtn.disabled = false;

        // Preview if image
        if (file.type.startsWith('image/')) {
            const reader = new FileReader();
            reader.onload = (e) => {
                previewImg.src = e.target.result;
                previewContainer.style.display = 'block';
            };
            reader.readAsDataURL(file);
        } else {
            previewContainer.style.display = 'none';
        }
    }
}

async function uploadFile() {
    if (fileInput.files.length === 0) {
        alert('파일을 선택해주세요.');
        return;
    }

    const file = fileInput.files[0];

    setLoading(true, '1. Presigned URL 요청 중...');

    try {
        // 1. Request Presigned URL
        const presignRes = await fetch('/presign', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                filename: file.name,
                content_type: file.type
            })
        });

        if (!presignRes.ok) throw new Error(`Presign URL 발급 실패 (${presignRes.status})`);
        const { presigned_url, key } = await presignRes.json();

        // 2. Upload to S3
        setLoading(true, '2. S3로 파일 업로드 중...');

        const uploadRes = await fetch(presigned_url, {
            method: 'PUT',
            headers: { 'Content-Type': file.type },
            body: file
        });

        if (!uploadRes.ok) throw new Error('S3 업로드 실패');

        setStatus('업로드 성공! 🎉', 'success');

        // Pure URL for display (removing query params)
        const pureUrl = presigned_url.split('?')[0];
        statusDiv.innerHTML += `<br><a href="${pureUrl}" target="_blank" style="color:var(--primary-color);text-decoration:none;font-size:0.8rem">파일 보기 ↗</a>`;

    } catch (error) {
        console.error(error);
        setStatus(`에러 발생: ${error.message}`, 'error');
    } finally {
        setLoading(false);
    }
}

function setLoading(isLoading, msg = '') {
    uploadBtn.disabled = isLoading;
    uploadBtn.textContent = isLoading ? '처리 중...' : '업로드';
    if (isLoading) {
        setStatus(msg, 'loading');
    }
}

function setStatus(msg, type) {
    statusDiv.textContent = msg;
    statusDiv.className = type;
}

function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}
