(function() {
  function i18n(root, key, fallback) {
    if (!root) return fallback;
    var val = root.getAttribute('data-i18n-' + key);
    return val && val.length ? val : fallback;
  }

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
          var uploading = i18n(root, 'uploading', 'Uploading…');
          if (submitButton.tagName === 'INPUT') {
            submitButton.value = uploading;
          } else {
            submitButton.textContent = uploading;
          }
          submitButton.disabled = true;
        }
      });
    }
  }

  function setupDealDashboard(root) {
    if (root.dataset.dealDashboardBound === 'true') return;
    root.dataset.dealDashboardBound = 'true';

    var statusUrl = root.dataset.processingStatusUrl || root.getAttribute('data-processing-status-url');
    // Slim の boolean true は空属性になることがあるため、"false" 以外は処理中とみなす
    var rawProcessing = root.getAttribute('data-is-processing');
    var isProcessing = rawProcessing === 'true' || rawProcessing === '';
    var pollTimer = null;

    function checkProcessingStatus() {
      if (!statusUrl) return;
      fetch(statusUrl, {
        credentials: 'same-origin',
        headers: { Accept: 'application/json' }
      })
        .then(function(r) {
          if (!r.ok) throw new Error('status ' + r.status);
          return r.json();
        })
        .then(function(data) {
          if (!data.processing) {
            if (pollTimer) clearInterval(pollTimer);
            var banner = document.getElementById('processing-message');
            if (banner) {
              banner.textContent = data.failed
                ? i18n(root, 'ai-failed', 'AI processing failed. Reloading…')
                : i18n(root, 'ai-done', 'AI processing complete. Reloading…');
            }
            window.location.reload();
          }
        })
        .catch(function() {});
    }

    if (isProcessing && statusUrl) {
      checkProcessingStatus();
      pollTimer = setInterval(checkProcessingStatus, 3000);
    }

    var shareUrlField = document.getElementById('deal-share-url-field');
    var shareUrlCopyBtn = document.getElementById('deal-share-url-copy');
    var shareUrlOpenBtn = document.getElementById('deal-share-url-open');
    var shareStrip = root.querySelector('.db-v2-share-strip');

    function shareReadyFrom(el) {
      var host = el && (el.closest('[data-share-ready]') || shareStrip);
      return !!(host && host.getAttribute('data-share-ready') === 'true');
    }

    function copyShareUrl(value, triggerEl) {
      if (!shareReadyFrom(triggerEl || shareStrip)) {
        alert(i18n(root, 'copy-after-publish', 'Available after publishing'));
        return;
      }

      var text = value || '';
      if (!text) return;

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function() {
          alert(i18n(root, 'copy-ok', 'URL copied'));
        });
      } else {
        var temp = document.createElement('textarea');
        temp.value = text;
        document.body.appendChild(temp);
        temp.select();
        document.execCommand('copy');
        document.body.removeChild(temp);
        alert(i18n(root, 'copy-ok', 'URL copied'));
      }
    }

    if (shareUrlField) {
      shareUrlField.addEventListener('focus', function() {
        shareUrlField.select();
      });
    }

    if (shareUrlCopyBtn && shareUrlField) {
      shareUrlCopyBtn.addEventListener('click', function() {
        copyShareUrl(shareUrlField.value, shareUrlCopyBtn);
      });
    }

    if (shareUrlOpenBtn) {
      shareUrlOpenBtn.addEventListener('click', function(e) {
        if (!shareReadyFrom(shareUrlOpenBtn)) {
          e.preventDefault();
          alert(i18n(root, 'copy-after-publish', 'Available after publishing'));
        }
      });
    }

    root.querySelectorAll('[data-copy-share-url]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var row = btn.closest('.db-v2-copy-row');
        var input = row ? row.querySelector('input[type="text"]') : null;
        if (!input) return;
        copyShareUrl(input.value, btn);
      });
    });

    root._meetiaPollTimer = pollTimer;

    bindUploadHandlers(root);

    root.querySelectorAll('.btn-ai-rewrite').forEach(function(link) {
      link.addEventListener('click', function() {
        window.setTimeout(function() {
          link.textContent = i18n(root, 'ai-improving', 'AI rewriting…');
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
})();
