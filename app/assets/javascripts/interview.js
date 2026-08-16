// app/assets/javascripts/interview.js
(function() {
  function initInterviewPortal() {
    const steps = document.querySelectorAll('.step');
    const stepIndicators = document.querySelectorAll('.step-indicator__item');
    if (!steps.length) return;

    function byId(id) { return document.getElementById(id); }

    var I18N = {};
    try {
      var i18nEl = document.getElementById('interview-i18n');
      if (i18nEl) I18N = JSON.parse(i18nEl.textContent) || {};
    } catch (_e) {}

    function t(key, vars) {
      var s = (I18N[key] != null && String(I18N[key]).length) ? String(I18N[key]) : key;
      if (vars) {
        Object.keys(vars).forEach(function(k) {
          s = s.split('%{' + k + '}').join(vars[k]);
        });
      }
      return s;
    }

    // Step 1 elements
    const startBtn = byId('start_interview');
    const resumeBtn = byId('resume_interview');
    if (!startBtn) return;

    // Step 2 elements
    const statusEl = byId('interview_status');
    const progressBar = byId('progress_bar');
    const progressText = byId('progress_text');
    const questionCount = byId('question_count');
    const questionText = byId('question_text');
    const questionAudio = byId('question_audio');
    const mcqOptions = byId('mcq_options');
    const recordStart = byId('record_start');
    const recordStop = byId('record_stop');
    const recordStatus = byId('record_status');
    const recordedAudio = byId('recorded_audio');
    const submitBtn = byId('submit_answer');
    const completeBtn = byId('complete_interview');

    // Step 3 elements
    const resultStatus = byId('result_status');
    const resultFinal = byId('result_final_status');
    const resultAvg = byId('result_avg_score');
    const resultQs = byId('result_qs');
    const resultSummary = byId('result_summary');
    const resultStrengths = byId('result_strengths');
    const resultWeaknesses = byId('result_weaknesses');
    const resultRecommendation = byId('result_recommendation');
    const backToStartBtn = byId('back_to_start');

    let interviewId = null;
    let currentQuestion = null;
    let mediaRecorder = null;
    let recordedChunks = [];
    let recordedBlob = null;
    let selectedOption = null;
    let isSubmitting = false;

    // ===== API通信ヘルパー =====
    function authHeaders(extra) {
      var headers = extra || {};
      if (typeof accessToken !== 'undefined' && accessToken) {
        headers['X-Interview-Token'] = accessToken;
      }
      return headers;
    }

    async function apiRequest(url, options) {
      options = options || {};
      options.headers = authHeaders(options.headers || {});

      var res;
      try {
        res = await fetch(url, options);
      } catch (netErr) {
        throw new Error(t('network_error', { message: netErr.message }));
      }

      // 認証エラー(401)またはレスポンスURLがログイン画面を指している場合、
      // fetchの内部フリーズを回避してブラウザごと強制遷移させる
      if (res.status === 401 || res.url.indexOf('/users/sign_in') !== -1) {
        clearSavedInterview();
        alert(t('session_expired'));
        window.location.href = '/users/sign_in';
        return { status: res.status, ok: false, data: { success: false } };
      }

      var contentType = res.headers.get('content-type') || '';
      var data;
      if (contentType.indexOf('application/json') !== -1) {
        try {
          data = await res.json();
        } catch (e) {
          throw new Error(t('parse_failed'));
        }
      } else {
        data = { success: false, error: t('server_error', { status: res.status }) };
      }

      if (res.status === 410 && data.reason === 'timeout') {
        data.__timeout = true;
      }
      if (res.status === 401) {
        data.__unauthorized = true;
      }

      if (data.__timeout || data.__unauthorized) {
        clearSavedInterview();
      }

      return { status: res.status, ok: res.ok, data: data };
    }

    // ===== ステップ制御 =====
    function showStep(n) {
      steps.forEach(function(s) { s.classList.remove('active'); });
      stepIndicators.forEach(function(item) { item.classList.remove('active', 'done'); });

      var target = byId('step-' + n);
      if (target) target.classList.add('active');

      stepIndicators.forEach(function(item) {
        var stepNum = parseInt(item.getAttribute('data-step'), 10);
        if (stepNum < n) item.classList.add('done');
        if (stepNum === n) item.classList.add('active');
      });
    }

    // ===== ステータス表示 =====
    function setStatus(msg) {
      if (statusEl) statusEl.textContent = msg;
    }

    function setProgress(progress, answered, total) {
      var pct = Math.max(0, Math.min(100, progress || 0));
      if (progressBar) progressBar.style.width = pct + '%';
      if (progressText) progressText.textContent = Math.round(pct) + '%';
      if (questionCount) questionCount.textContent = t('question_count', { answered: answered || 0, total: total || 0 });
    }

    // ===== localStorage =====
    function saveInterview(id, language) {
      localStorage.setItem('aiInterviewId', String(id));
      localStorage.setItem('aiInterviewLanguage', String(language || 'ja'));
    }

    function loadSavedInterview() {
      var id = localStorage.getItem('aiInterviewId');
      return id ? parseInt(id, 10) : null;
    }

    function clearSavedInterview() {
      localStorage.removeItem('aiInterviewId');
      localStorage.removeItem('aiInterviewLanguage');
    }

    // ===== API calls =====
    async function startInterview() {
      var situationId = byId('situation_id').value;
      var language = byId('language').value || 'ja';

      if (!situationId) {
        alert(t('pick_form'));
        return;
      }

      startBtn.disabled = true;
      startBtn.textContent = t('starting');

      try {
        var result = await apiRequest('/api/interviews/start', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ situation_id: parseInt(situationId, 10), language: language })
        });
        var data = result.data;

        if (data.__timeout || data.__unauthorized) {
          return; // apiRequest内部でリダイレクトされるため処理を中断
        }

        if (data.reason === 'already_completed') {
          clearSavedInterview();
          showStep(3);
          displayResults({
            message: t('already_taken'),
            result: {
              final_status: 'completed',
              average_score: null,
              answered_questions: null,
              total_questions: null
            }
          });
          startBtn.disabled = false;
          startBtn.textContent = t('start');
          return;
        }

        if (!data.success) {
          alert(data.error || t('start_failed'));
          startBtn.disabled = false;
          startBtn.textContent = t('start');
          return;
        }

        interviewId = data.interview_id;
        saveInterview(interviewId, data.language);
        setStatus(t('started'));
        showStep(2);
        await loadNextQuestion();
      } catch (e) {
        alert(t('error_prefix', { message: e.message }));
        startBtn.disabled = false;
        startBtn.textContent = t('start');
      }
    }

    async function resumeInterview() {
      var savedId = loadSavedInterview();
      if (!savedId) {
        alert(t('saved_missing'));
        return;
      }
      interviewId = savedId;
      showStep(2);
      setStatus(t('resuming'));

      try {
        var statusResult = await apiRequest('/api/interviews/' + interviewId + '/status', {});
        var statusData = statusResult.data;

        if (statusData.__timeout || statusData.__unauthorized) return;

        if (!statusData.success) {
          alert(statusData.error || t('fetch_failed'));
          clearSavedInterview();
          showStep(1);
          return;
        }

        var currentStatus = statusData.state && statusData.state.status;

        if (currentStatus === 'completed' || currentStatus === 'failed') {
          alert(t('already_done'));
          clearSavedInterview();
          showStep(1);
          return;
        }

        if (currentStatus === 'not_started') {
          alert(t('not_started'));
          clearSavedInterview();
          showStep(1);
          return;
        }

        if (currentStatus === 'abandoned') {
          var resumeResult = await apiRequest('/api/interviews/' + interviewId + '/resume', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
          });
          var resumeData = resumeResult.data;
          if (resumeData.__timeout || resumeData.__unauthorized) return;
          
          if (!resumeData.success) {
            alert(resumeData.error || t('resume_failed'));
            clearSavedInterview();
            showStep(1);
            return;
          }
        }

        await refreshStatus();
        await loadNextQuestion();
      } catch (e) {
        alert(t('error_prefix', { message: e.message }));
        clearSavedInterview();
        showStep(1);
      }
    }

    async function transitionIfInterviewEnded() {
      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/status', {});
        var data = result.data;
        if (!data || !data.success || !data.state) return false;

        var s = data.state.status;
        if (s === 'failed' || s === 'completed') {
          clearSavedInterview();
          showStep(3);

          var rejectionMsg = data.state.rejection_reason || '';
          displayResults({
            message: s === 'failed'
              ? t('ended') + (rejectionMsg ? ('\n' + rejectionMsg) : '')
              : t('completed'),
            result: {
              final_status: s === 'failed' ? 'failed' : 'passed',
              average_score: null,
              answered_questions: data.state.answered_questions,
              total_questions: data.state.total_questions
            }
          });
          return true;
        }
        return false;
      } catch (e) {
        return false;
      }
    }

    async function refreshStatus() {
      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/status', {});
        var data = result.data;
        if (data.__timeout || data.__unauthorized) return;
        
        if (!data.success) {
          setStatus(data.error || t('status_failed'));
          return;
        }
        var state = data.state;
        setProgress(state.progress, state.answered_questions, state.total_questions);
      } catch (e) {
        setStatus(t('status_failed'));
      }
    }

    function renderOptions(options) {
      mcqOptions.innerHTML = '';
      selectedOption = null;
      if (!options || !options.choices) return;

      options.choices.forEach(function(choice) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'mcq-option';
        btn.textContent = choice;
        btn.addEventListener('click', function() {
          selectedOption = choice;
          document.querySelectorAll('.mcq-option').forEach(function(b) {
            b.classList.remove('selected');
          });
          btn.classList.add('selected');
        });
        mcqOptions.appendChild(btn);
      });
    }


    async function submitAnswer() {
      if (isSubmitting) return;
      if (!currentQuestion) {
        alert(t('no_question'));
        return;
      }

      var textAnswer = byId('text_answer').value;
      var audioFileInput = byId('audio_file');
      var videoFileInput = byId('video_file');

      var hasText = textAnswer && textAnswer.trim().length > 0;
      var hasAudio = audioFileInput.files[0];
      var hasVideo = videoFileInput.files[0];
      var hasRecording = recordedBlob !== null && recordedBlob.size > 0;
      var hasSelection = selectedOption;

      if (!hasText && !hasAudio && !hasVideo && !hasRecording && !hasSelection) {
        alert(t('need_answer'));
        return;
      }

      isSubmitting = true;
      submitBtn.disabled = true;
      submitBtn.textContent = t('submitting');

      var form = new FormData();
      form.append('question_id', currentQuestion.question_id);

      if (hasSelection) {
        form.append('selected_option', selectedOption);
      }
      if (hasText) {
        form.append('text_answer', textAnswer);
      }
      if (hasAudio) {
        form.append('audio_file', audioFileInput.files[0]);
      } else if (hasRecording) {
        form.append('audio_file', recordedBlob, 'recording.webm');
      }
      if (hasVideo) {
        form.append('video_file', videoFileInput.files[0]);
      }

      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/submit_answer', {
          method: 'POST',
          body: form
        });
        var data = result.data;

        if (data.__timeout || data.__unauthorized) return;

        if (!data.success) {
          alert(data.error || t('submit_failed'));
          return;
        }

        recordedChunks = [];
        recordedBlob = null;
        selectedOption = null;
        if (recordedAudio) recordedAudio.src = '';
        if (recordStatus) recordStatus.textContent = t('idle');
        byId('text_answer').value = '';
        audioFileInput.value = '';
        videoFileInput.value = '';

        setStatus(t('submitted_next'));
        await loadNextQuestion();
      } catch (e) {
        alert(t('error_prefix', { message: e.message }));
      } finally {
        isSubmitting = false;
        submitBtn.disabled = false;
        submitBtn.textContent = t('submit_answer');
      }
    }

    async function completeInterview() {
      completeBtn.disabled = true;
      completeBtn.textContent = t('completing');

      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/complete', {
          method: 'POST'
        });
        var data = result.data;

        if (data.__timeout || data.__unauthorized) return;

        if (!data.success) {
          alert(data.error || t('complete_failed'));
          completeBtn.disabled = false;
          completeBtn.textContent = t('complete');
          return;
        }

        clearSavedInterview();
        showStep(3);
        displayResults(data);
      } catch (e) {
        alert(t('error_prefix', { message: e.message }));
        completeBtn.disabled = false;
        completeBtn.textContent = t('complete');
      }
    }

    function displayResults(data) {
      var result = data.result || {};
      resultStatus.textContent = data.message || t('completed');

      var finalStatus = result.final_status || '-';
      resultFinal.textContent = finalStatus === 'passed' ? t('passed') : finalStatus === 'failed' ? t('failed') : finalStatus;
      resultFinal.className = 'result-item__value result-status--' + finalStatus;

      var avgScore = result.average_score;
      resultAvg.textContent = avgScore != null ? avgScore.toFixed(1) + ' / 100' : '-';
      resultQs.textContent = t('question_count', { answered: result.answered_questions || 0, total: result.total_questions || 0 });

      fetchDetailedResults();
    }

    async function fetchDetailedResults() {
      if (!interviewId) return;
      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/status', {});
        var data = result.data;
        if (!data.success || !data.state) return;

        var state = data.state;
        if (state.summary) resultSummary.textContent = state.summary;

        if (state.strengths && Array.isArray(state.strengths)) {
          resultStrengths.innerHTML = '';
          state.strengths.forEach(function(s) {
            var li = document.createElement('li');
            li.textContent = s;
            resultStrengths.appendChild(li);
          });
        }

        if (state.weaknesses && Array.isArray(state.weaknesses)) {
          resultWeaknesses.innerHTML = '';
          state.weaknesses.forEach(function(w) {
            var li = document.createElement('li');
            li.textContent = w;
            resultWeaknesses.appendChild(li);
          });
        }

        if (state.recommendation) resultRecommendation.textContent = state.recommendation;
      } catch (e) {
        // Quiet catch
      }
    }

    async function setupRecorder() {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        recordStatus.textContent = t('unsupported');
        return;
      }

      try {
        var stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaRecorder = new MediaRecorder(stream);

        mediaRecorder.ondataavailable = function(e) {
          if (e.data.size > 0) recordedChunks.push(e.data);
        };

        mediaRecorder.onstop = function() {
          if (recordedChunks.length === 0) {
            recordedBlob = null;
            recordStatus.textContent = t('no_audio');
            return;
          }
          var blob = new Blob(recordedChunks, { type: 'audio/webm' });
          recordedBlob = blob;
          if (recordedAudio.src && recordedAudio.src.indexOf('blob:') === 0) {
            URL.revokeObjectURL(recordedAudio.src);
          }
          recordedAudio.src = URL.createObjectURL(blob);
          recordStatus.textContent = t('recorded');
        };
      } catch (e) {
        recordStatus.textContent = t('mic_denied');
        mediaRecorder = null;
      }
    }

    // ===== 既存のリスナーを一度確実にクリアしてから再登録 =====
    startBtn.onclick = startInterview;
    if (resumeBtn) resumeBtn.onclick = resumeInterview;
    if (submitBtn) submitBtn.onclick = submitAnswer;
    if (completeBtn) completeBtn.onclick = completeInterview;

    if (recordStart) {
      recordStart.onclick = async function() {
        if (!mediaRecorder) await setupRecorder();
        if (!mediaRecorder) return;
        recordedChunks = [];
        recordedBlob = null;
        if (recordedAudio && recordedAudio.src && recordedAudio.src.indexOf('blob:') === 0) {
          URL.revokeObjectURL(recordedAudio.src);
        }
        if (recordedAudio) recordedAudio.src = '';
        mediaRecorder.start();
        recordStart.disabled = true;
        recordStop.disabled = false;
        recordStatus.textContent = t('recording');
      };
    }

    if (recordStop) {
      recordStop.onclick = function() {
        if (!mediaRecorder) return;
        mediaRecorder.stop();
        recordStart.disabled = false;
        recordStop.disabled = true;
      };
    }

    if (backToStartBtn) {
      backToStartBtn.onclick = function() {
        showStep(1);
        startBtn.disabled = false;
        startBtn.textContent = t('start');
      };
    }

    // ===== 起動時の再開ボタン判定 =====
    (async function maybeShowResumeButton() {
      if (!resumeBtn) return;
      var savedId = loadSavedInterview();
      if (!savedId) return;

      if (typeof accessToken === 'undefined' || !accessToken) {
        var tmpToken = localStorage.getItem('aiInterviewToken');
        if (tmpToken) window.accessToken = tmpToken;
      }

      try {
        var result = await apiRequest('/api/interviews/' + savedId + '/status', {});
        var data = result.data;
        if (!data || !data.success || !data.state) {
          clearSavedInterview();
          return;
        }
        var s = data.state.status;
        var canResume = (s === 'in_progress') || (s === 'abandoned' && data.state.resumable === true);
        if (canResume) {
          resumeBtn.style.display = 'inline-block';
        } else {
          clearSavedInterview();
        }
      } catch (e) {
        // Fail silently
      }
    })();
  }

  // グローバルドロップダウンおよび共通制御（多重発火・Turbo耐性を完全に保証）
  function initGlobalNavScripts() {
    // ログインドロップダウン
    const toggleBtn = document.querySelector('[data-toggle-login]');
    const menu = document.querySelector('.dropdown-menu-login');

    if (toggleBtn && menu) {
      toggleBtn.onclick = function(e) {
        e.preventDefault();
        e.stopPropagation();
        const isOpen = menu.style.display === 'block';
        menu.style.display = isOpen ? 'none' : 'block';
      };

      // 画面外クリックで閉じる処理の統合
      const closeDropdown = function() {
        menu.style.display = 'none';
      };
      
      document.removeEventListener('click', closeDropdown);
      document.addEventListener('click', closeDropdown);

      menu.onclick = function(e) {
        e.stopPropagation();
      };
    }
  }

  if (document.readyState !== 'loading') {
    initInterviewPortal();
    initGlobalNavScripts();
  } else {
    document.addEventListener('DOMContentLoaded', function() {
      initInterviewPortal();
      initGlobalNavScripts();
    });
  }

  document.addEventListener('turbo:load', function() {
    initInterviewPortal();
    initGlobalNavScripts();
  });
})();