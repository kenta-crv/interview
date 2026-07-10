(function() {
  function setupDbV2PricingSlider(root) {
    var viewport = root.querySelector('.db-v2-pricing__viewport');
    var track = root.querySelector('.db-v2-pricing__track');
    var prev = root.querySelector('[data-pricing-prev]');
    var next = root.querySelector('[data-pricing-next]');
    if (!viewport || !track || !prev || !next) return;

    root.setAttribute('data-pricing-ready', '1');

    var index = 0;
    var gap = 14;
    var touchStartX = null;
    var initialFullCards = 3;
    var initialPeekRatio = 0.5;

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

    function maxIndex() {
      return Math.max(0, cards().length - layout().full);
    }

    function render() {
      syncCardWidths();
      var max = maxIndex();
      if (index > max) index = max;
      track.style.transform = 'translateX(-' + (index * cardStep()) + 'px)';
      prev.classList.toggle('is-disabled', index <= 0);
      next.classList.toggle('is-disabled', index >= max);
    }

    function goPrev() {
      if (index <= 0) return;
      index -= 1;
      render();
    }

    function goNext() {
      if (index >= maxIndex()) return;
      index += 1;
      render();
    }

    prev.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      goPrev();
    });

    next.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      goNext();
    });

    viewport.addEventListener('touchstart', function(e) {
      if (!e.touches.length) return;
      touchStartX = e.touches[0].clientX;
    }, { passive: true });

    viewport.addEventListener('touchend', function(e) {
      if (touchStartX === null || !e.changedTouches.length) return;
      var delta = e.changedTouches[0].clientX - touchStartX;
      touchStartX = null;
      if (Math.abs(delta) < 40) return;
      if (delta < 0) goNext();
      else goPrev();
    }, { passive: true });

    window.addEventListener('resize', render);

    if (typeof ResizeObserver !== 'undefined') {
      var ro = new ResizeObserver(render);
      ro.observe(viewport);
      ro.observe(track);
    }

    requestAnimationFrame(function() {
      requestAnimationFrame(render);
    });
  }

  function initDbV2PricingSliders() {
    document.querySelectorAll('[data-pricing-slider]:not([data-pricing-ready])').forEach(function(root) {
      if (!root.querySelector('.db-v2-pricing__viewport')) return;
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
      el.removeAttribute('data-pricing-ready');
    });
  }

  document.addEventListener('turbo:before-cache', clearReady);
  document.addEventListener('turbolinks:before-cache', clearReady);
})();
