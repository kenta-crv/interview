(function() {
  function bindUploadHandlers(root) {
    if (root.dataset.dealUploadBound === 'true') return;
    root.dataset.dealUploadBound = 'true';

    var uploadForm = document.getElementById('documents-upload-form');
    var fileInput = document.getElementById('deal-documents-input') ||
      (uploadForm ? uploadForm.querySelector('input[type="file"]') : null);
    var selectedBox = document.getElementById('deal-documents-selected');
    var fileList = document.getElementById('deal-documents-file-list');
    var errorBox = document.getElementById('deal-documents-error');
    var submitButton = document.getElementById('deal-documents-submit') ||
      (uploadForm ? uploadForm.querySelector('[type="submit"]') : null);

    function renderSelectedFiles() {
      if (!fileInput || !selectedBox || !fileList) return;

      var files = Array.prototype.slice.call(fileInput.files || []);
      fileList.innerHTML = '';

      if (!files.length) {
        selectedBox.hidden = true;
        if (submitButton && !fileInput.disabled) submitButton.disabled = false;
        return;
      }

      files.forEach(function(file) {
        var item = document.createElement('li');
        item.innerHTML = '<i class="fa-solid fa-file-pdf" aria-hidden="true"></i><span></span>';
        item.querySelector('span').textContent = file.name;
        fileList.appendChild(item);
      });

      selectedBox.hidden = false;
      if (errorBox) errorBox.hidden = true;
      if (submitButton && !fileInput.disabled) submitButton.disabled = false;
    }

    var pickButton = document.getElementById('deal-documents-pick');

    if (pickButton && fileInput) {
      pickButton.addEventListener('click', function() {
        if (fileInput.disabled) return;
        fileInput.click();
      });
    }

    if (fileInput) {
      fileInput.addEventListener('change', renderSelectedFiles);
    }

    if (uploadForm) {
      uploadForm.addEventListener('submit', function(e) {
        var files = fileInput ? Array.prototype.slice.call(fileInput.files || []) : [];

        if (!files.length) {
          e.preventDefault();
          if (errorBox) errorBox.hidden = false;
          if (selectedBox) selectedBox.hidden = true;
          return;
        }

        if (errorBox) errorBox.hidden = true;

        if (submitButton) {
          if (submitButton.tagName === 'INPUT') {
            submitButton.value = 'アップロード中...';
          } else {
            submitButton.textContent = 'アップロード中...';
          }
          submitButton.disabled = true;
        }
      });
    }
  }

  function setupDealDashboard(root) {
    if (root.dataset.dealDashboardBound === 'true') return;
    root.dataset.dealDashboardBound = 'true';

    var statusUrl = root.dataset.processingStatusUrl;
    var isProcessing = root.dataset.isProcessing === 'true';
    var pollTimer = null;

    if (isProcessing && statusUrl) {
      pollTimer = setInterval(function() {
        fetch(statusUrl, {
          credentials: 'same-origin',
          headers: { Accept: 'application/json' }
        })
          .then(function(r) { return r.json(); })
          .then(function(data) {
            if (!data.processing) {
              clearInterval(pollTimer);
              window.location.reload();
            }
          })
          .catch(function() {});
      }, 5000);
    }

    var shareUrlField = document.getElementById('deal-share-url-field');
    var shareUrlCopyBtn = document.getElementById('deal-share-url-copy');

    function copyShareUrl(value) {
      var text = value || '';
      if (!text) return;

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() {
          alert('URLをコピーしました');
        });
      } else {
        var temp = document.createElement('textarea');
        temp.value = text;
        document.body.appendChild(temp);
        temp.select();
        document.execCommand('copy');
        document.body.removeChild(temp);
        alert('URLをコピーしました');
      }
    }

    if (shareUrlField) {
      shareUrlField.addEventListener('focus', function() {
        shareUrlField.select();
      });
    }

    if (shareUrlCopyBtn && shareUrlField) {
      shareUrlCopyBtn.addEventListener('click', function() {
        copyShareUrl(shareUrlField.value);
      });
    }

    root.querySelectorAll('[data-copy-share-url]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var row = btn.closest('.db-v2-copy-row');
        var input = row ? row.querySelector('input[type="text"]') : null;
        if (!input) return;
        copyShareUrl(input.value);
      });
    });

    root._meetiaPollTimer = pollTimer;

    bindUploadHandlers(root);

    root.querySelectorAll('.btn-ai-rewrite').forEach(function(link) {
      link.addEventListener('click', function() {
        window.setTimeout(function() {
          link.textContent = 'AI改善中...';
          link.classList.add('is-disabled');
          link.style.pointerEvents = 'none';
        }, 0);
      });
    });
  }

  function onReady() {
    var root = document.querySelector('[data-deal-dashboard]');
    if (root) setupDealDashboard(root);
  }

  if (window.MeetiaPageInit && window.MeetiaPageInit.onPageReady) {
    window.MeetiaPageInit.onPageReady(onReady);
  } else {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', onReady);
    } else {
      onReady();
    }
    document.addEventListener('turbo:load', onReady);
    document.addEventListener('turbolinks:load', onReady);
  }

  document.addEventListener('turbo:before-cache', function() {
    document.querySelectorAll('[data-deal-dashboard]').forEach(function(root) {
      root.removeAttribute('data-deal-dashboard-bound');
      root.removeAttribute('data-deal-upload-bound');
    });
  });
})();
