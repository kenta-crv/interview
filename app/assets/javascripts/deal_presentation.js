(function() {
  var init = window.MeetiaPageInit;

  function readConfig() {
    var defaults = { pages: [], opening: {}, opening_segments: [], closing: {}, materials: null, public_mode: false, preview_mode: false, finish_redirect_url: '/', cta: {} };
    var el = document.getElementById('deal-presentation-config');
    if (!el) return defaults;

    try {
      var data = JSON.parse(el.textContent);
      return {
        pages: data.pages || [],
        opening: data.opening || {},
        opening_segments: data.opening_segments || [],
        closing: data.closing || {},
        materials: data.materials || null,
        respond_url: data.respond_url || '',
        evaluate_url: data.evaluate_url || '',
        track_url: data.track_url || '',
        public_mode: !!data.public_mode,
        preview_mode: !!data.preview_mode,
        finish_redirect_url: data.finish_redirect_url || '/',
        cta: data.cta || {}
      };
    } catch (_e) {
      return defaults;
    }
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
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
      var openingSegments = config.opening_segments;
      var closing = config.closing || {};
      var materials = config.materials;
      var respondUrl = root.dataset.respondUrl || config.respond_url;
      var evaluateUrl = root.dataset.evaluateUrl || config.evaluate_url;
      var trackUrl = root.dataset.trackUrl || config.track_url;
      var slides = root.querySelectorAll('.document-slide');
      var documentViewport = root.querySelector('.document-viewport');
      var choiceButtons = root.querySelectorAll('.presentation-choice-track .btn-choice');
      var pageNavItems = root.querySelectorAll('.presentation-page-nav__item');
      var pdfDocCache = {};
      var pdfRenderTasks = {};
      var pdfRenderGeneration = {};
      var pdfResizeTimer = null;
      var avatar = document.getElementById('presentation-avatar-img');
      var overlay = document.getElementById('presentation-start-overlay');
      var startBtn = document.getElementById('presentation-start-btn');
      var chatPanel = document.getElementById('presentation-chat-panel');
      var chatToggle = document.getElementById('presentation-chat-toggle');
      var messagesContainer = document.getElementById('conversation-messages');
      var freeTextInput = document.getElementById('free-text-input');
      var freeTextBtn = document.getElementById('send-free-text');
      var endBtn = document.getElementById('end-conversation-btn');
      var modal = document.getElementById('evaluation-modal');
      var submitEvaluationBtn = document.getElementById('submit-evaluation');
      var evaluationNotice = document.getElementById('evaluation-notice');
      var ctaBtn = document.getElementById('presentation-cta-btn');
      var exitContractBtn = document.getElementById('exit-contract-btn');
      var headerSalesCallBtn = document.getElementById('presentation-sales-call-btn');
      var exitSalesCallBtn = document.getElementById('exit-sales-call-btn');
      var materialsDownloadLink = document.getElementById('presentation-materials-download');
      var ctaConfig = config.cta || {};
      var currentAudio = null;
      var presentationStarted = false;
      var currentPageNumber = parseInt((opening.greeting_page || opening['greeting-page'] || 1), 10);
      var sessionStartedAt = Date.now();
      var timerEl = document.getElementById('presentation-timer');
      var voiceBtn = document.getElementById('presentation-voice-btn');
      var playbackToken = 0;
      var isPaused = false;
      var openingQueue = null;
      var currentSpeech = null;
      var audioCache = {};
      var autoAdvance = null;
      var IDLE_BEFORE_AUTO_MS = 2500;
      var SEGMENT_GAP_MS = 900;
      var closingPlayed = false;
      var sideCtasVisible = false;
      var heat = {
        viewedPages: {},
        topicClicks: 0,
        freeTextCount: 0,
        roleHits: 0
      };

      function setPlayButtonPlaying(playing) {
        if (!voiceBtn) return;
        voiceBtn.classList.toggle('presentation-play-btn--playing', !!playing);
        voiceBtn.setAttribute('aria-label', playing ? '一時停止' : '再生');
      }

      function isSpeechActive() {
        return 'speechSynthesis' in window &&
          (window.speechSynthesis.speaking || window.speechSynthesis.paused);
      }

      function hasResumablePlayback() {
        if (currentAudio && !currentAudio.ended && currentAudio.paused) return true;
        if (isSpeechActive() && window.speechSynthesis.paused) return true;
        if (openingQueue && openingQueue.running && isPaused) return true;
        return false;
      }

      function pausePlayback() {
        isPaused = true;
        if (currentAudio && !currentAudio.ended) {
          currentAudio.pause();
        } else if (isSpeechActive() && !window.speechSynthesis.paused) {
          window.speechSynthesis.pause();
        }
        setPlayButtonPlaying(false);
      }

      function resumePlayback() {
        isPaused = false;
        setPlayButtonPlaying(true);

        if (currentAudio && currentAudio.paused && !currentAudio.ended) {
          var attempt = currentAudio.play();
          if (attempt && attempt.catch) attempt.catch(function() {});
          return Promise.resolve();
        }

        if (isSpeechActive() && window.speechSynthesis.paused) {
          window.speechSynthesis.resume();
          return Promise.resolve();
        }

        if (openingQueue && openingQueue.running) {
          return continueOpeningQueue();
        }

        setPlayButtonPlaying(false);
        return Promise.resolve();
      }

      function resetPlayback() {
        playbackToken += 1;
        isPaused = false;
        currentSpeech = null;
        cancelAutoAdvance();
        if (currentAudio) {
          currentAudio.pause();
          currentAudio = null;
        }
        if ('speechSynthesis' in window) window.speechSynthesis.cancel();
        openingQueue = null;
        setPlayButtonPlaying(false);
      }

      function wait(ms) {
        return new Promise(function(resolve) {
          setTimeout(resolve, ms);
        });
      }

      function ensurePdfJsReady(timeoutMs) {
        if (window.pdfjsLib) {
          if (pdfjsLib.GlobalWorkerOptions && !pdfjsLib.GlobalWorkerOptions.workerSrc) {
            pdfjsLib.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js';
          }
          return Promise.resolve(true);
        }
        var limit = typeof timeoutMs === 'number' ? timeoutMs : 4000;
        var started = Date.now();
        return new Promise(function(resolve) {
          function tick() {
            if (window.pdfjsLib) {
              if (pdfjsLib.GlobalWorkerOptions && !pdfjsLib.GlobalWorkerOptions.workerSrc) {
                pdfjsLib.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js';
              }
              resolve(true);
              return;
            }
            if (Date.now() - started >= limit) {
              resolve(false);
              return;
            }
            setTimeout(tick, 50);
          }
          tick();
        });
      }

      function whenAudioReady(audio, timeoutMs) {
        return new Promise(function(resolve) {
          if (!audio) {
            resolve(false);
            return;
          }
          // HAVE_FUTURE_DATA (3) or HAVE_ENOUGH_DATA (4)
          if (audio.readyState >= 3) {
            resolve(true);
            return;
          }

          var settled = false;
          var timer = setTimeout(function() {
            if (settled) return;
            settled = true;
            resolve(audio.readyState >= 2);
          }, typeof timeoutMs === 'number' ? timeoutMs : 2500);

          function done(ok) {
            if (settled) return;
            settled = true;
            clearTimeout(timer);
            resolve(!!ok);
          }

          audio.addEventListener('canplaythrough', function() { done(true); }, { once: true });
          audio.addEventListener('canplay', function() { done(true); }, { once: true });
          audio.addEventListener('error', function() { done(false); }, { once: true });
        });
      }

      function preloadAudio(url) {
        if (!url) return Promise.resolve(null);
        if (audioCache[url]) {
          return whenAudioReady(audioCache[url], 2500).then(function() {
            return audioCache[url];
          });
        }
        try {
          var audio = new Audio();
          audio.preload = 'auto';
          audio.src = url;
          audioCache[url] = audio;
          try { audio.load(); } catch (_loadErr) {}
          return whenAudioReady(audio, 2500).then(function() {
            return audio;
          });
        } catch (_e) {
          return Promise.resolve(null);
        }
      }

      function takeCachedAudio(url) {
        if (url && audioCache[url]) {
          var cached = audioCache[url];
          delete audioCache[url];
          try { cached.currentTime = 0; } catch (_e) {}
          return cached;
        }
        return url ? new Audio(url) : null;
      }

      function afterLayout(fn) {
        return new Promise(function(resolve) {
          window.requestAnimationFrame(function() {
            window.requestAnimationFrame(function() {
              resolve(typeof fn === 'function' ? fn() : undefined);
            });
          });
        });
      }

      function cancelAutoAdvance() {
        if (autoAdvance && autoAdvance.timer) {
          clearTimeout(autoAdvance.timer);
          autoAdvance.timer = null;
        }
        if (autoAdvance) autoAdvance.running = false;
        autoAdvance = null;
      }

      function pagesForAutoAdvance() {
        return pages
          .slice()
          .filter(function(page) {
            return page && page.page_number > 1 && (page.audio_url || page.script);
          })
          .sort(function(a, b) {
            return a.page_number - b.page_number;
          });
      }

      function scheduleAutoAdvance(delayMs) {
        cancelAutoAdvance();
        var list = pagesForAutoAdvance();
        var startIdx = 0;
        while (startIdx < list.length && list[startIdx].page_number <= currentPageNumber) {
          startIdx += 1;
        }
        if (startIdx >= list.length) return;

        autoAdvance = {
          running: true,
          pages: list,
          nextIndex: startIdx,
          timer: null
        };
        autoAdvance.timer = setTimeout(function() {
          if (!autoAdvance || !autoAdvance.running) return;
          autoAdvance.timer = null;
          continueAutoAdvance();
        }, typeof delayMs === 'number' ? delayMs : IDLE_BEFORE_AUTO_MS);
      }

      function continueAutoAdvance() {
        if (!autoAdvance || !autoAdvance.running || isPaused) {
          return Promise.resolve();
        }

        var index = autoAdvance.nextIndex;
        if (index >= autoAdvance.pages.length) {
          cancelAutoAdvance();
          setPlayButtonPlaying(false);
          return playClosing({ source: 'auto_advance_complete' });
        }

        var page = autoAdvance.pages[index];
        var nextPage = autoAdvance.pages[index + 1];
        if (nextPage && nextPage.audio_url) preloadAudio(nextPage.audio_url);

        notePageEngagement(page);
        trackEvent('auto_advance', { page_number: page.page_number });

        var keepUi = index < autoAdvance.pages.length - 1;
        return presentPage(page.page_number, { syncChoice: false }).then(function() {
          if (!autoAdvance || !autoAdvance.running || isPaused) return;
          return playUrl(page.audio_url, page.script, { keepPlayingUi: keepUi });
        }).then(function() {
          if (!autoAdvance || !autoAdvance.running || isPaused) return;
          maybeShowSideCtasForPage(page);
          autoAdvance.nextIndex = index + 1;
          if (autoAdvance.nextIndex >= autoAdvance.pages.length) {
            return continueAutoAdvance();
          }
          return wait(SEGMENT_GAP_MS).then(function() {
            if (!autoAdvance || !autoAdvance.running || isPaused) return;
            return continueAutoAdvance();
          });
        });
      }

      function findPage(pageNumber) {
        var n = parseInt(pageNumber, 10);
        if (!n) return null;
        return pages.find(function(p) {
          return parseInt(p.page_number, 10) === n;
        }) || null;
      }

      function pageRole(page) {
        if (!page) return null;
        if (page.role === 'pricing' || page.role === 'flow') return page.role;
        var hay = [page.title || '', page.script || ''].join(' ');
        if (/料金|費用|価格|プラン|月額|pricing|price|plan/i.test(hay)) return 'pricing';
        if (/導入フロー|契約フロー|オンボーディング|導入の流れ|導入手順|flow/i.test(hay)) return 'flow';
        return null;
      }

      function isClosingRole(page) {
        var role = pageRole(page);
        return role === 'pricing' || role === 'flow';
      }

      function setActionMode(_mode) {
        // 「最後に」ボタンは一旦非表示。レイアウトを崩さないため no-op。
        refreshChoiceScrollers();
      }

      function notePageEngagement(page) {
        if (!page || !page.page_number) return;
        heat.viewedPages[String(page.page_number)] = true;
        if (isClosingRole(page)) {
          heat.roleHits += 1;
        }
      }

      function heatScore() {
        return Object.keys(heat.viewedPages).length + (heat.topicClicks * 2) + (heat.freeTextCount * 3) + (heat.roleHits * 3);
      }

      function isHotEnough() {
        return heat.roleHits > 0;
      }

      function updateLastButtonVisibility() {
        // 「最後に」ボタンは一旦出さない
        setActionMode(null);
      }

      function showSideCtas() {
        sideCtasVisible = true;
        updateLastButtonVisibility();
      }

      function maybeShowSideCtasForPage(page) {
        if (!page) return;
        if (isClosingRole(page)) {
          showSideCtas();
        }
      }

      function closingText() {
        return closing.text || closing['text'] || openingValue('closing_text') || '';
      }

      function closingAudioUrl() {
        return closing.audio_url || closing['audio_url'] || openingValue('closing_audio') || '';
      }

      function stopAllSpeech() {
        openingQueue = null;
        cancelAutoAdvance();
        isPaused = false;
        playbackToken += 1;
        currentSpeech = null;
        if (currentAudio) {
          try { currentAudio.pause(); } catch (_e) {}
          currentAudio = null;
        }
        if ('speechSynthesis' in window) {
          try { window.speechSynthesis.cancel(); } catch (_e2) {}
        }
        setPlayButtonPlaying(false);
      }

      function playClosing(options) {
        options = options || {};
        stopAllSpeech();
        closingPlayed = true;
        updateLastButtonVisibility();

        var pageNumber = parseInt(closing.page_number || closing['page_number'] || openingValue('closing_page') || currentPageNumber, 10) || currentPageNumber;
        trackEvent('closing_play', {
          page_number: pageNumber,
          metadata: { source: options.source || 'unknown' }
        });
        appendChatMessage(closingText(), 'assistant', null);

        return presentPage(pageNumber, { syncChoice: false }).then(function() {
          return playUrl(closingAudioUrl(), closingText());
        }).then(function() {
          showSideCtas();
        });
      }

      function playCurrentPageAudio() {
        cancelAutoAdvance();
        var page = findPage(currentPageNumber);
        if (!page) return Promise.resolve();
        notePageEngagement(page);
        if (page.audio_url || page.script) {
          return renderActivePdfSlide().then(function() {
            return playUrl(page.audio_url, page.script);
          }).then(function() {
            maybeShowSideCtasForPage(page);
            scheduleAutoAdvance(IDLE_BEFORE_AUTO_MS);
          });
        }
        return Promise.resolve();
      }

      if (timerEl) {
        setInterval(function() {
          var elapsed = Math.floor((Date.now() - sessionStartedAt) / 1000);
          var h = Math.floor(elapsed / 3600);
          var m = Math.floor((elapsed % 3600) / 60);
          var s = elapsed % 60;
          timerEl.textContent = [h, m, s].map(function(n) {
            return String(n).padStart(2, '0');
          }).join(':');
        }, 1000);
      }

      var choiceScrollerRefreshers = [];

      function refreshChoiceScrollers() {
        choiceScrollerRefreshers.forEach(function(fn) { fn(); });
      }

      function initChoiceScroller() {
        var leftWrap = document.getElementById('presentation-choice-scroller-wrap-left');
        var rightWrap = document.getElementById('presentation-choice-scroller-wrap-right');
        var leftScroller = document.getElementById('presentation-choice-scroller-left');
        var rightScroller = document.getElementById('presentation-choice-scroller-right');
        var prevBtn = document.getElementById('presentation-choice-more-prev');
        var nextBtn = document.getElementById('presentation-choice-more-next');
        if (!leftWrap || !rightWrap || !leftScroller || !rightScroller || !prevBtn || !nextBtn) return;

        function sideState(scroller) {
          var overflow = scroller.scrollWidth > scroller.clientWidth + 2;
          var atStart = scroller.scrollLeft <= 4;
          var atEnd = scroller.scrollLeft + scroller.clientWidth >= scroller.scrollWidth - 4;
          return { overflow: overflow, atStart: atStart, atEnd: atEnd };
        }

        function alignLeftScroller() {
          leftScroller.scrollLeft = Math.max(0, leftScroller.scrollWidth - leftScroller.clientWidth);
        }

        function updateChoiceScroller() {
          var left = sideState(leftScroller);
          var right = sideState(rightScroller);

          leftWrap.classList.toggle('has-overflow', left.overflow && !left.atStart);
          rightWrap.classList.toggle('has-overflow', right.overflow && !right.atEnd);

          // 左右どちらかが戻せる/進めれば矢印を出す（共通操作）
          prevBtn.hidden = !((left.overflow && !left.atStart) || (right.overflow && !right.atStart));
          nextBtn.hidden = !((right.overflow && !right.atEnd) || (left.overflow && !left.atEnd));
        }

        function scrollShared(direction) {
          var delta = Math.max(160, Math.min(leftScroller.clientWidth, rightScroller.clientWidth) * 0.7);
          var left = sideState(leftScroller);
          var right = sideState(rightScroller);

          if (direction > 0) {
            if (right.overflow && !right.atEnd) {
              rightScroller.scrollBy({ left: delta, behavior: 'smooth' });
            } else if (left.overflow && !left.atEnd) {
              leftScroller.scrollBy({ left: delta, behavior: 'smooth' });
            }
          } else if (left.overflow && !left.atStart) {
            leftScroller.scrollBy({ left: -delta, behavior: 'smooth' });
          } else if (right.overflow && !right.atStart) {
            rightScroller.scrollBy({ left: -delta, behavior: 'smooth' });
          }
        }

        prevBtn.addEventListener('click', function() { scrollShared(-1); });
        nextBtn.addEventListener('click', function() { scrollShared(1); });
        leftScroller.addEventListener('scroll', updateChoiceScroller, { passive: true });
        rightScroller.addEventListener('scroll', updateChoiceScroller, { passive: true });
        window.addEventListener('resize', function() {
          alignLeftScroller();
          updateChoiceScroller();
        });

        alignLeftScroller();
        updateChoiceScroller();
        choiceScrollerRefreshers.push(function() {
          alignLeftScroller();
          updateChoiceScroller();
        });
      }

      initChoiceScroller();

      var sessionKey = (function() {
        var storageKey = 'deal-presentation-session';
        var existing = null;
        try { existing = sessionStorage.getItem(storageKey); } catch (_e) {}
        if (existing) return existing;
        var generated = 'sess_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
        try { sessionStorage.setItem(storageKey, generated); } catch (_e2) {}
        return generated;
      })();
      var conversationHistory = [];
      var closeLogged = false;
      var exitModalShown = false;

      function trackEvent(eventType, details) {
        if (!trackUrl) return;

        var payload = Object.assign({
          session_key: sessionKey,
          event_type: eventType,
          page_number: currentPageNumber,
          occurred_at: new Date().toISOString()
        }, details || {});

        var body = JSON.stringify(payload);
        var useBeacon = eventType === 'session_close' && navigator.sendBeacon;

        if (useBeacon) {
          var blob = new Blob([body], { type: 'application/json' });
          navigator.sendBeacon(trackUrl, blob);
          return;
        }

        fetch(trackUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken()
          },
          body: body,
          keepalive: true
        }).catch(function() {});
      }

      function logSessionClose(reason) {
        if (closeLogged || exitModalShown) return;
        closeLogged = true;
        trackEvent('session_close', {
          metadata: {
            reason: reason,
            presentation_started: presentationStarted,
            current_page_number: currentPageNumber,
            duration_ms: Date.now() - sessionStartedAt,
            evaluated: false
          }
        });
      }

      function finalizeSession(reason, ratingValue, feedbackValue) {
        if (closeLogged) return Promise.resolve();
        closeLogged = true;

        var tasks = [];
        if (trackUrl) {
          tasks.push(Promise.resolve(trackEvent('evaluation_submit', {
            metadata: {
              rating: ratingValue,
              feedback: feedbackValue || ''
            }
          })));
        }

        if (evaluateUrl) {
          tasks.push(
            fetch(evaluateUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': csrfToken()
              },
              body: JSON.stringify({
                rating: ratingValue,
                feedback: feedbackValue || ''
              })
            }).then(function(response) {
              if (!response.ok) {
                return response.json().catch(function() { return {}; }).then(function(payload) {
                  var message = (payload && payload.errors && payload.errors[0]) || '評価の送信に失敗しました';
                  throw new Error(message);
                });
              }
              return response;
            })
          );
        }

        return Promise.all(tasks).then(function() {
          trackEvent('session_close', {
            metadata: {
              reason: reason,
              presentation_started: presentationStarted,
              current_page_number: currentPageNumber,
              duration_ms: Date.now() - sessionStartedAt,
              evaluated: true,
              rating: ratingValue
            }
          });
        });
      }

      function showEvaluationRequiredNotice() {
        if (evaluationNotice) {
          evaluationNotice.classList.add('is-warning');
          evaluationNotice.textContent = '商談を終了するには、満足度（星）を選び「評価を送信して終了」を押してください。';
        }
        alert('満足度の評価を送信してから終了してください。');
      }

      function closePresentationWindow() {
        pausePlayback();
        hideExitModal();
        hideOverlay();
        document.body.classList.remove('presentation-exit-open', 'presentation-locked');

        if (config.preview_mode) {
          try { window.close(); } catch (_e) {}
          if (!window.closed) {
            window.location.assign(config.finish_redirect_url || '/');
          }
          return;
        }

        if (config.public_mode) {
          window.location.assign(config.finish_redirect_url || '/');
          return;
        }

        try { window.close(); } catch (_e2) {}
        if (!window.closed) {
          window.location.assign(config.finish_redirect_url || '/');
        }
      }

      function ctaUrl() {
        return (ctaConfig.url || '').trim();
      }

      function salesUrl() {
        return (ctaConfig.sales_url || ctaConfig['sales_url'] || '').trim();
      }

      function openExternalUrl(url) {
        if (!url) return false;
        var opened = window.open(url, '_blank', 'noopener,noreferrer');
        if (!opened) {
          window.location.assign(url);
        }
        return true;
      }

      function openCtaUrl(source) {
        var url = ctaUrl();
        if (!url) {
          alert('契約ページのURLが設定されていません。');
          return false;
        }
        return openExternalUrl(url);
      }

      function trackCtaClick(source, label) {
        trackEvent('cta_click', {
          label: label,
          metadata: { source: source, url: ctaUrl() }
        });
      }

      function handleCtaInteraction(e, source) {
        var url = ctaUrl();
        var label = ctaConfig.label || (ctaBtn && (ctaBtn.dataset.label || ctaBtn.textContent.trim())) || 'CTA';

        if (!presentationStarted) {
          if (e) e.preventDefault();
          startPresentation().then(function() {
            trackCtaClick(source, label);
            if (url) openCtaUrl(source);
            else alert('契約ページのURLが設定されていません。');
          });
          return;
        }

        trackCtaClick(source, label);
        if (!url) {
          if (e) e.preventDefault();
          alert('契約ページのURLが設定されていません。');
        }
      }

      function showExitModal() {
        if (!modal) return;
        hideOverlay();
        exitModalShown = true;
        modal.classList.add('presentation-exit-modal--open');
        document.body.classList.add('presentation-exit-open');
        document.body.classList.remove('presentation-locked');
      }

      function hideExitModal() {
        if (!modal) return;
        exitModalShown = false;
        modal.classList.remove('presentation-exit-modal--open');
        document.body.classList.remove('presentation-exit-open');
        if (evaluationNotice) {
          evaluationNotice.classList.remove('is-warning');
          evaluationNotice.textContent = '商談を終了するには、満足度（星）を選び「評価を送信」を押してください。';
        }
      }

      function handleCtaClick(source) {
        handleCtaInteraction(null, source);
      }

      function handleExitContractClick(e) {
        var label = ctaConfig.exit_contract_label || (exitContractBtn && exitContractBtn.textContent.trim()) || '契約へ進む';
        var url = ctaUrl();

        trackEvent('exit_contract_click', {
          label: label,
          metadata: { url: url }
        });

        if (!url) {
          if (e) e.preventDefault();
          alert('契約ページのURLが設定されていません。');
          return;
        }
      }

      function handleExitSalesCallClick(e) {
        var button = e && e.currentTarget;
        var label = (button && (button.dataset.label || button.textContent.trim())) ||
          ctaConfig.exit_sales_call_label ||
          '担当者に繋ぐ';
        var url = salesUrl();
        var source = button && button.id === 'presentation-sales-call-btn' ? 'header' : 'modal';
        trackEvent('exit_sales_call_click', {
          label: label,
          metadata: { url: url || null, source: source }
        });

        if (url) {
          openExternalUrl(url);
          return;
        }

        if (e) e.preventDefault();
        alert('担当者より折り返しご連絡いたします。しばらくお待ちください。');
      }

      function openingValue(key) {
        return opening[key] || opening[key.replace(/_/g, '-')] || null;
      }

      function segmentValue(segment, key) {
        return segment[key] || segment[key.replace(/_/g, '-')] || null;
      }

      function setAvatarSpeaking(_active) {
        /* アバターは静止表示 */
      }

      function hideOverlay() {
        if (!overlay) return;
        overlay.hidden = true;
        overlay.style.display = 'none';
        overlay.setAttribute('aria-hidden', 'true');
        document.body.classList.remove('presentation-locked');
      }

      function showOverlay() {
        if (!overlay) return;
        overlay.hidden = false;
        overlay.style.display = 'flex';
        overlay.setAttribute('aria-hidden', 'false');
        document.body.classList.add('presentation-locked');
      }

      function setChatPanelState(state) {
        if (!chatPanel || !chatToggle) return;
        var isOpen = state === 'open';
        chatPanel.classList.toggle('presentation-chat-panel--open', isOpen);
        chatPanel.classList.toggle('presentation-chat-panel--peek', state === 'peek');
        chatPanel.classList.remove('presentation-chat-panel--closed');
        chatToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
      }

      function stopCurrentAudio(hard) {
        if (!currentAudio) return;
        currentAudio.pause();
        if (hard) currentAudio = null;
      }

      function speakText(text, token) {
        return new Promise(function(resolve) {
          if (!text || !('speechSynthesis' in window)) {
            resolve();
            return;
          }

          var activeToken = token || ++playbackToken;
          if (!token) isPaused = false;

          if (currentSpeech && isSpeechActive()) {
            window.speechSynthesis.cancel();
          }

          var utterance = new SpeechSynthesisUtterance(text);
          utterance.lang = 'ja-JP';
          currentSpeech = utterance;

          function finish() {
            if (activeToken !== playbackToken) {
              resolve();
              return;
            }
            if (isPaused) {
              resolve();
              return;
            }
            currentSpeech = null;
            setAvatarSpeaking(false);
            setPlayButtonPlaying(false);
            resolve();
          }

          utterance.onend = finish;
          utterance.onerror = finish;
          setAvatarSpeaking(true);
          setPlayButtonPlaying(true);
          window.speechSynthesis.speak(utterance);
        });
      }

      function playUrl(url, textFallback, options) {
        options = options || {};
        var keepPlayingUi = !!options.keepPlayingUi;

        return new Promise(function(resolve) {
          var token = ++playbackToken;
          isPaused = false;
          var settled = false;

          function finish() {
            if (settled) return;
            settled = true;
            if (token !== playbackToken) {
              resolve();
              return;
            }
            if (isPaused) {
              resolve();
              return;
            }
            setAvatarSpeaking(false);
            if (!keepPlayingUi) setPlayButtonPlaying(false);
            resolve();
          }

          if (!url) {
            speakText(textFallback, token).then(finish);
            return;
          }

          stopCurrentAudio(true);

          var audio = takeCachedAudio(url);
          currentAudio = audio;
          setAvatarSpeaking(true);
          setPlayButtonPlaying(true);

          function finishAudio() {
            if (token !== playbackToken) {
              finish();
              return;
            }
            if (isPaused) {
              finish();
              return;
            }
            setAvatarSpeaking(false);
            if (currentAudio === audio) currentAudio = null;
            finish();
          }

          function fallback() {
            if (settled || token !== playbackToken) {
              finish();
              return;
            }
            if (currentAudio === audio) currentAudio = null;
            if (textFallback) speakText(textFallback, token).then(finish);
            else finishAudio();
          }

          audio.addEventListener('ended', finishAudio, { once: true });
          audio.addEventListener('error', fallback, { once: true });

          whenAudioReady(audio, 2500).then(function(ready) {
            if (token !== playbackToken || isPaused) {
              finish();
              return;
            }
            if (!ready && audio.readyState < 2) {
              fallback();
              return;
            }
            var playAttempt = audio.play();
            if (playAttempt && playAttempt.catch) {
              playAttempt.catch(fallback);
            }
          });
        });
      }

      function continueOpeningQueue() {
        if (!openingQueue || !openingQueue.running || isPaused) {
          return Promise.resolve();
        }

        var index = openingQueue.nextIndex;
        if (index >= openingQueue.segments.length) {
          openingQueue.running = false;
          setPlayButtonPlaying(false);
          updateLastButtonVisibility();
          scheduleAutoAdvance(IDLE_BEFORE_AUTO_MS);
          return Promise.resolve();
        }

        var segment = openingQueue.segments[index];
        var pageNumber = parseInt(segmentValue(segment, 'page_number'), 10) || 1;
        var url = segmentValue(segment, 'audio_url');
        var text = segmentValue(segment, 'text');
        var nextSegment = openingQueue.segments[index + 1];
        if (nextSegment) preloadAudio(segmentValue(nextSegment, 'audio_url'));

        var keepUi = index < openingQueue.segments.length - 1;
        // ページ描画と音声バッファ完了を待ってから再生（白紙・開始ばらつきを防ぐ）
        return Promise.all([
          presentPage(pageNumber, { syncChoice: false }),
          url ? preloadAudio(url) : Promise.resolve(null)
        ]).then(function() {
          if (isPaused || !openingQueue || !openingQueue.running) return;
          return playUrl(url, text, { keepPlayingUi: keepUi });
        }).then(function() {
          if (isPaused || !openingQueue || !openingQueue.running) return;
          openingQueue.nextIndex = index + 1;
          if (openingQueue.nextIndex >= openingQueue.segments.length) {
            return continueOpeningQueue();
          }
          return wait(SEGMENT_GAP_MS).then(function() {
            if (isPaused || !openingQueue || !openingQueue.running) return;
            return continueOpeningQueue();
          });
        });
      }

      function startOpeningQueue(segments) {
        openingQueue = {
          segments: segments,
          nextIndex: 0,
          running: true
        };
        return continueOpeningQueue();
      }

      function getPdfDocument(url) {
        if (!url) return Promise.reject(new Error('pdf url missing'));
        return ensurePdfJsReady().then(function(ready) {
          if (!ready || !window.pdfjsLib) return Promise.reject(new Error('pdfjs unavailable'));
          if (!pdfDocCache[url]) {
            pdfDocCache[url] = window.pdfjsLib.getDocument({ url: url, withCredentials: true }).promise;
          }
          return pdfDocCache[url];
        });
      }

      function slideFitSize(slide) {
        // Prefer the shared viewport box so mobile layout changes (nav top / sidebar stack)
        // still produce a stable contain-fit size.
        var width = 0;
        var height = 0;
        if (documentViewport) {
          width = documentViewport.clientWidth;
          height = documentViewport.clientHeight;
        }
        if (width < 2 || height < 2) {
          width = slide.clientWidth;
          height = slide.clientHeight;
        }
        return { width: width, height: height };
      }

      function renderPdfSlide(slide, attempt) {
        if (!slide) return Promise.resolve();
        attempt = attempt || 0;

        var canvas = slide.querySelector('canvas.document-pdf-canvas');
        var iframe = slide.querySelector('iframe.document-pdf-clean');
        var url = slide.getAttribute('data-pdf-url');
        var pageNumber = parseInt(slide.getAttribute('data-page-number'), 10);
        if (!canvas || !url || !pageNumber) return Promise.resolve();

        return ensurePdfJsReady(attempt === 0 ? 4000 : 500).then(function(ready) {
          if (!ready || !window.pdfjsLib) {
            // canvas 不可時は iframe を見せたまま（暗い白紙で終わらせない）
            slide.classList.remove('is-pdf-fitted');
            if (iframe) iframe.style.visibility = 'visible';
            return;
          }

          var size = slideFitSize(slide);
          var width = size.width;
          var height = size.height;
          if (width < 2 || height < 2) {
            if (attempt >= 10) {
              slide.classList.remove('is-pdf-fitted');
              return;
            }
            return wait(40 * (attempt + 1)).then(function() {
              return renderPdfSlide(slide, attempt + 1);
            });
          }

          var taskKey = slide.id || String(pageNumber);
          var generation = (pdfRenderGeneration[taskKey] || 0) + 1;
          pdfRenderGeneration[taskKey] = generation;

          if (pdfRenderTasks[taskKey] && typeof pdfRenderTasks[taskKey].cancel === 'function') {
            try { pdfRenderTasks[taskKey].cancel(); } catch (_e) {}
          }

          return getPdfDocument(url).then(function(pdf) {
            if (pdfRenderGeneration[taskKey] !== generation) return;
            return pdf.getPage(pageNumber).then(function(page) {
              if (pdfRenderGeneration[taskKey] !== generation) return;

              var dpr = Math.min(window.devicePixelRatio || 1, 2);
              var baseViewport = page.getViewport({ scale: 1 });
              // Contain: width OR height becomes 100%, never crop, never scroll.
              var fitScale = Math.min(width / baseViewport.width, height / baseViewport.height);
              if (!isFinite(fitScale) || fitScale <= 0) return;

              var viewport = page.getViewport({ scale: fitScale * dpr });
              var canvasW = Math.max(1, Math.floor(width * dpr));
              var canvasH = Math.max(1, Math.floor(height * dpr));
              var offsetX = Math.floor((canvasW - viewport.width) / 2);
              var offsetY = Math.floor((canvasH - viewport.height) / 2);

              canvas.width = canvasW;
              canvas.height = canvasH;

              var context = canvas.getContext('2d', { alpha: false });
              if (!context) return;

              context.setTransform(1, 0, 0, 1, 0, 0);
              context.fillStyle = '#1a1b22';
              context.fillRect(0, 0, canvasW, canvasH);
              context.setTransform(1, 0, 0, 1, offsetX, offsetY);

              var renderTask = page.render({ canvasContext: context, viewport: viewport });
              pdfRenderTasks[taskKey] = renderTask;
              return renderTask.promise.then(function() {
                if (pdfRenderGeneration[taskKey] !== generation) return;
                slide.classList.add('is-pdf-fitted');
              }).catch(function(err) {
                if (err && err.name === 'RenderingCancelledException') return;
                throw err;
              });
            });
          }).catch(function(err) {
            if (err && err.name === 'RenderingCancelledException') return;
            if (pdfRenderGeneration[taskKey] !== generation) return;
            slide.classList.remove('is-pdf-fitted');
            if (attempt < 3) {
              return wait(120 * (attempt + 1)).then(function() {
                return renderPdfSlide(slide, attempt + 1);
              });
            }
            if (window.console && typeof console.warn === 'function') {
              console.warn('[presentation] PDF fit render failed', err);
            }
          });
        });
      }

      function ensureSlideRendered(slide) {
        return renderPdfSlide(slide).then(function() {
          if (!slide || !slide.classList.contains('active')) return;
          if (slide.classList.contains('is-pdf-fitted')) return;
          // リサイズ等でキャンセルされた場合、最新描画が終わるまで一度だけ待つ
          return wait(60).then(function() {
            if (!slide.classList.contains('active')) return;
            if (slide.classList.contains('is-pdf-fitted')) return;
            return renderPdfSlide(slide);
          });
        });
      }

      function renderActivePdfSlide() {
        return ensureSlideRendered(root.querySelector('.document-slide.active'));
      }

      function showSlideByPageNumber(pageNumber) {
        var matched = false;
        var activeSlide = null;
        slides.forEach(function(slide) {
          var active = parseInt(slide.dataset.pageNumber, 10) === pageNumber;
          slide.classList.toggle('active', active);
          if (active) {
            matched = true;
            activeSlide = slide;
          }
        });

        if (!matched && slides.length > 0) {
          var index = Math.max(0, Math.min(pageNumber - 1, slides.length - 1));
          slides.forEach(function(slide, i) {
            var active = i === index;
            slide.classList.toggle('active', active);
            if (active) activeSlide = slide;
          });
        }

        return ensureSlideRendered(activeSlide);
      }

      function setActiveButton(pageNumber) {
        choiceButtons.forEach(function(btn) {
          var active = parseInt(btn.dataset.pageNumber, 10) === pageNumber;
          btn.classList.toggle('btn-choice--active', active);
        });
      }

      function setActivePageNav(pageNumber) {
        pageNavItems.forEach(function(item) {
          var active = parseInt(item.dataset.pageNumber, 10) === pageNumber;
          item.classList.toggle('is-active', active);
          if (active && typeof item.scrollIntoView === 'function') {
            item.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' });
          }
        });
      }

      function presentPage(pageNumber, options) {
        options = options || {};
        if (currentPageNumber !== pageNumber) {
          trackEvent('page_view', { page_number: pageNumber });
        }
        currentPageNumber = pageNumber;
        if (options.syncChoice === false) {
          choiceButtons.forEach(function(btn) {
            btn.classList.remove('btn-choice--active');
          });
        } else {
          setActiveButton(pageNumber);
        }
        setActivePageNav(pageNumber);
        if (presentationStarted) {
          notePageEngagement(findPage(pageNumber));
        }
        return showSlideByPageNumber(pageNumber);
      }

      function appendChatMessage(content, role, audioUrl) {
        if (!messagesContainer || !content) return;

        var messageDiv = document.createElement('div');
        messageDiv.className = 'message message--' + role;
        var roleText = role === 'assistant' ? 'AIアシスタント' : 'あなた';
        var safeContent = String(content).replace(/\n/g, '<br>');

        messageDiv.innerHTML =
          '<div class="message-header"><span class="message-role">' + roleText + '</span></div>' +
          '<div class="message-content">' + safeContent + '</div>';

        messagesContainer.appendChild(messageDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;

        var panelBody = document.getElementById('presentation-chat-panel-body');
        if (panelBody) panelBody.scrollTop = panelBody.scrollHeight;

        if (role === 'assistant' && audioUrl) {
          resetPlayback();
          playUrl(audioUrl, content);
        }
      }

      function segmentsForOpening() {
        if (openingSegments.length > 0) return openingSegments;

        return [
          {
            page_number: parseInt(openingValue('greeting_page'), 10) || 1,
            text: openingValue('greeting_text'),
            audio_url: openingValue('greeting_audio')
          },
          {
            page_number: parseInt(openingValue('company_page'), 10) || 1,
            text: openingValue('company_overview_text'),
            audio_url: openingValue('company_overview_audio')
          },
          {
            page_number: parseInt(openingValue('company_page'), 10) || 1,
            text: openingValue('usage_guide_text'),
            audio_url: openingValue('usage_guide_audio')
          }
        ];
      }

      function playOpeningSegments(segments) {
        return startOpeningQueue(segments);
      }

      function startPresentation() {
        if (presentationStarted) {
          if (hasResumablePlayback()) return resumePlayback();
          // 開始済みのキューを二重起動しない（セグメント飛び・音声二重の原因）
          return Promise.resolve();
        }
        presentationStarted = true;
        updateLastButtonVisibility();
        trackEvent('presentation_start', { page_number: currentPageNumber });
        hideOverlay();
        var segments = segmentsForOpening();
        // 全セグメントを裏で温めつつ、先頭音声だけ待ってから開始する
        segments.forEach(function(segment) {
          preloadAudio(segmentValue(segment, 'audio_url'));
        });
        var firstUrl = segments[0] ? segmentValue(segments[0], 'audio_url') : null;
        var firstPage = segments[0]
          ? (parseInt(segmentValue(segments[0], 'page_number'), 10) || currentPageNumber)
          : currentPageNumber;

        // 描画 → 先頭音声準備 → オープニング再生
        return ensurePdfJsReady(4000).then(function() {
          return afterLayout(function() {
            return presentPage(firstPage, { syncChoice: false });
          });
        }).then(function() {
          return firstUrl ? preloadAudio(firstUrl) : Promise.resolve(null);
        }).then(function() {
          return playOpeningSegments(segments);
        });
      }

      function fetchResponse(options) {
        if (!respondUrl) return Promise.reject(new Error('no respond url'));

        return fetch(respondUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken()
          },
          body: JSON.stringify({
            topic: options.topic || null,
            message: options.message || null,
            page_number: options.pageNumber || null,
            session_key: sessionKey,
            history: conversationHistory.slice(-8)
          })
        }).then(function(response) {
          if (!response.ok) throw new Error('respond error');
          return response.json();
        });
      }

      function pushHistory(role, content) {
        if (!content) return;
        conversationHistory.push({ role: role, content: String(content) });
        if (conversationHistory.length > 16) {
          conversationHistory = conversationHistory.slice(-16);
        }
      }

      function handleTopicChoice(button) {
        var pageNumber = parseInt(button.dataset.pageNumber, 10);
        var topic = button.dataset.topic;
        var label = button.dataset.label;
        if (!pageNumber) return Promise.resolve();

        stopAllSpeech();
        heat.topicClicks += 1;
        trackEvent('topic_click', {
          page_number: pageNumber,
          topic: topic,
          label: label
        });

        var page = findPage(pageNumber);
        notePageEngagement(page);

        if (page && (page.audio_url || page.script)) {
          return presentPage(pageNumber).then(function() {
            return playUrl(page.audio_url, page.script);
          }).then(function() {
            maybeShowSideCtasForPage(page);
            scheduleAutoAdvance(IDLE_BEFORE_AUTO_MS);
          });
        }

        return presentPage(pageNumber).then(function() {
          return fetchResponse({ topic: topic, pageNumber: pageNumber });
        }).then(function(result) {
          if (result.page_number) return presentPage(result.page_number).then(function() { return result; });
          return result;
        }).then(function(result) {
          appendChatMessage(result.text, 'assistant', result.audio_url);
          scheduleAutoAdvance(IDLE_BEFORE_AUTO_MS);
        }).catch(function() {
          appendChatMessage('回答を取得できませんでした。', 'assistant', null);
        });
      }

      function handleFreeText(message) {
        cancelAutoAdvance();
        heat.freeTextCount += 1;
        updateLastButtonVisibility();
        trackEvent('free_text_send', { message: message, page_number: currentPageNumber });
        appendChatMessage(message, 'user');
        pushHistory('user', message);
        return fetchResponse({ message: message }).then(function(result) {
          if (result.page_number) presentPage(result.page_number);
          appendChatMessage(result.text, 'assistant', result.audio_url);
          pushHistory('assistant', result.text);
          scheduleAutoAdvance(IDLE_BEFORE_AUTO_MS);
        }).catch(function() {
          appendChatMessage('回答を取得できませんでした。', 'assistant', null);
        });
      }

      function ensureStarted(thenFn) {
        if (presentationStarted) {
          thenFn();
          return;
        }
        startPresentation().then(thenFn);
      }

      if (chatToggle && chatPanel) {
        chatToggle.addEventListener('click', function() {
          var willOpen = !chatPanel.classList.contains('presentation-chat-panel--open');
          setChatPanelState(willOpen ? 'open' : 'peek');
          trackEvent('chat_toggle', {
            metadata: { open: willOpen },
            page_number: currentPageNumber
          });
        });
      }

      choiceButtons.forEach(function(button) {
        button.addEventListener('click', function() {
          ensureStarted(function() {
            handleTopicChoice(button);
          });
        });
      });

      pageNavItems.forEach(function(item) {
        item.addEventListener('click', function() {
          var pageNumber = parseInt(item.dataset.pageNumber, 10);
          if (!pageNumber) return;
          cancelAutoAdvance();
          // 左ナビはスライド切替のみ。中央の再生ボタン見た目／役割は維持する
          presentPage(pageNumber, { syncChoice: false });
        });
      });

      if (freeTextBtn && freeTextInput) {
        var isComposing = false;

        freeTextInput.addEventListener('compositionstart', function() {
          isComposing = true;
        });

        freeTextInput.addEventListener('compositionend', function() {
          isComposing = false;
        });

        freeTextBtn.addEventListener('click', function() {
          var message = freeTextInput.value.trim();
          if (!message) return;
          freeTextInput.value = '';
          ensureStarted(function() {
            handleFreeText(message);
          });
        });

        freeTextInput.addEventListener('keydown', function(e) {
          // IME変換中のEnter（確定）は送信しない
          if (e.isComposing || isComposing || e.keyCode === 229) return;
          if (e.key === 'Enter') freeTextBtn.click();
        });
      }

      if (startBtn) {
        startBtn.addEventListener('click', function(e) {
          e.preventDefault();
          e.stopPropagation();
          startPresentation();
        });
      }

      if (voiceBtn) {
        voiceBtn.addEventListener('click', function() {
          if (voiceBtn.classList.contains('presentation-play-btn--playing')) {
            pausePlayback();
            cancelAutoAdvance();
            return;
          }

          if (hasResumablePlayback()) {
            resumePlayback();
            return;
          }

          if (!presentationStarted) {
            startPresentation();
            return;
          }

          // 開始後は現在ページの読み上げを再生（左ナビで選んだページも対象）
          playCurrentPageAudio();
        });
      }

      if (overlay) {
        overlay.addEventListener('click', function(e) {
          if (e.target === overlay) startPresentation();
        });
      }

      if (ctaBtn) {
        ctaBtn.addEventListener('click', function(e) {
          handleCtaInteraction(e, 'presentation_bar');
        });
      }

      if (endBtn && modal) {
        endBtn.addEventListener('click', function() {
          showExitModal();
        });
      }

      if (exitContractBtn) {
        exitContractBtn.addEventListener('click', handleExitContractClick);
      }

      [headerSalesCallBtn, exitSalesCallBtn].forEach(function(button) {
        if (button) {
          button.addEventListener('click', handleExitSalesCallClick);
        }
      });

      if (materialsDownloadLink) {
        materialsDownloadLink.addEventListener('click', function() {
          trackEvent('materials_download', {
            page_number: currentPageNumber,
            metadata: { filename: (materials && materials.filename) || null }
          });
        });
      }

      if (modal) {
        modal.addEventListener('click', function(e) {
          if (e.target === modal || e.target.classList.contains('presentation-exit-modal__backdrop') || e.target.getAttribute('data-close-modal') === 'true') {
            e.preventDefault();
            hideExitModal();
          }
        });
      }

      if (submitEvaluationBtn && modal) {
        submitEvaluationBtn.addEventListener('click', function() {
          var rating = document.querySelector('input[name="rating"]:checked');
          var feedbackEl = document.getElementById('feedback');
          if (!rating) {
            showEvaluationRequiredNotice();
            return;
          }

          submitEvaluationBtn.disabled = true;
          finalizeSession('evaluation_submit', rating.value, feedbackEl ? feedbackEl.value : '')
            .then(function() {
              closePresentationWindow();
            })
            .catch(function() {
              submitEvaluationBtn.disabled = false;
              closeLogged = false;
              alert('送信に失敗しました。もう一度お試しください。');
            });
        });
      }

      setChatPanelState('open');
      presentPage(parseInt(openingValue('greeting_page'), 10) || 1);
      showOverlay();

      ensurePdfJsReady(4000).then(function(ready) {
        if (!ready) return;
        // PDF ドキュメントを先読み（開始後のページ切替空白を減らす）
        slides.forEach(function(slide) {
          var pdfUrl = slide.getAttribute('data-pdf-url');
          if (pdfUrl) {
            getPdfDocument(pdfUrl).catch(function() {});
          }
        });
        renderActivePdfSlide();
      });
      // オープニング音声もオーバーレイ表示中に先読み
      segmentsForOpening().forEach(function(segment) {
        preloadAudio(segmentValue(segment, 'audio_url'));
      });

      window.requestAnimationFrame(function() { renderActivePdfSlide(); });
      window.setTimeout(renderActivePdfSlide, 150);
      window.setTimeout(renderActivePdfSlide, 450);
      window.addEventListener('resize', function() {
        if (pdfResizeTimer) window.clearTimeout(pdfResizeTimer);
        pdfResizeTimer = window.setTimeout(renderActivePdfSlide, 100);
      });
      window.addEventListener('orientationchange', function() {
        if (pdfResizeTimer) window.clearTimeout(pdfResizeTimer);
        pdfResizeTimer = window.setTimeout(renderActivePdfSlide, 220);
      });
      if (window.ResizeObserver && documentViewport) {
        var viewportObserver = new ResizeObserver(function() {
          if (pdfResizeTimer) window.clearTimeout(pdfResizeTimer);
          pdfResizeTimer = window.setTimeout(renderActivePdfSlide, 80);
        });
        viewportObserver.observe(documentViewport);
      }

      window.addEventListener('pagehide', function() {
        logSessionClose('pagehide');
      });
      window.addEventListener('beforeunload', function() {
        logSessionClose('beforeunload');
      });
    });
  }

  if (init) {
    init.onPageReady(initDealPresentation);
  } else {
    document.addEventListener('DOMContentLoaded', initDealPresentation);
    document.addEventListener('turbo:load', initDealPresentation);
  }
})();
