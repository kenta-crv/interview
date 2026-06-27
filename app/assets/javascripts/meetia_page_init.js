// Turbo / DOMContentLoaded 両対応のページ初期化ヘルパー
(function(global) {
  function onPageReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
    document.addEventListener('turbo:load', fn);
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  function bindOnce(root, attr, fn) {
    if (!root || root.getAttribute(attr) === 'true') return;
    root.setAttribute(attr, 'true');
    fn(root);
  }

  function unbind(root, attr) {
    if (root) root.removeAttribute(attr);
  }

  global.MeetiaPageInit = {
    onPageReady: onPageReady,
    csrfToken: csrfToken,
    bindOnce: bindOnce,
    unbind: unbind
  };

  document.addEventListener('turbo:before-cache', function() {
    document.querySelectorAll('[data-meetia-bound]').forEach(function(el) {
      el.removeAttribute('data-meetia-bound');
    });
  });
})(window);
