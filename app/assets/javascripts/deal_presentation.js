(function() {
  var init = window.MeetiaPageInit;

  function readConfig() {
    var defaults = { pages: [], opening: {}, opening_segments: [], closing: {}, materials: null, public_mode: false, preview_mode: false, home_url: '/', sales_call_url: '', cta: {} };
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
        sales_call_url: data.sales_call_url || '',
        public_mode: !!data.public_mode,
        preview_mode: !!data.preview_mode,
        home_url: data.home_url || '/',
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
      var salesCallUrl = root.dataset.salesCallUrl || config.sales_call_url;
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
      var holdAutoAdvance = false;
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
        // 自由質問中は自動ページ送りしない（回答が途切れて次ページへ飛ぶのを防ぐ）
        if (holdAutoAdvance) return;
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
          if (holdAutoAdvance || !autoAdvance || !autoAdvance.running) return;
          autoAdvance.timer = null;
          continueAutoAdvance();
        }, typeof delayMs === 'number' ? delayMs : IDLE_BEFORE_AUTO_MS);
      }

      function holdPresentationAdvance() {
        // 自動ページ送りだけ止める。再生中の音声は止めない。
        holdAutoAdvance = true;
        cancelAutoAdvance();
      }

      function resumePresentationFlow() {
        holdAutoAdvance = false;
      }

      function continueAutoAdvance() {
        if (holdAutoAdvance || !autoAdvance || !autoAdvance.running || isPaused) {
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
          if (holdAutoAdvance || !autoAdvance || !autoAdvance.running || isPaused) return;
          return playUrl(page.audio_url, page.script, { keepPlayingUi: keepUi });
        }).then(function() {
          if (holdAutoAdvance || !autoAdvance || !autoAdvance.running || isPaused) return;
          maybeShowSideCtasForPage(page);
          autoAdvance.nextIndex = index + 1;
          if (autoAdvance.nextIndex >= autoAdvance.pages.length) {
            return continueAutoAdvance();
          }
          return wait(SEGMENT_GAP_MS).then(function() {
            if (holdAutoAdvance || !autoAdvance || !autoAdvance.running || isPaused) return;
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
        // テキスト表示のみ。音声は下の playUrl で再生（二重再生・無音化を防ぐ）
        appendChatMessage(closingText(), 'assistant', null, { skipAudio: true });

        // PDF描画は待たない（ユーザー操作コンテキスト内で即再生）
        presentPage(pageNumber, { syncChoice: false });
        return playUrl(closingAudioUrl(), closingText()).then(function() {
          showSideCtas();
        });
      }

      function playCurrentPageAudio() {
        resumePresentationFlow();
        isPaused = false;
        cancelAutoAdvance();
        var page = findPage(currentPageNumber);
        if (!page) return Promise.resolve();
        notePageEngagement(page);
        if (page.audio_url || page.script) {
          // PDF描画完了を待たない（描画待ちで再生不能になるのを防ぐ）
          renderActivePdfSlide();
          return playUrl(page.audio_url, page.script).then(function() {
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
        var scrollerWrap = document.getElementById('presentation-choice-scroller-wrap');
        var scroller = document.getElementById('presentation-choice-scroller');
        var prevBtn = document.getElementById('presentation-choice-more-prev');
        var nextBtn = document.getElementById('presentation-choice-more-next');
        if (!scrollerWrap || !scroller || !prevBtn || !nextBtn) return;

        function updateChoiceScroller() {
          var overflow = scroller.scrollWidth > scroller.clientWidth + 2;
          var atStart = scroller.scrollLeft <= 4;
          var atEnd = scroller.scrollLeft + scroller.clientWidth >= scroller.scrollWidth - 4;
          scrollerWrap.classList.toggle('has-overflow-left', overflow && !atStart);
          scrollerWrap.classList.toggle('has-overflow-right', overflow && !atEnd);
          prevBtn.hidden = !overflow || atStart;
          nextBtn.hidden = !overflow || atEnd;
        }

        prevBtn.addEventListener('click', function() {
          var delta = Math.max(180, scroller.clientWidth * 0.65);
          scroller.scrollBy({ left: -delta, behavior: 'smooth' });
        });
        nextBtn.addEventListener('click', function() {
          var delta = Math.max(180, scroller.clientWidth * 0.65);
          scroller.scrollBy({ left: delta, behavior: 'smooth' });
        });

        scroller.addEventListener('scroll', updateChoiceScroller, { passive: true });
        window.addEventListener('resize', updateChoiceScroller);
        updateChoiceScroller();
        choiceScrollerRefreshers.push(updateChoiceScroller);
        // ボタン数が増えた直後にも再計測
        window.requestAnimationFrame(updateChoiceScroller);
        window.setTimeout(updateChoiceScroller, 120);
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

      function fetchWithTimeout(url, options, timeoutMs) {
        var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
        var opts = Object.assign({}, options || {});
        if (controller) opts.signal = controller.signal;

        var timer = null;
        var timedOut = false;
        var timeoutPromise = new Promise(function(_resolve, reject) {
          timer = setTimeout(function() {
            timedOut = true;
            if (controller) {
              try { controller.abort(); } catch (_e) {}
            }
            reject(new Error('timeout'));
          }, typeof timeoutMs === 'number' ? timeoutMs : 10000);
        });

        return Promise.race([
          fetch(url, opts).then(function(response) {
            if (timedOut) throw new Error('timeout');
            return response;
          }),
          timeoutPromise
        ]).then(function(response) {
          if (timer) clearTimeout(timer);
          return response;
        }).catch(function(err) {
          if (timer) clearTimeout(timer);
          throw err;
        });
      }

      function finalizeSession(reason, ratingValue, feedbackValue) {
        if (closeLogged) return Promise.resolve();
        closeLogged = true;

        if (!evaluateUrl) {
          return Promise.reject(new Error('評価の送信先が設定されていません'));
        }

        // evaluate と track_event を並列にすると SQLite で database is locked になる。
        // 評価保存・メール送信は evaluate に一本化し、終了後に session_close だけ送る。
        return fetchWithTimeout(evaluateUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': csrfToken()
          },
          body: JSON.stringify({
            rating: ratingValue,
            feedback: feedbackValue || '',
            session_key: typeof sessionKey !== 'undefined' ? sessionKey : null
          })
        }, 60000).then(function(response) {
          var contentType = (response.headers.get('content-type') || '').toLowerCase();
          return response.json().catch(function() { return {}; }).then(function(payload) {
            if (!response.ok) {
              var message = (payload && payload.errors && payload.errors[0]) || '評価の送信に失敗しました';
              throw new Error(message);
            }
            // 認証切れなどで HTML にリダイレクトされると「成功」扱いになりトップへ飛ぶ事故になる
            if (contentType.indexOf('application/json') === -1) {
              throw new Error('評価の送信に失敗しました。ページを再読み込みしてから再度お試しください。');
            }
            return payload;
          });
        }).then(function() {
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

      function showCompleteScreen(options) {
        var opts = options || {};
        var screen = document.getElementById('presentation-complete-screen');
        var titleEl = document.getElementById('presentation-complete-title');
        var leadEl = document.getElementById('presentation-complete-lead');
        var actionsEl = document.getElementById('presentation-complete-actions');

        pausePlayback();
        hideExitModal();
        hideOverlay();
        document.body.classList.remove('presentation-exit-open', 'presentation-locked');
        document.body.classList.add('presentation-complete-open');

        if (titleEl) titleEl.textContent = opts.title || '商談が終了しました';
        if (leadEl) {
          leadEl.textContent = opts.lead || 'このタブを閉じてください。';
        }
        if (actionsEl) {
          actionsEl.hidden = !!opts.hideActions;
        }

        if (screen) {
          screen.hidden = false;
          screen.setAttribute('aria-hidden', 'false');
        }

        document.title = opts.documentTitle || '商談終了';
      }

      function closePresentationWindow() {
        var isPreview = !!config.preview_mode;
        var isPublic = !!config.public_mode;

        if (isPublic && !isPreview) {
          pausePlayback();
          // 商談ページが一瞬見えるのを防ぐため、先に完了画面を被せてから遷移する
          showCompleteScreen({
            title: '商談が終了しました',
            lead: 'トップページへ移動します…',
            hideActions: true,
            documentTitle: '商談終了'
          });
          var home = (config.home_url || '/').toString();
          var sep = home.indexOf('?') >= 0 ? '&' : '?';
          window.setTimeout(function() {
            window.location.replace(home + sep + 'deal_session=ended');
          }, 400);
          return;
        }

        if (isPreview) {
          showCompleteScreen({
            title: 'プレビュー終了',
            lead: 'プレビューのため、リードは保存されません。このタブを閉じます。',
            hideActions: true,
            documentTitle: 'プレビュー終了'
          });
          window.setTimeout(function() {
            try { window.close(); } catch (_e) {}
          }, 1200);
          return;
        }

        pausePlayback();
        document.body.classList.remove('presentation-exit-open', 'presentation-locked');
        try { window.close(); } catch (_e2) {}
        if (!window.closed) {
          showCompleteScreen({
            title: '商談が終了しました',
            lead: 'このタブを閉じてください。',
            hideActions: true,
            documentTitle: '商談終了'
          });
        }
      }

      function ctaUrl() {
        return (ctaConfig.url || '').trim();
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
        if (e) e.preventDefault();

        var button = e && e.currentTarget;
        var label = (button && (button.dataset.label || button.textContent.trim())) ||
          ctaConfig.exit_sales_call_label ||
          '担当者に繋ぐ';
        var source = button && button.id === 'presentation-sales-call-btn' ? 'header' : 'modal';

        if (!salesCallUrl) {
          alert('担当者への連絡機能が利用できません。');
          return;
        }

        if (button && button.dataset.sending === '1') return;
        if (button) {
          button.dataset.sending = '1';
          button.disabled = true;
        }

        fetch(salesCallUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': csrfToken(),
            'Accept': 'application/json'
          },
          body: JSON.stringify({
            session_key: typeof sessionKey !== 'undefined' ? sessionKey : null,
            source: source,
            label: label
          }),
          credentials: 'same-origin'
        }).then(function(response) {
          return response.json().catch(function() { return {}; }).then(function(data) {
            if (!response.ok) {
              var msg = (data.errors && data.errors[0]) || '送信に失敗しました。しばらくしてから再度お試しください。';
              throw new Error(msg);
            }
            return data;
          });
        }).then(function(data) {
          if (data && data.preview) {
            alert('プレビューのため、担当者へのメールは送信されません。');
          } else {
            alert('担当者へご連絡しました。折り返しご連絡いたします。');
          }
          if (button) {
            button.textContent = '連絡済み';
            button.dataset.sending = '0';
          }
        }).catch(function(err) {
          alert(err.message || '送信に失敗しました。');
          if (button) {
            button.disabled = false;
            button.dataset.sending = '0';
          }
        });
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

          try { window.speechSynthesis.cancel(); } catch (_e) {}

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

          // cancel 直後の speak はブラウザによって無音になることがある
          window.setTimeout(function() {
            if (activeToken !== playbackToken || isPaused) {
              resolve();
              return;
            }
            try {
              window.speechSynthesis.speak(utterance);
            } catch (_speakErr) {
              finish();
            }
          }, 40);
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

          // クリック直後に play() を試し、失敗時のみ準備待ち→再試行/フォールバック
          // （PDF描画待ちでユーザー操作コンテキストが切れると無音になる）
          function attemptPlay() {
            if (token !== playbackToken || isPaused) {
              finish();
              return;
            }
            var playAttempt = audio.play();
            if (playAttempt && playAttempt.then) {
              playAttempt.then(function() {
                // playing
              }).catch(function() {
                whenAudioReady(audio, 2500).then(function(ready) {
                  if (token !== playbackToken || isPaused) {
                    finish();
                    return;
                  }
                  if (!ready && audio.readyState < 2) {
                    fallback();
                    return;
                  }
                  var retry = audio.play();
                  if (retry && retry.catch) retry.catch(fallback);
                });
              });
            }
          }

          attemptPlay();
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
        // PDF描画は待たない。音声を先に再生して無音化を防ぐ
        presentPage(pageNumber, { syncChoice: false });
        if (url) preloadAudio(url);
        return playUrl(url, text, { keepPlayingUi: keepUi }).then(function() {
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

      function showPdfIframeFallback(slide, iframe) {
        if (slide) slide.classList.remove('is-pdf-fitted');
        if (iframe) iframe.style.visibility = 'visible';
      }

      function getPdfDocument(url) {
        if (!url) return Promise.reject(new Error('pdf url missing'));
        return ensurePdfJsReady().then(function(ready) {
          if (!ready || !window.pdfjsLib) return Promise.reject(new Error('pdfjs unavailable'));
          if (!pdfDocCache[url]) {
            // cMap / 標準フォント必須: 未設定だと日本語など埋め込みなし文字が消える
            pdfDocCache[url] = window.pdfjsLib.getDocument({
              url: url,
              withCredentials: true,
              cMapUrl: '/pdfjs/cmaps/',
              cMapPacked: true,
              standardFontDataUrl: '/pdfjs/standard_fonts/'
            }).promise;
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
            showPdfIframeFallback(slide, iframe);
            return;
          }

          var size = slideFitSize(slide);
          var width = size.width;
          var height = size.height;
          if (width < 2 || height < 2) {
            if (attempt >= 10) {
              showPdfIframeFallback(slide, iframe);
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
              // ページ実寸で描画し、余白は CSS object-fit:contain + スライド背景で見せる
              var canvasW = Math.max(1, Math.floor(viewport.width));
              var canvasH = Math.max(1, Math.floor(viewport.height));

              canvas.width = canvasW;
              canvas.height = canvasH;

              var context = canvas.getContext('2d', { alpha: false });
              if (!context) return;

              context.setTransform(1, 0, 0, 1, 0, 0);
              // 透明背景PDFでも黒文字が消えないようページ面は白で塗る
              context.fillStyle = '#ffffff';
              context.fillRect(0, 0, canvasW, canvasH);

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
            if (attempt < 3) {
              showPdfIframeFallback(slide, iframe);
              return wait(120 * (attempt + 1)).then(function() {
                return renderPdfSlide(slide, attempt + 1);
              });
            }
            showPdfIframeFallback(slide, iframe);
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
        // PDF描画は非同期で進める。呼び出し元で await しない（音声再生をユーザー操作内に保つ）
        showSlideByPageNumber(pageNumber);
        return Promise.resolve();
      }

      function appendChatMessage(content, role, audioUrl, options) {
        if (!messagesContainer || !content) return null;
        options = options || {};

        var messageDiv = document.createElement('div');
        messageDiv.className = 'message message--' + role;
        var roleText = role === 'assistant' ? 'AIアシスタント' : 'あなた';
        var safeContent = String(content).replace(/\n/g, '<br>');

        messageDiv.innerHTML =
          '<div class="message-header"><span class="message-role">' + roleText + '</span></div>' +
          '<div class="message-content">' + safeContent + '</div>';

        messagesContainer.appendChild(messageDiv);
        scrollChatToElement(messageDiv);

        // 自由質問の回答では本編音声を止めない（テキスト表示のみ）
        if (role === 'assistant' && !options.skipAudio) {
          resetPlayback();
          playUrl(audioUrl || null, content);
        }
        return messageDiv;
      }

      function scrollChatToElement(el) {
        if (!el) return;
        setChatPanelState('open');
        var panelBody = document.getElementById('presentation-chat-panel-body');
        if (panelBody) panelBody.scrollTop = panelBody.scrollHeight;
        if (messagesContainer) messagesContainer.scrollTop = messagesContainer.scrollHeight;
        try {
          el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        } catch (_e) {
          try { el.scrollIntoView(false); } catch (_e2) {}
        }
      }

      function appendTypingIndicator() {
        if (!messagesContainer) return null;
        setChatPanelState('open');
        var el = document.createElement('div');
        el.className = 'message message--assistant message--typing';
        el.setAttribute('aria-live', 'polite');
        el.setAttribute('aria-label', '回答を用意しています');
        el.innerHTML =
          '<div class="message-header"><span class="message-role">AIアシスタント</span></div>' +
          '<div class="message-content message-typing-dots" aria-hidden="true">' +
            '<span></span><span></span><span></span>' +
          '</div>';
        messagesContainer.appendChild(el);
        scrollChatToElement(el);
        return el;
      }

      function removeTypingIndicator(el) {
        if (el && el.parentNode) el.parentNode.removeChild(el);
      }

      function setFreeTextBusy(busy) {
        if (freeTextBtn) freeTextBtn.disabled = !!busy;
      }

      function handleFreeText(message) {
        // 自動送りだけ止める。本編音声は止めない。
        holdPresentationAdvance();
        heat.freeTextCount += 1;
        updateLastButtonVisibility();
        setFreeTextBusy(true);
        trackEvent('free_text_send', { message: message, page_number: currentPageNumber });
        appendChatMessage(message, 'user');
        pushHistory('user', message);
        var typing = appendTypingIndicator();
        return fetchResponse({ message: message }).then(function(result) {
          removeTypingIndicator(typing);
          appendChatMessage(result.text, 'assistant', null, { skipAudio: true });
          pushHistory('assistant', result.text);
        }).catch(function() {
          removeTypingIndicator(typing);
          appendChatMessage('回答を取得できませんでした。', 'assistant', null, { skipAudio: true });
        }).then(function() {
          setFreeTextBusy(false);
          if (freeTextInput) freeTextInput.focus();
        });
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
        // 全セグメントを裏で温めつつ、先頭から即再生（PDF待ちで無音になるのを防ぐ）
        segments.forEach(function(segment) {
          preloadAudio(segmentValue(segment, 'audio_url'));
        });
        ensurePdfJsReady(4000).then(function() {
          renderActivePdfSlide();
        });
        return playOpeningSegments(segments);
      }

      function fetchResponse(options) {
        if (!respondUrl) return Promise.reject(new Error('no respond url'));

        return fetchWithTimeout(respondUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': csrfToken()
          },
          body: JSON.stringify({
            topic: options.topic || null,
            message: options.message || null,
            page_number: options.pageNumber || null,
            session_key: sessionKey,
            history: conversationHistory.slice(-8)
          })
        }, 15000).then(function(response) {
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

        resumePresentationFlow();
        stopAllSpeech();
        heat.topicClicks += 1;
        trackEvent('topic_click', {
          page_number: pageNumber,
          topic: topic,
          label: label
        });

        var page = findPage(pageNumber);
        notePageEngagement(page);
        // スライド切替は即時。音声はクリック直後に開始（PDF待ちで無音になるのを防ぐ）
        presentPage(pageNumber);

        if (page && (page.audio_url || page.script)) {
          return playUrl(page.audio_url, page.script).then(function() {
            maybeShowSideCtasForPage(page);
            scheduleAutoAdvance(IDLE_BEFORE_AUTO_MS);
          });
        }

        return fetchResponse({ topic: topic, pageNumber: pageNumber }).then(function(result) {
          if (result.page_number) presentPage(result.page_number);
          appendChatMessage(result.text, 'assistant', result.audio_url);
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
        var freeTextSending = false;

        freeTextInput.addEventListener('compositionstart', function() {
          isComposing = true;
        });

        freeTextInput.addEventListener('compositionend', function() {
          isComposing = false;
        });

        // 入力中は自動ページ送りだけ止める（音声は止めない）
        freeTextInput.addEventListener('focus', function() {
          holdPresentationAdvance();
        });
        freeTextInput.addEventListener('input', function() {
          if (!holdAutoAdvance) holdPresentationAdvance();
        });

        freeTextBtn.addEventListener('click', function() {
          var message = freeTextInput.value.trim();
          if (!message || freeTextSending) return;
          freeTextSending = true;
          freeTextInput.value = '';
          ensureStarted(function() {
            handleFreeText(message).then(function() {
              freeTextSending = false;
            }, function() {
              freeTextSending = false;
            });
          });
        });

        freeTextInput.addEventListener('keydown', function(e) {
          // IME変換中のEnter（確定）は送信しない
          if (e.isComposing || isComposing || e.keyCode === 229) return;
          if (e.key === 'Enter') {
            e.preventDefault();
            freeTextBtn.click();
          }
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
          var actuallyPlaying = !!(
            (currentAudio && !currentAudio.paused && !currentAudio.ended) ||
            (isSpeechActive() && !window.speechSynthesis.paused) ||
            (openingQueue && openingQueue.running && !isPaused)
          );

          // 見た目だけ playing のときは一時停止扱いにせず、再生を開始する
          if (actuallyPlaying) {
            pausePlayback();
            cancelAutoAdvance();
            return;
          }

          setPlayButtonPlaying(false);
          isPaused = false;

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

          if (submitEvaluationBtn.dataset.sending === '1') return;
          submitEvaluationBtn.dataset.sending = '1';
          submitEvaluationBtn.disabled = true;
          var originalLabel = submitEvaluationBtn.textContent;
          submitEvaluationBtn.textContent = '送信中…';

          finalizeSession('evaluation_submit', rating.value, feedbackEl ? feedbackEl.value : '')
            .then(function() {
              closePresentationWindow();
            })
            .catch(function(err) {
              submitEvaluationBtn.dataset.sending = '0';
              submitEvaluationBtn.disabled = false;
              submitEvaluationBtn.textContent = originalLabel;
              closeLogged = false;
              var msg = (err && err.message) ? err.message : '送信に失敗しました。もう一度お試しください。';
              if (msg === 'timeout') msg = '送信がタイムアウトしました。通信状況を確認して再度お試しください。';
              alert(msg);
            });
        });
      }

      setChatPanelState('open');
      presentPage(parseInt(openingValue('greeting_page'), 10) || 1);
      showOverlay();

      ensurePdfJsReady(4000).then(function(ready) {
        if (!ready) return;
        // 全ページ先読みは重いので、表示中スライドだけ描画する
        renderActivePdfSlide();
      });
      // オープニング音声もオーバーレイ表示中に先読み
      segmentsForOpening().forEach(function(segment) {
        preloadAudio(segmentValue(segment, 'audio_url'));
      });

      window.requestAnimationFrame(function() { renderActivePdfSlide(); });
      window.setTimeout(renderActivePdfSlide, 200);
      window.addEventListener('resize', function() {
        if (pdfResizeTimer) window.clearTimeout(pdfResizeTimer);
        pdfResizeTimer = window.setTimeout(renderActivePdfSlide, 200);
      });
      window.addEventListener('orientationchange', function() {
        if (pdfResizeTimer) window.clearTimeout(pdfResizeTimer);
        pdfResizeTimer = window.setTimeout(renderActivePdfSlide, 280);
      });
      if (window.ResizeObserver && documentViewport) {
        var viewportObserver = new ResizeObserver(function() {
          if (pdfResizeTimer) window.clearTimeout(pdfResizeTimer);
          pdfResizeTimer = window.setTimeout(renderActivePdfSlide, 200);
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
