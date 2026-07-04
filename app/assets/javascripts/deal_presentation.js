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
      var avatar = root.querySelector('.avatar-img-2');
      var overlay = document.getElementById('presentation-start-overlay');
      var startBtn = document.getElementById('presentation-start-btn');
      var chatPanel = document.getElementById('presentation-chat-panel');
      var chatToggle = document.getElementById('presentation-chat-toggle');
      var messagesContainer = document.getElementById('conversation-messages');
      var freeTextInput = document.getElementById('free-text-input');
      var freeTextBtn = document.getElementById('send-free-text');
      var endBtn = document.getElementById('end-conversation-btn');
      var modal = document.getElementById('evaluation-modal');
      var closeModalBtn = document.getElementById('close-modal');
      var dismissModalBtn = document.getElementById('dismiss-modal');
      var submitEvaluationBtn = document.getElementById('submit-evaluation');
      var ctaBtn = document.getElementById('presentation-cta-btn');
      var exitContractBtn = document.getElementById('exit-contract-btn');
      var exitSalesCallBtn = document.getElementById('exit-sales-call-btn');
      var ctaConfig = config.cta || {};
      var currentAudio = null;
      var presentationStarted = false;
      var currentPageNumber = parseInt((opening.greeting_page || opening['greeting-page'] || 1), 10);
      var sessionStartedAt = Date.now();
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
        if (closeLogged) return;
        closeLogged = true;
        trackEvent('session_close', {
          metadata: {
            reason: reason,
            presentation_started: presentationStarted,
            current_page_number: currentPageNumber,
            duration_ms: Date.now() - sessionStartedAt
          }
        });
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
        modal.classList.add('presentation-exit-modal--open');
        document.body.classList.add('presentation-exit-open');
        document.body.classList.remove('presentation-locked');
      }

      function hideExitModal() {
        if (!modal) return;
        modal.classList.remove('presentation-exit-modal--open');
        document.body.classList.remove('presentation-exit-open');
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

        hideExitModal();
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

      function setAvatarSpeaking(active) {
        if (!avatar) return;
        avatar.classList.toggle('avatar-img-2--speaking', active);
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

      function setChatPanelOpen(open) {
        if (!chatPanel || !chatToggle) return;
        chatPanel.classList.toggle('presentation-chat-panel--closed', !open);
        chatToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      }

      function stopCurrentAudio() {
        if (!currentAudio) return;
        currentAudio.pause();
        currentAudio = null;
      }

      function speakText(text) {
        return new Promise(function(resolve) {
          if (!text || !('speechSynthesis' in window)) {
            resolve();
            return;
          }

          window.speechSynthesis.cancel();
          var utterance = new SpeechSynthesisUtterance(text);
          utterance.lang = 'ja-JP';
          utterance.onend = function() {
            setAvatarSpeaking(false);
            resolve();
          };
          utterance.onerror = utterance.onend;
          setAvatarSpeaking(true);
          window.speechSynthesis.speak(utterance);
        });
      }

      function playUrl(url, textFallback) {
        return new Promise(function(resolve) {
          if (!url) {
            if (textFallback) speakText(textFallback).then(resolve);
            else resolve();
            return;
          }

          stopCurrentAudio();

          var audio = new Audio(url);
          currentAudio = audio;
          setAvatarSpeaking(true);

          function finish() {
            setAvatarSpeaking(false);
            if (currentAudio === audio) currentAudio = null;
            resolve();
          }

          function fallback() {
            if (textFallback) speakText(textFallback).then(finish);
            else finish();
          }

          audio.addEventListener('ended', finish, { once: true });
          audio.addEventListener('error', fallback, { once: true });

          var playAttempt = audio.play();
          if (playAttempt && playAttempt.catch) {
            playAttempt.catch(fallback);
          }
        });
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

      function presentPage(pageNumber) {
        if (currentPageNumber !== pageNumber) {
          trackEvent('page_view', { page_number: pageNumber });
        }
        currentPageNumber = pageNumber;
        showSlideByPageNumber(pageNumber);
        setActiveButton(pageNumber);
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

        if (role === 'assistant' && audioUrl) playUrl(audioUrl, content);
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
        return segments.reduce(function(chain, segment) {
          return chain.then(function() {
            var pageNumber = parseInt(segmentValue(segment, 'page_number'), 10) || 1;
            var url = segmentValue(segment, 'audio_url');
            var text = segmentValue(segment, 'text');
            presentPage(pageNumber);
            return playUrl(url, text);
          });
        }, Promise.resolve());
      }

      function startPresentation() {
        if (presentationStarted) return Promise.resolve();
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
          var isClosed = chatPanel.classList.contains('presentation-chat-panel--closed');
          setChatPanelOpen(isClosed);
          trackEvent('chat_toggle', {
            metadata: { open: isClosed },
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

      if (freeTextBtn && freeTextInput) {
        freeTextBtn.addEventListener('click', function() {
          var message = freeTextInput.value.trim();
          if (!message) return;
          freeTextInput.value = '';
          ensureStarted(function() {
            handleFreeText(message);
          });
        });

        freeTextInput.addEventListener('keydown', function(e) {
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
          trackEvent('session_close', {
            metadata: {
              reason: 'end_button',
              presentation_started: presentationStarted,
              current_page_number: currentPageNumber,
              duration_ms: Date.now() - sessionStartedAt
            }
          });
          closeLogged = true;
          showExitModal();
        });
      }

      if (exitContractBtn) {
        exitContractBtn.addEventListener('click', handleExitContractClick);
      }

      if (exitSalesCallBtn) {
        exitSalesCallBtn.addEventListener('click', handleExitSalesCallClick);
      }

      [closeModalBtn, dismissModalBtn].forEach(function(btn) {
        if (!btn) return;
        btn.addEventListener('click', hideExitModal);
      });

      if (modal) {
        modal.querySelectorAll('[data-close-modal]').forEach(function(el) {
          el.addEventListener('click', hideExitModal);
        });
        modal.addEventListener('click', function(e) {
          if (e.target === modal || e.target.classList.contains('presentation-exit-modal__backdrop')) {
            hideExitModal();
          }
        });
      }

      if (submitEvaluationBtn && modal) {
        submitEvaluationBtn.addEventListener('click', function() {
          var rating = document.querySelector('input[name="rating"]:checked');
          var feedbackEl = document.getElementById('feedback');
          if (!rating) {
            alert('満足度を選択してください');
            return;
          }

          if (evaluateUrl) {
            trackEvent('evaluation_submit', {
              metadata: {
                rating: rating.value,
                feedback: feedbackEl ? feedbackEl.value : ''
              }
            });
            fetch(evaluateUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': csrfToken()
              },
              body: JSON.stringify({
                rating: rating.value,
                feedback: feedbackEl ? feedbackEl.value : ''
              })
            }).catch(function() {});
          }

          hideExitModal();
          alert('評価を送信しました。ありがとうございました！');
        });
      }

      setChatPanelOpen(false);
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
