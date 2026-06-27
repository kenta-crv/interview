(function() {
  var init = window.MeetiaPageInit;
  if (!init) return;

  function setupDealDashboard(root) {
    init.bindOnce(root, 'data-meetia-bound', function(container) {
      var statusUrl = container.dataset.processingStatusUrl;
      var isProcessing = container.dataset.isProcessing === 'true';
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

      var shareUrlBtn = document.getElementById('share-url-btn');
      var shareUrlModal = document.getElementById('share-url-modal');
      var closeShareModal = document.getElementById('close-share-modal');
      var copyUrlBtn = document.getElementById('copy-url-btn');

      if (shareUrlBtn && shareUrlModal) {
        shareUrlBtn.addEventListener('click', function(e) {
          e.preventDefault();
          shareUrlModal.style.display = 'block';
        });
      }

      if (closeShareModal && shareUrlModal) {
        closeShareModal.addEventListener('click', function() {
          shareUrlModal.style.display = 'none';
        });
      }

      if (copyUrlBtn && shareUrlModal) {
        copyUrlBtn.addEventListener('click', function() {
          var urlInput = shareUrlModal.querySelector('input[type="text"]');
          if (!urlInput) return;
          urlInput.select();
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(urlInput.value).then(function() {
              alert('URLをコピーしました');
            });
          } else {
            document.execCommand('copy');
            alert('URLをコピーしました');
          }
        });
      }

      container._meetiaPollTimer = pollTimer;
    });
  }

  init.onPageReady(function() {
    var root = document.querySelector('[data-deal-dashboard]');
    if (root) setupDealDashboard(root);
  });
})();
