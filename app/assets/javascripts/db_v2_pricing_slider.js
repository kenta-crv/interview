(function() {
  function teardownDbV2PricingSlider(root) {
    if (!root) return;
    if (root._pricingResizeObserver) {
      root._pricingResizeObserver.disconnect();
      root._pricingResizeObserver = null;
    }
    if (typeof root._pricingCleanup === 'function') {
      root._pricingCleanup();
      root._pricingCleanup = null;
    }
    root.removeAttribute('data-pricing-ready');
  }

  function setupDbV2PricingSlider(root) {
    var viewport = root.querySelector('.db-v2-pricing__viewport');
    var track = root.querySelector('.db-v2-pricing__track');
    var prev = root.querySelector('[data-pricing-prev]');
    var next = root.querySelector('[data-pricing-next]');
    if (!viewport || !track || !prev || !next) return;

    teardownDbV2PricingSlider(root);
    root.setAttribute('data-pricing-ready', '1');

    var gap = 14;
    var initialFullCards = 3;
    var initialPeekRatio = 0.5;
    var abort = typeof AbortController !== 'undefined' ? new AbortController() : null;
    var signal = abort ? { signal: abort.signal } : false;

    function cards() {
      return track.querySelectorAll('.db-v2-pricing__card');
    }

    function layout() {
      if (viewport.clientWidth < 640) {
        return { full: 1, peek: 0.45 };
      }
      return { full: initialFullCards, peek: initialPeekRatio };
    }

    function cardWidth() {
      var config = layout();
      var gapTotal = gap * config.full;
      return (viewport.clientWidth - gapTotal) / (config.full + config.peek);
    }

    function syncCardWidths() {
      var width = cardWidth();
      cards().forEach(function(card) {
        card.style.flexBasis = width + 'px';
        card.style.width = width + 'px';
        card.style.maxWidth = width + 'px';
      });
      root.style.setProperty('--db-v2-pricing-card-width', width + 'px');
    }

    function cardStep() {
      return cardWidth() + gap;
    }

    function maxScroll() {
      return Math.max(0, viewport.scrollWidth - viewport.clientWidth);
    }

    function syncButtons() {
      var max = maxScroll();
      var left = viewport.scrollLeft;
      prev.classList.toggle('is-disabled', left <= 1);
      next.classList.toggle('is-disabled', left >= max - 1);
    }

    function layoutAndSync() {
      var previousLeft = viewport.scrollLeft;
      syncCardWidths();
      viewport.scrollLeft = Math.min(previousLeft, maxScroll());
      syncButtons();
    }

    function goPrev() {
      viewport.scrollBy({ left: -cardStep(), behavior: 'smooth' });
    }

    function goNext() {
      viewport.scrollBy({ left: cardStep(), behavior: 'smooth' });
    }

    prev.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      goPrev();
    }, signal);

    next.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      goNext();
    }, signal);

    viewport.addEventListener('scroll', syncButtons, signal ? Object.assign({ passive: true }, signal) : { passive: true });
    window.addEventListener('resize', layoutAndSync, signal);

    var ro = null;
    if (typeof ResizeObserver !== 'undefined') {
      ro = new ResizeObserver(layoutAndSync);
      ro.observe(viewport);
      root._pricingResizeObserver = ro;
    }

    root._pricingCleanup = function() {
      if (abort) abort.abort();
      if (ro) ro.disconnect();
      root._pricingResizeObserver = null;
      track.style.transform = '';
      track.style.transition = '';
    };

    requestAnimationFrame(function() {
      requestAnimationFrame(layoutAndSync);
    });
  }

  function initDbV2PricingSliders() {
    document.querySelectorAll('[data-pricing-slider]').forEach(function(root) {
      if (!root.querySelector('.db-v2-pricing__viewport')) return;
      if (root.getAttribute('data-pricing-ready') === '1') {
        teardownDbV2PricingSlider(root);
      }
      setupDbV2PricingSlider(root);
    });
  }

  function onReady() {
    initDbV2PricingSliders();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }

  document.addEventListener('turbo:load', onReady);
  document.addEventListener('turbolinks:load', onReady);

  function clearReady() {
    document.querySelectorAll('[data-pricing-ready]').forEach(function(el) {
      teardownDbV2PricingSlider(el);
    });
  }

  document.addEventListener('turbo:before-cache', clearReady);
  document.addEventListener('turbolinks:before-cache', clearReady);
})();
