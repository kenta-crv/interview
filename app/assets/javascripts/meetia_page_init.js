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

  function initPricingSlider() {
    document.querySelectorAll('.meetia-pricing__slider').forEach(function(slider) {
      MeetiaPageInit.bindOnce(slider, 'data-pricing-bound', function(root) {
        var track = root.querySelector('.meetia-pricing__track');
        var prev = root.querySelector('.meetia-pricing__arrow--prev');
        var next = root.querySelector('.meetia-pricing__arrow--next');
        if (!track || !prev || !next) return;

        function scrollStep() {
          var card = track.querySelector('.meetia-pricing__card');
          return card ? card.offsetWidth + 14 : 294;
        }

        function updateArrows() {
          var maxScroll = track.scrollWidth - track.clientWidth;
          prev.classList.toggle('is-hidden', maxScroll <= 0 || track.scrollLeft <= 4);
          next.classList.toggle('is-hidden', maxScroll <= 0 || track.scrollLeft >= maxScroll - 4);
        }

        prev.addEventListener('click', function() {
          track.scrollBy({ left: -scrollStep(), behavior: 'smooth' });
        });
        next.addEventListener('click', function() {
          track.scrollBy({ left: scrollStep(), behavior: 'smooth' });
        });
        track.addEventListener('scroll', updateArrows, { passive: true });
        window.addEventListener('resize', updateArrows);
        updateArrows();
      });
    });
  }

  MeetiaPageInit.onPageReady(initPricingSlider);
})(window);
