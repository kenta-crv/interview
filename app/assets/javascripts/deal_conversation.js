(function() {
  var TOPIC_FALLBACKS = {
    overview: 'サービス概要について説明します。私たちのAI商談システムは、資料に基づいてご案内する革新的なソリューションです。',
    pricing: '料金プランについて説明します。基本プランから企業規模に応じた柔軟なプランをご用意しています。',
    trial: 'トライアルについて説明します。無料トライアルをご用意しており、主要機能をお試しいただけます。',
    contract: '契約フローについて説明します。オンラインで完結するシンプルな手続きとなっており、スムーズに利用開始できます。'
  };

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

  function initDealConversation() {
    var root = document.querySelector('[data-deal-conversation]');
    if (!root || root.dataset.bound === 'true') return;
    root.dataset.bound = 'true';

    var dealId = root.dataset.dealId;
    var respondUrl = root.dataset.respondUrl;
    var evaluateUrl = root.dataset.evaluateUrl;
    var messagesContainer = document.getElementById('conversation-messages');
    var freeTextInput = document.getElementById('free-text-input');
    var freeTextBtn = document.getElementById('send-free-text');
    var endBtn = document.getElementById('end-conversation-btn');
    var modal = document.getElementById('evaluation-modal');
    var closeModalBtn = document.getElementById('close-modal');
    var submitEvaluationBtn = document.getElementById('submit-evaluation');

    if (!messagesContainer) return;

    var currentAudio = null;

    function playAudio(url) {
      if (!url) return;
      if (currentAudio) currentAudio.pause();
      currentAudio = new Audio(url);
      currentAudio.play().catch(function() {});
    }

    function speakText(text) {
      if (!('speechSynthesis' in window) || !text) return;
      window.speechSynthesis.cancel();
      var utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = 'ja-JP';
      window.speechSynthesis.speak(utterance);
    }

    function addMessage(content, role, audioUrl) {
      var messageDiv = document.createElement('div');
      messageDiv.className = 'message message--' + role;
      var time = new Date().toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' });
      var roleText = role === 'assistant' ? 'AIアシスタント' : 'あなた';
      var safeContent = String(content || '').replace(/\n/g, '<br>');
      var safeText = String(content || '').replace(/"/g, '&quot;').replace(/\n/g, ' ');

      messageDiv.innerHTML =
        '<div class="message-header">' +
          '<span class="message-role">' + roleText + '</span>' +
          '<span class="message-time">' + time + '</span>' +
        '</div>' +
        '<div class="message-content">' + safeContent + '</div>' +
        (role === 'assistant'
          ? '<div class="message-actions"><button type="button" class="btn-audio" data-text="' + safeText + '" data-audio-url="' + (audioUrl || '') + '" title="音声再生">🔊</button></div>'
          : '');

      messagesContainer.appendChild(messageDiv);
      messagesContainer.scrollTop = messagesContainer.scrollHeight;

      if (role === 'assistant' && audioUrl) playAudio(audioUrl);
    }

    function showLoading() {
      var loadingDiv = document.createElement('div');
      loadingDiv.className = 'message message--assistant loading';
      loadingDiv.id = 'loading-message';
      loadingDiv.innerHTML = '<div class="message-content">入力中...</div>';
      messagesContainer.appendChild(loadingDiv);
    }

    function hideLoading() {
      var loadingEl = document.getElementById('loading-message');
      if (loadingEl) loadingEl.remove();
    }

    function fallbackTopicResponse(topic) {
      return TOPIC_FALLBACKS[topic] || '申し訳ありません。そのトピックについての情報を取得できませんでした。';
    }

    async function fetchViaApi(topic, message, pageNumber) {
      var payload = { deal_id: dealId };
      if (topic) payload.topic = topic;
      if (message) payload.message = message;
      if (pageNumber) payload.page_number = pageNumber;

      var response = await fetch('/api/ai_response', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken()
        },
        body: JSON.stringify(payload)
      });

      if (!response.ok) throw new Error('api error');
      var data = await response.json();
      return {
        text: data.response || data.text,
        audio_url: data.audio_url
      };
    }

    async function fetchViaRespond(topic, message, pageNumber) {
      if (!respondUrl) throw new Error('no respond url');

      var response = await fetch(respondUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken()
        },
        body: JSON.stringify({
          topic: topic,
          message: message,
          page_number: pageNumber
        })
      });

      if (!response.ok) throw new Error('respond error');
      var data = await response.json();
      return {
        text: data.text || data.response,
        audio_url: data.audio_url
      };
    }

    async function requestResponse(options) {
      showLoading();
      try {
        var result;
        try {
          result = await fetchViaRespond(options.topic, options.message, options.pageNumber);
        } catch (_respondError) {
          result = await fetchViaApi(options.topic, options.message, options.pageNumber);
        }

        hideLoading();
        addMessage(result.text || fallbackTopicResponse(options.topic), 'assistant', result.audio_url);
      } catch (error) {
        hideLoading();
        var fallback = options.message || fallbackTopicResponse(options.topic);
        addMessage(fallback, 'assistant', null);
      }
    }

    root.querySelectorAll('.btn-topic').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var label = this.dataset.label || this.textContent;
        addMessage(label, 'user');
        requestResponse({
          topic: this.dataset.topic,
          pageNumber: this.dataset.pageNumber
        });
      });
    });

    root.querySelectorAll('.btn-toggle-doc').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var docId = this.dataset.docId;
        var preview = document.getElementById('preview-' + docId);
        if (!preview) return;
        var isHidden = preview.style.display === 'none';
        root.querySelectorAll('.document-preview').forEach(function(p) { p.style.display = 'none'; });
        preview.style.display = isHidden ? 'block' : 'none';
        this.textContent = isHidden ? '▲' : '▼';
      });
    });

    root.addEventListener('click', function(e) {
      if (!e.target.classList.contains('btn-audio')) return;
      var audioUrl = e.target.dataset.audioUrl;
      if (audioUrl) {
        playAudio(audioUrl);
      } else {
        speakText(e.target.dataset.text);
      }
    });

    if (freeTextBtn && freeTextInput) {
      freeTextBtn.addEventListener('click', function() {
        var message = freeTextInput.value.trim();
        if (!message) return;
        addMessage(message, 'user');
        freeTextInput.value = '';
        requestResponse({ message: message });
      });

      freeTextInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter') freeTextBtn.click();
      });
    }

    if (endBtn && modal) {
      endBtn.addEventListener('click', function() {
        modal.style.display = 'block';
      });
    }

    if (closeModalBtn && modal) {
      closeModalBtn.addEventListener('click', function() {
        modal.style.display = 'none';
      });
      modal.addEventListener('click', function(e) {
        if (e.target === modal) modal.style.display = 'none';
      });
    }

    if (submitEvaluationBtn && modal) {
      submitEvaluationBtn.addEventListener('click', async function() {
        var rating = document.querySelector('input[name="rating"]:checked');
        var feedbackEl = document.getElementById('feedback');
        if (!rating) {
          alert('満足度を選択してください');
          return;
        }

        if (evaluateUrl) {
          try {
            await fetch(evaluateUrl, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': csrfToken()
              },
              body: JSON.stringify({
                rating: rating.value,
                feedback: feedbackEl ? feedbackEl.value : ''
              })
            });
          } catch (_e) {}
        }

        modal.style.display = 'none';
        alert('評価を送信しました。ありがとうございました！');
      });
    }
  }

  document.addEventListener('turbo:before-cache', function() {
    var root = document.querySelector('[data-deal-conversation]');
    if (root) delete root.dataset.bound;
  });

  onPageReady(initDealConversation);
})();
