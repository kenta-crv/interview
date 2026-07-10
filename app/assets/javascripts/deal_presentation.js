(function() {
  var init = window.MeetiaPageInit;

  function readConfig() {
    var defaults = { pages: [], opening: {}, opening_segments: [], public_mode: false, cta: {} };
    var el = document.getElementById('deal-presentation-config');
    if (!el) return defaults;

    try {
      var data = JSON.parse(el.textContent);
      return {
        pages: data.pages || [],
        opening: data.opening || {},
        opening_segments: data.opening_segments || [],
        respond_url: data.respond_url || '',
        evaluate_url: data.evaluate_url || '',
        track_url: data.track_url || '',
        public_mode: !!data.public_mode,
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
      var respondUrl = root.dataset.respondUrl || config.respond_url;
      var evaluateUrl = root.dataset.evaluateUrl || config.evaluate_url;
      var trackUrl = root.dataset.trackUrl || config.track_url;
      var slides = root.querySelectorAll('.document-slide');
      var choiceButtons = root.querySelectorAll('.btn-choice');
      var pageNavItems = root.querySelectorAll('.presentation-page-nav__item');
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
      var exitSalesCallBtn = document.getElementById('exit-sales-call-btn');
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
        if (currentAudio) {
          currentAudio.pause();
          currentAudio = null;
        }
        if ('speechSynthesis' in window) window.speechSynthesis.cancel();
        openingQueue = null;
        setPlayButtonPlaying(false);
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

      function initChoiceScroller(options) {
        var scrollerWrap = document.getElementById(options.wrapId);
        var scroller = document.getElementById(options.scrollerId);
        var moreBtn = document.getElementById(options.moreId);
        if (!scrollerWrap || !scroller || !moreBtn) return;

        function alignLeftScroller() {
          if (options.side !== 'left') return;
          scroller.scrollLeft = Math.max(0, scroller.scrollWidth - scroller.clientWidth);
        }

        function updateChoiceScroller() {
          var overflow = scroller.scrollWidth > scroller.clientWidth + 2;

          if (options.side === 'left') {
            var atStart = scroller.scrollLeft <= 4;
            scrollerWrap.classList.toggle('has-overflow', overflow && !atStart);
            moreBtn.hidden = !overflow || atStart;
            return;
          }

          var atEnd = scroller.scrollLeft + scroller.clientWidth >= scroller.scrollWidth - 4;
          scrollerWrap.classList.toggle('has-overflow', overflow && !atEnd);
          moreBtn.hidden = !overflow || atEnd;
        }

        moreBtn.addEventListener('click', function() {
          var delta = Math.max(180, scroller.clientWidth * 0.65);
          scroller.scrollBy({
            left: options.side === 'left' ? -delta : delta,
            behavior: 'smooth'
          });
        });

        scroller.addEventListener('scroll', updateChoiceScroller, { passive: true });
        window.addEventListener('resize', function() {
          alignLeftScroller();
          updateChoiceScroller();
        });

        alignLeftScroller();
        updateChoiceScroller();
      }

      initChoiceScroller({
        wrapId: 'presentation-choice-scroller-wrap-left',
        scrollerId: 'presentation-choice-scroller-left',
        moreId: 'presentation-choice-more-left',
        side: 'left'
      });

      initChoiceScroller({
        wrapId: 'presentation-choice-scroller-wrap-right',
        scrollerId: 'presentation-choice-scroller-right',
        moreId: 'presentation-choice-more-right',
        side: 'right'
      });

      var sessionKey = (function() {
        var storageKey = 'deal-presentation-session';
        var existing = null;
        try { existing = sessionStorage.getItem(storageKey); } catch (_e) {}
        if (existing) return existing;
        var generated = 'sess_' + Date.now().toString(36) + '_' + Math.random().toString(36).slice(2, 10);
        try { sessionStorage.setItem(storageKey, generated); } catch (_e2) {}
        return generated;
      })();
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
          tasks.push(fetch(evaluateUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': csrfToken()
            },
            body: JSON.stringify({
              rating: ratingValue,
              feedback: feedbackValue || ''
            })
          }));
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
        document.body.classList.remove('presentation-exit-open', 'presentation-locked');
        try { window.close(); } catch (_e) {}
        if (!window.closed) {
          document.body.innerHTML = '<div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0a0b1e;color:#fff;font-family:sans-serif;text-align:center;padding:24px;"><div><h1 style="font-size:1.5rem;margin-bottom:12px;">商談が終了しました</h1><p style="color:#94a3b8;margin:0;">このタブを閉じてください。</p></div></div>';
          document.title = '商談終了';
        }
      }

      function ctaUrl() {
        return (ctaConfig.url || '').trim();
      }

      function openCtaUrl(source) {
        var url = ctaUrl();
        if (!url) {
          alert('契約ページのURLが設定されていません。');
          return false;
        }
        var opened = window.open(url, '_blank', 'noopener,noreferrer');
        if (!opened) {
          window.location.assign(url);
        }
        return true;
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

      function handleExitSalesCallClick() {
        var label = ctaConfig.exit_sales_call_label || (exitSalesCallBtn && exitSalesCallBtn.textContent.trim()) || '担当者と商談を希望';
        trackEvent('exit_sales_call_click', {
          label: label,
          metadata: { status: 'pending_implementation' }
        });
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

      function playUrl(url, textFallback) {
        return new Promise(function(resolve) {
          var token = ++playbackToken;
          isPaused = false;

          function finish() {
            if (token !== playbackToken) {
              resolve();
              return;
            }
            if (isPaused) {
              resolve();
              return;
            }
            setAvatarSpeaking(false);
            setPlayButtonPlaying(false);
            resolve();
          }

          if (!url) {
            speakText(textFallback, token).then(resolve);
            return;
          }

          stopCurrentAudio(true);

          var audio = new Audio(url);
          currentAudio = audio;
          setAvatarSpeaking(true);
          setPlayButtonPlaying(true);

          function finishAudio() {
            if (isPaused) {
              resolve();
              return;
            }
            setAvatarSpeaking(false);
            if (currentAudio === audio) currentAudio = null;
            finish();
          }

          function fallback() {
            if (textFallback) speakText(textFallback, token).then(resolve);
            else finishAudio();
          }

          audio.addEventListener('ended', finishAudio, { once: true });
          audio.addEventListener('error', fallback, { once: true });

          var playAttempt = audio.play();
          if (playAttempt && playAttempt.catch) {
            playAttempt.catch(fallback);
          }
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
          return Promise.resolve();
        }

        var segment = openingQueue.segments[index];
        var pageNumber = parseInt(segmentValue(segment, 'page_number'), 10) || 1;
        var url = segmentValue(segment, 'audio_url');
        var text = segmentValue(segment, 'text');
        presentPage(pageNumber);

        return playUrl(url, text).then(function() {
          if (isPaused || !openingQueue || !openingQueue.running) return;
          openingQueue.nextIndex = index + 1;
          return continueOpeningQueue();
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

      function setActivePageNav(pageNumber) {
        pageNavItems.forEach(function(item) {
          var active = parseInt(item.dataset.pageNumber, 10) === pageNumber;
          item.classList.toggle('is-active', active);
          if (active && typeof item.scrollIntoView === 'function') {
            item.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
          }
        });
      }

      function presentPage(pageNumber) {
        if (currentPageNumber !== pageNumber) {
          trackEvent('page_view', { page_number: pageNumber });
        }
        currentPageNumber = pageNumber;
        showSlideByPageNumber(pageNumber);
        setActiveButton(pageNumber);
        setActivePageNav(pageNumber);
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
          if (openingQueue && openingQueue.running) return continueOpeningQueue();
          return Promise.resolve();
        }
        presentationStarted = true;
        trackEvent('presentation_start', { page_number: currentPageNumber });
        hideOverlay();
        return playOpeningSegments(segmentsForOpening());
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
            page_number: options.pageNumber || null
          })
        }).then(function(response) {
          if (!response.ok) throw new Error('respond error');
          return response.json();
        });
      }

      function handleTopicChoice(button) {
        var pageNumber = parseInt(button.dataset.pageNumber, 10);
        var topic = button.dataset.topic;
        var label = button.dataset.label;
        if (!pageNumber) return Promise.resolve();

        trackEvent('topic_click', {
          page_number: pageNumber,
          topic: topic,
          label: label
        });

        presentPage(pageNumber);
        resetPlayback();
        var page = pages.find(function(p) { return p.page_number === pageNumber; });

        if (page && page.audio_url) {
          return playUrl(page.audio_url, page.script);
        }

        return fetchResponse({ topic: topic, pageNumber: pageNumber }).then(function(result) {
          if (result.page_number) presentPage(result.page_number);
          appendChatMessage(result.text, 'assistant', result.audio_url);
        });
      }

      function handleFreeText(message) {
        trackEvent('free_text_send', { message: message, page_number: currentPageNumber });
        appendChatMessage(message, 'user');
        return fetchResponse({ message: message }).then(function(result) {
          if (result.page_number) presentPage(result.page_number);
          appendChatMessage(result.text, 'assistant', result.audio_url);
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
          presentPage(pageNumber);
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
            return;
          }

          if (hasResumablePlayback()) {
            resumePlayback();
            return;
          }

          if (!presentationStarted) {
            startPresentation();
          }
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

      if (exitSalesCallBtn) {
        exitSalesCallBtn.addEventListener('click', handleExitSalesCallClick);
      }

      if (modal) {
        modal.addEventListener('click', function(e) {
          if (e.target === modal || e.target.classList.contains('presentation-exit-modal__backdrop')) {
            e.preventDefault();
            showEvaluationRequiredNotice();
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
