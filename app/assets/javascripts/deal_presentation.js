(function() {
  var init = window.MeetiaPageInit;

  function readConfig() {
    var el = document.getElementById('deal-presentation-config');
    if (!el) return { pages: [], opening: {} };

    try {
      var data = JSON.parse(el.textContent);
      return {
        pages: data.pages || [],
        opening: data.opening || {}
      };
    } catch (_e) {
      return { pages: [], opening: {} };
    }
  }

  function initDealPresentation() {
    var wrapper = document.querySelector('[data-deal-presentation]');
    if (!wrapper) return;

    var bind = init ? init.bindOnce.bind(init) : function(root, attr, fn) {
      if (root.getAttribute(attr) === 'true') return;
      root.setAttribute(attr, 'true');
      fn(root);
    };

    bind(wrapper, 'data-meetia-bound', function(root) {
      var config = readConfig();
      var pages = config.pages;
      var opening = config.opening;
      var slides = root.querySelectorAll('.document-slide');
      var choiceButtons = root.querySelectorAll('.btn-choice');
      var avatar = root.querySelector('.avatar-img-2');
      var overlay = document.getElementById('presentation-start-overlay');
      var startBtn = document.getElementById('presentation-start-btn');
      var currentAudio = null;
      var audioUnlocked = false;
      var presentationStarted = false;

      function openingValue(key) {
        return opening[key] || opening[key.replace(/_/g, '-')] || null;
      }

      function hasOpeningAudio() {
        return Boolean(openingValue('greeting_audio') || openingValue('company_overview_audio'));
      }

      function setAvatarSpeaking(active) {
        if (!avatar) return;
        avatar.classList.toggle('avatar-img-2--speaking', active);
      }

      function hideOverlay() {
        if (!overlay) return;
        overlay.hidden = true;
        overlay.style.display = 'none';
        document.body.classList.remove('presentation-locked');
      }

      function showOverlay() {
        if (!overlay) return;
        overlay.hidden = false;
        overlay.style.display = 'flex';
        document.body.classList.add('presentation-locked');
      }

      function playUrl(url) {
        return new Promise(function(resolve) {
          if (!url) {
            resolve();
            return;
          }

          if (currentAudio) {
            currentAudio.pause();
            currentAudio = null;
          }

          var audio = new Audio(url);
          currentAudio = audio;
          setAvatarSpeaking(true);

          function finish() {
            setAvatarSpeaking(false);
            currentAudio = null;
            resolve();
          }

          audio.addEventListener('ended', finish);
          audio.addEventListener('error', finish);

          audio.play().then(function() {
            audioUnlocked = true;
          }).catch(finish);
        });
      }

      function playSequence(urls) {
        return urls.filter(Boolean).reduce(function(chain, url) {
          return chain.then(function() { return playUrl(url); });
        }, Promise.resolve());
      }

      function openingUrls() {
        return [
          openingValue('greeting_audio'),
          openingValue('company_overview_audio')
        ];
      }

      function showSlideByPageNumber(pageNumber) {
        var matched = false;
        slides.forEach(function(slide) {
          var active = parseInt(slide.dataset.pageNumber, 10) === pageNumber;
          slide.classList.toggle('active', active);
          if (active) matched = true;
        });

        if (!matched && slides.length > 0) {
          var index = Math.max(0, Math.min(pageNumber - 1, slides.length - 1));
          slides.forEach(function(slide, i) {
            slide.classList.toggle('active', i === index);
          });
        }
      }

      function setActiveButton(pageNumber) {
        choiceButtons.forEach(function(btn) {
          var active = parseInt(btn.dataset.pageNumber, 10) === pageNumber;
          btn.classList.toggle('btn-choice--active', active);
        });
      }

      function startPresentation() {
        if (presentationStarted) return Promise.resolve();
        presentationStarted = true;
        audioUnlocked = true;
        hideOverlay();
        showSlideByPageNumber(openingValue('company_page') || 1);
        return playSequence(openingUrls());
      }

      function handleChoice(pageNumber) {
        var page = pages.find(function(p) { return p.page_number === pageNumber; });
        showSlideByPageNumber(pageNumber);
        setActiveButton(pageNumber);
        return playUrl(page && page.audio_url);
      }

      choiceButtons.forEach(function(button) {
        button.addEventListener('click', function() {
          var pageNumber = parseInt(this.dataset.pageNumber, 10);
          if (!pageNumber) return;

          if (!audioUnlocked) {
            startPresentation().then(function() {
              handleChoice(pageNumber);
            });
            return;
          }

          handleChoice(pageNumber);
        });
      });

      if (startBtn) {
        startBtn.addEventListener('click', function(e) {
          e.stopPropagation();
          startPresentation();
        });
      }

      showSlideByPageNumber(openingValue('company_page') || 1);

      if (slides.length > 0 && hasOpeningAudio()) {
        showOverlay();
      } else {
        hideOverlay();
      }
    });
  }

  if (init) {
    init.onPageReady(initDealPresentation);
  } else {
    document.addEventListener('DOMContentLoaded', initDealPresentation);
    document.addEventListener('turbo:load', initDealPresentation);
  }
})();
