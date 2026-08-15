const FINISHED_STATUSES = ['success', 'failure', 'cancel'];

const STATUS_ICONS = {
  success: 'fa fa-check-circle',
  initial: 'fa fa-spinner fa-spin',
  provisioning: 'fa fa-spinner fa-spin',
  deploying: 'fa fa-spinner fa-spin',
  reserved_cancel: 'fa fa-spinner fa-spin',
  failure: 'fa fa-exclamation-triangle',
  cancel: 'fa fa-times-circle',
};

document.addEventListener('DOMContentLoaded', () => {
  const root = document.querySelector('[data-deploy-job-id]');
  if (!root) return;

  const deployJobId = root.dataset.deployJobId;
  if (FINISHED_STATUSES.includes(root.dataset.status)) return;

  const logsEl = document.querySelector('.logs');
  const statusEl = document.getElementById('deploy-status');

  const appendLog = (line) => {
    if (!logsEl) return;
    const placeholder = logsEl.querySelector('[data-logs-placeholder]');
    if (placeholder) placeholder.remove();

    // Only auto-scroll when the user is already near the bottom, so scrolling
    // up to read earlier output during streaming is not interrupted.
    const nearBottom = window.innerHeight + window.scrollY >= document.body.scrollHeight - 100;

    const pre = document.createElement('pre');
    pre.textContent = line;
    logsEl.appendChild(pre);

    if (nearBottom) window.scrollTo(0, document.body.scrollHeight);
  };

  const updateStatus = (status) => {
    if (!statusEl) return;
    statusEl.innerHTML = `<i class="${STATUS_ICONS[status] || ''}"></i> ${status}`;
  };

  // The page already rendered the existing log lines server-side; resume from
  // there so we only append new ones.
  const offset = logsEl ? logsEl.querySelectorAll('pre').length : 0;
  const source = new EventSource(`/deploy_jobs/${deployJobId}/stream?offset=${offset}`);

  source.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'log') {
      appendLog(data.line);
    } else if (data.type === 'status') {
      updateStatus(data.status);
      if (data.finished) {
        source.close();
        // Reload once to render server-side final metadata (task ARNs,
        // execution time, git tag) that is not streamed incrementally.
        setTimeout(() => window.location.reload(), 800);
      }
    }
  };
});
