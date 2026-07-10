// Turbo / DOMContentLoaded 両対応のページ初期化ヘルパー
(function(global) {
  function onPageReady(fn) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
    document.addEventListener('turbo:load', fn);
    document.addEventListener('turbolinks:load', fn);
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
    document.querySelectorAll('[data-pricing-bound]').forEach(function(el) {
      el.removeAttribute('data-pricing-bound');
    });
  });

  document.addEventListener('turbolinks:before-cache', function() {
    document.querySelectorAll('[data-pricing-bound]').forEach(function(el) {
      el.removeAttribute('data-pricing-bound');
    });
  });

  function setupMeetiaPricingSlider(root) {
    var viewport = root.querySelector('.meetia-pricing__viewport');
    var track = root.querySelector('.meetia-pricing__track');
    var prev = root.querySelector('[data-pricing-prev]');
    var next = root.querySelector('[data-pricing-next]');
    if (!viewport || !track || !prev || !next) return;

    var index = 0;
    var gap = 14;
    var touchStartX = null;
    var initialFullCards = 3;
    var initialPeekRatio = 0.5;

    function cards() {
      return track.querySelectorAll('.meetia-pricing__card');
    }

    function layout() {
      var viewportWidth = viewport.clientWidth;
      if (viewportWidth < 640) {
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
      root.style.setProperty('--meetia-pricing-card-width', width + 'px');
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
      root._pricingResizeObserver = ro;
    }

    requestAnimationFrame(function() {
      requestAnimationFrame(render);
    });
  }

  function initPricingSlider() {
    document.querySelectorAll('.meetia-pricing__slider[data-pricing-slider]').forEach(function(slider) {
      MeetiaPageInit.bindOnce(slider, 'data-pricing-bound', setupMeetiaPricingSlider);
    });
  }

  MeetiaPageInit.onPageReady(initPricingSlider);

  function initLpNav() {
    document.querySelectorAll('[data-lp-nav-toggle]').forEach(function(toggle) {
      MeetiaPageInit.bindOnce(toggle, 'data-lp-nav-bound', function(btn) {
        var menu = document.querySelector('[data-lp-nav-menu]');
        if (!menu) return;
        btn.addEventListener('click', function() {
          menu.classList.toggle('is-open');
        });
      });
    });
  }

  function initFeatureTabs() {
    document.querySelectorAll('.meetia-feature-tabs').forEach(function(root) {
      MeetiaPageInit.bindOnce(root, 'data-feature-tabs-bound', function(tabs) {
        var buttons = tabs.querySelectorAll('[data-feature-tab]');
        var rows = document.querySelectorAll('[data-feature-panel]');
        if (!buttons.length || !rows.length) return;

        function activate(tab) {
          buttons.forEach(function(btn) {
            btn.classList.toggle('is-active', btn.getAttribute('data-feature-tab') === tab);
          });
          rows.forEach(function(row) {
            row.classList.toggle('is-active', row.getAttribute('data-feature-panel') === tab);
          });
        }

        buttons.forEach(function(btn) {
          btn.addEventListener('click', function() {
            activate(btn.getAttribute('data-feature-tab'));
          });
        });
      });
    });
  }

  function initFaqChat() {
    document.querySelectorAll('[data-faq-chat]').forEach(function(chat) {
      MeetiaPageInit.bindOnce(chat, 'data-faq-chat-bound', function(root) {
        var userBubble = root.querySelector('[data-faq-user]');
        var answerBubble = root.querySelector('[data-faq-answer]');
        var userText = root.querySelector('[data-faq-user-text]');
        var answerText = root.querySelector('[data-faq-answer-text]');
        if (!userBubble || !answerBubble || !userText || !answerText) return;

        document.querySelectorAll('[data-faq-q]').forEach(function(chip) {
          chip.addEventListener('click', function() {
            userText.textContent = chip.getAttribute('data-faq-q');
            answerText.textContent = chip.getAttribute('data-faq-a');
            userBubble.classList.remove('is-hidden');
            answerBubble.classList.remove('is-hidden');
          });
        });
      });
    });
  }

  function initHeroPlayButton() {
    document.querySelectorAll('[data-hero-play]').forEach(function(btn) {
      MeetiaPageInit.bindOnce(btn, 'data-hero-play-bound', function(button) {
        function setPlaying(playing) {
          button.classList.toggle('presentation-play-btn--playing', !!playing);
          button.setAttribute('aria-label', playing ? '一時停止' : '再生');
        }

        button.addEventListener('click', function() {
          setPlaying(!button.classList.contains('presentation-play-btn--playing'));
        });

        if (button.classList.contains('presentation-play-btn--playing')) {
          setPlaying(true);
        }
      });
    });
  }

  function initFaqSearch() {
    var searchInput = document.querySelector('[data-faq-search]');
    var items = document.querySelectorAll('.meetia-faq-panel__item');
    if (!searchInput || !items.length) return;

    MeetiaPageInit.bindOnce(searchInput, 'data-faq-search-bound', function(input) {
      input.addEventListener('input', function() {
        var q = input.value.trim().toLowerCase();
        items.forEach(function(item) {
          var text = item.textContent.toLowerCase();
          item.style.display = !q || text.indexOf(q) !== -1 ? '' : 'none';
        });
      });
    });
  }

  MeetiaPageInit.onPageReady(initLpNav);
  MeetiaPageInit.onPageReady(initFeatureTabs);
  MeetiaPageInit.onPageReady(initFaqChat);
  MeetiaPageInit.onPageReady(initHeroPlayButton);
  MeetiaPageInit.onPageReady(initFaqSearch);
})(window);
