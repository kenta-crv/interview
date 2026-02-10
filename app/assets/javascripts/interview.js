// app/assets/javascripts/interview.js
function initInterviewPortal() {
  function byId(id) { return document.getElementById(id); }
  const startBtn = byId('start_interview');
  const resumeBtn = byId('resume_interview');
  if (!startBtn || !resumeBtn) return;

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

  const resultStatus = byId('result_status');
  const resultFinal = byId('result_final_status');
  const resultAvg = byId('result_avg_score');
  const resultQs = byId('result_qs');
  const resultSummary = byId('result_summary');
  const resultStrengths = byId('result_strengths');
  const resultWeaknesses = byId('result_weaknesses');
  const resultRecommendation = byId('result_recommendation');

  let interviewId = null;
  let currentQuestion = null;
  let mediaRecorder = null;
  let recordedChunks = [];
  let selectedOption = null;

  function setStatus(msg) { statusEl.textContent = msg; }

  function saveInterview(id, language) {
    localStorage.setItem('aiInterviewId', String(id));
    localStorage.setItem('aiInterviewLanguage', String(language || 'en'));
  }

  function loadSavedInterview() {
    const id = localStorage.getItem('aiInterviewId');
    return id ? parseInt(id, 10) : null;
  }

  function clearSavedInterview() {
    localStorage.removeItem('aiInterviewId');
  }

  function setProgress(progress, answered, total) {
    const pct = Math.max(0, Math.min(100, progress || 0));
    progressBar.style.width = pct + '%';
    progressText.textContent = pct + '%';
    questionCount.textContent = `${answered || 0} / ${total || 0}`;
  }

  async function startInterview() {
    const situationId = byId('situation_id').value || 1;
    const language = byId('language').value || 'en';

    const res = await fetch('/api/interviews/start', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ situation_id: parseInt(situationId, 10), language: language })
    });
    const data = await res.json();
    if (!data.success) {
      setStatus(data.error || 'Failed to start interview');
      return;
    }
    interviewId = data.interview_id;
    saveInterview(interviewId, data.language);
    setStatus('Interview started.');
    await loadNextQuestion();
  }

  async function resumeInterview() {
    const savedId = loadSavedInterview();
    if (!savedId) {
      setStatus('No saved interview found.');
      return;
    }
    interviewId = savedId;
    await refreshStatus();
    await loadNextQuestion();
  }

  async function refreshStatus() {
    const res = await fetch(`/api/interviews/${interviewId}/status`);
    const data = await res.json();
    if (!data.success) {
      setStatus(data.error || 'Failed to load status');
      return;
    }
    const state = data.state;
    setProgress(state.progress, state.answered_questions, state.total_questions);
  }

  function renderOptions(options) {
    mcqOptions.innerHTML = '';
    selectedOption = null;
    if (!options || !options.choices) return;

    options.choices.forEach((choice) => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'mcq-option';
      btn.textContent = choice;
      btn.addEventListener('click', () => {
        selectedOption = choice;
        document.querySelectorAll('.mcq-option').forEach(b => b.classList.remove('selected'));
        btn.classList.add('selected');
      });
      mcqOptions.appendChild(btn);
    });
  }

  async function loadNextQuestion() {
    const res = await fetch(`/api/interviews/${interviewId}/next_question`);
    const data = await res.json();
    if (!data.success) {
      setStatus(data.error || 'Failed to load question');
      return;
    }
    if (data.interview_complete) {
      setStatus(data.message || 'Interview complete.');
      return;
    }

    currentQuestion = data.question;
    questionText.textContent = currentQuestion.question_text;
    if (currentQuestion.audio_url) {
      questionAudio.src = currentQuestion.audio_url;
    }
    if (currentQuestion.options) {
      renderOptions(currentQuestion.options);
    } else {
      mcqOptions.innerHTML = '';
    }

    await refreshStatus();
  }

  async function submitAnswer() {
    if (!currentQuestion) {
      setStatus('No active question.');
      return;
    }

    const textAnswer = byId('text_answer').value;
    const audioFileInput = byId('audio_file');
    const videoFileInput = byId('video_file');

    const form = new FormData();
    form.append('question_id', currentQuestion.question_id);

    if (selectedOption) {
      form.append('selected_option', selectedOption);
    }

    if (textAnswer) {
      form.append('text_answer', textAnswer);
    }

    if (audioFileInput.files[0]) {
      form.append('audio_file', audioFileInput.files[0]);
    } else if (recordedChunks.length) {
      const blob = new Blob(recordedChunks, { type: 'audio/webm' });
      form.append('audio_file', blob, 'recording.webm');
    }

    if (videoFileInput.files[0]) {
      form.append('video_file', videoFileInput.files[0]);
    }

    const res = await fetch(`/api/interviews/${interviewId}/submit_answer`, {
      method: 'POST',
      body: form
    });
    const data = await res.json();
    if (!data.success) {
      setStatus(data.error || 'Failed to submit answer');
      return;
    }

    recordedChunks = [];
    recordedAudio.src = '';
    byId('text_answer').value = '';
    audioFileInput.value = '';
    videoFileInput.value = '';
    setStatus('Answer submitted. Loading next question...');
    await loadNextQuestion();
  }

  async function completeInterview() {
    const res = await fetch(`/api/interviews/${interviewId}/complete`, { method: 'POST' });
    const data = await res.json();
    if (!data.success) {
      resultStatus.textContent = data.error || 'Failed to complete interview';
      return;
    }
    resultStatus.textContent = data.message || 'Interview completed';
    const result = data.result;
    resultFinal.textContent = result.final_status || '-';
    resultAvg.textContent = result.average_score || '-';
    resultQs.textContent = `${result.answered_questions || 0} / ${result.total_questions || 0}`;

    await fetchResultDetails();
    clearSavedInterview();
  }

  async function fetchResultDetails() {
    const res = await fetch(`/api/interviews/${interviewId}/status`);
    const statusData = await res.json();
    if (!statusData.success) return;

    // For now, display summary from InterviewResult using admin/client screens.
    // This portal focuses on flow; detailed results are visible in admin/client UI.
  }

  async function setupRecorder() {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      recordStatus.textContent = 'Recording not supported in this browser.';
      return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaRecorder = new MediaRecorder(stream);

    mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) recordedChunks.push(e.data);
    };

    mediaRecorder.onstop = () => {
      const blob = new Blob(recordedChunks, { type: 'audio/webm' });
      recordedAudio.src = URL.createObjectURL(blob);
      recordStatus.textContent = 'Recording ready.';
    };
  }

  startBtn.addEventListener('click', startInterview);
  resumeBtn.addEventListener('click', resumeInterview);
  submitBtn.addEventListener('click', submitAnswer);
  completeBtn.addEventListener('click', completeInterview);

  recordStart.addEventListener('click', async () => {
    if (!mediaRecorder) await setupRecorder();
    recordedChunks = [];
    mediaRecorder.start();
    recordStart.disabled = true;
    recordStop.disabled = false;
    recordStatus.textContent = 'Recording...';
  });

  recordStop.addEventListener('click', () => {
    if (!mediaRecorder) return;
    mediaRecorder.stop();
    recordStart.disabled = false;
    recordStop.disabled = true;
  });

  const savedId = loadSavedInterview();
  resumeBtn.disabled = !savedId;
}

document.addEventListener('DOMContentLoaded', initInterviewPortal);
document.addEventListener('turbolinks:load', initInterviewPortal);
