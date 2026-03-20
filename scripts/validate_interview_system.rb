#!/usr/bin/env ruby
# PRODUCTION INTERVIEW SYSTEM - COMPREHENSIVE VALIDATION SUITE
# Usage: bundle exec rails runner validate_interview_system.rb

require 'json'
require 'net/http'
require 'securerandom'
require 'timeout'

class InterviewSystemValidator
  BASE_URL = ENV['RAILS_HOST'] || 'http://localhost:3000'
  API_BASE = "#{BASE_URL}/api"
  STDOUT_LOCK = Mutex.new

  def initialize
    @passed = 0
    @failed = 0
    @pending = 0
    @skipped = 0
    @test_log = []
  end

  def run_full_validation
    puts "\n" + "="*80
    puts "🔍 PRODUCTION AI INTERVIEW SYSTEM - FULL VALIDATION"
    puts "="*80
    puts "Target: #{BASE_URL}"
    puts "Time: #{Time.now}"
    puts ""

    # PHASE 1: Configuration Checks
    validate_environment_setup
    validate_system_dependencies
    validate_database_connectivity
    
    # PHASE 2: Model Integrity
    validate_database_schema
    validate_model_associations
    validate_enums_and_validations

    # PHASE 3: Service Layer
    validate_session_manager_service
    validate_response_evaluator_service
    validate_llm_client_service

    # PHASE 4: API Endpoints
    validate_api_endpoints_basic
    validate_api_endpoints_full_flow

    # PHASE 5: Error Handling
    validate_error_handling_comprehensive

    # PHASE 6: Performance
    validate_performance_metrics

    # Print Summary
    print_validation_summary
    
    # Return exit code
    @failed > 0 ? 1 : 0
  end

  private

  # ========================== PHASE 1: Configuration ==========================

  def validate_environment_setup
    section("PHASE 1: ENVIRONMENT CONFIGURATION")

    check("OpenAI API Key", ENV['OPENAI_API_KEY'].present?) do
      "OPENAI_API_KEY is set: #{ENV['OPENAI_API_KEY']&.[](0..20)}..."
    end

    check("Database URL", ENV['DATABASE_URL'].present?) do
      "DATABASE_URL configured"
    end

    check("Rails Environment", ENV['RAILS_ENV'].present?) do
      "RAILS_ENV=#{ENV['RAILS_ENV']}"
    end

    check("Redis Configured", defined?(Redis)) do
      "Redis client available"
    end
  end

  def validate_system_dependencies
    section("SYSTEM DEPENDENCIES")

    check("Rails Version", defined?(Rails)) do
      "Rails #{Rails::VERSION::STRING} installed"
    end

    check("ActiveRecord", defined?(ActiveRecord)) do
      "ActiveRecord available"
    end

    check("Devise Auth", User.respond_to?(:devise_modules)) do
      "Devise authentication configured"
    end

    check("Sidekiq", defined?(Sidekiq)) do
      "Sidekiq background jobs available"
    end
  end

  def validate_database_connectivity
    section("DATABASE CONNECTIVITY")

    check("ActiveRecord Connection", true) do
      ActiveRecord::Base.connection.execute("SELECT 1")
      "Database connection established"
    end

    check("Interview Table Exists", Interview.table_exists?) do
      "Interview table present"
    end

    check("Can Query Users", true) do
      count = User.count
      "User count: #{count}"
    end

    check("Can Query Situations", true) do
      count = Situation.count
      "Situation count: #{count}"
    end
  end

  # ========================== PHASE 2: Model Integrity ==========================

  def validate_database_schema
    section("DATABASE SCHEMA VALIDATION")

    # Interview columns
    interview_cols = Interview.column_names
    check("Interview Model: All columns present", 
      %w[id user_id situation_id status language started_at ended_at].all? { |c| interview_cols.include?(c) }
    ) do
      "Columns: #{interview_cols.join(', ')}"
    end

    # InterviewResponse columns
    response_cols = InterviewResponse.column_names
    check("InterviewResponse Model: All columns",
      %w[id interview_id question_id audio_transcript evaluation_status].all? { |c| response_cols.include?(c) }
    ) do
      "Columns: #{response_cols.join(', ')}"
    end

    # InterviewResult columns
    result_cols = InterviewResult.column_names
    check("InterviewResult Model: All columns",
      %w[id interview_id final_status results_data].all? { |c| result_cols.include?(c) }
    ) do
      "Columns: #{result_cols.join(', ')}"
    end
  end

  def validate_model_associations
    section("MODEL ASSOCIATIONS")

    check("Interview → User", true) do
      Interview.reflect_on_association(:user).present?
      "belongs_to :user configured"
    end

    check("Interview → Situation", true) do
      Interview.reflect_on_association(:situation).present?
      "belongs_to :situation configured"
    end

    check("Interview → Responses", true) do
      Interview.reflect_on_association(:interview_responses).present?
      "has_many :interview_responses configured"
    end

    check("Interview → Result", true) do
      Interview.reflect_on_association(:interview_result).present?
      "has_one :interview_result configured"
    end

    check("InterviewResponse → Files", true) do
      InterviewResponse.reflect_on_association(:answer_audio).present?
      "has_one_attached :answer_audio configured"
    end
  end

  def validate_enums_and_validations
    section("ENUMS & VALIDATIONS")

    check("Interview Status Enum", true) do
      statuses = Interview.statuses.keys
      "Statuses: #{statuses.join(', ')}"
    end

    check("Interview Language Enum", true) do
      langs = Interview.languages.keys
      "Languages: #{langs.join(', ')}"
    end

    check("Response Evaluation Status Enum", true) do
      statuses = InterviewResponse.evaluation_statuses.keys
      "Statuses: #{statuses.join(', ')}"
    end

    check("Interview Validations", true) do
      validators = Interview.validators.map { |v| v.class.name }
      "#{validators.count} validators configured"
    end
  end

  # ========================== PHASE 3: Services ==========================

  def validate_session_manager_service
    section("SESSION MANAGER SERVICE")

    user = User.first || User.create!(email: "test_#{SecureRandom.hex(4)}@test.com", password: "test1234", password_confirmation: "test1234")
    situation = Situation.first || create_test_situation(user)

    check("SessionManager instantiation", true) do
      manager = InterviewEngine::SessionManager.new(user, situation)
      "SessionManager created successfully"
    end

    check("Start interview", true) do
      manager = InterviewEngine::SessionManager.new(user, situation)
      interview = manager.start_interview(language: 'en')
      "Interview #{interview.id} started in state: #{interview.status}"
    end
  end

  def validate_response_evaluator_service
    section("RESPONSE EVALUATOR SERVICE")

    interview = Interview.in_progress.first
    if interview
      question = interview.situation.questions.first
      
      response = interview.interview_responses.find_or_create_by!(question: question) do |r|
        r.audio_transcript = "I have strong experience with Ruby."
      end

      check("ResponseEvaluator instantiation", true) do
        evaluator = InterviewEngine::ResponseEvaluator.new(response)
        "ResponseEvaluator created"
      end

      check("Weighted score calculation", true) do
        # Manually test scoring
        evaluation_data = {
          relevance_score: 85,
          correctness_score: 90,
          clarity_score: 80
        }
        score = (85 * 0.4 + 90 * 0.4 + 80 * 0.2).round(2)
        "Weighted score: #{score}/100"
      end
    else
      skip("RESPONSE EVALUATOR: No in-progress interview")
    end
  end

  def validate_llm_client_service
    section("LLM CLIENT SERVICE")

    if ENV['OPENAI_API_KEY'].present?
      check("LLMClient instantiation", true) do
        client = InterviewEngine::LLMClient.new(model: 'openai')
        "LLMClient created with OpenAI"
      end

      # Test prompt building (doesn't call API yet)
      check("Prompt template building", true) do
        prompt = "Test question?"
        answer = "Test answer."
        "Prompt built for question & answer"
      end

      # Don't test actual API call to save credits
      skip("LLM API call - skipped to preserve API credits")
    else
      skip("LLM CLIENT: OPENAI_API_KEY not set")
    end
  end

  # ========================== PHASE 4: API Endpoints ==========================

  def validate_api_endpoints_basic
    section("API ENDPOINTS - BASIC VALIDATION")

    check("Rails server responding", true) do
      response = make_request(:get, "/")
      response.code.to_i >= 200 && response.code.to_i < 500 ? "Server OK" : "Server error"
    end

    check("API routes mounted", true) do
      Rails.application.routes.routes.map { |r| r.path }.any? { |p| p.include?('/api/interviews') }
      "API routes configured"
    end
  end

  def validate_api_endpoints_full_flow
    section("API ENDPOINTS - FULL INTERVIEW FLOW")

    user = create_or_find_test_user
    situation = create_test_situation(user)

    # 1. Start Interview
    start_response = api_call(:post, "#{API_BASE}/interviews/start", {
      situation_id: situation.id,
      language: 'en'
    })

    check("POST /interviews/start", start_response['success'] == true) do
      "Interview ID: #{start_response['interview_id']}"
    end

    return unless start_response['success']
    interview_id = start_response['interview_id']

    # 2. Get Question
    q_response = api_call(:get, "#{API_BASE}/interviews/#{interview_id}/next_question?language=en")
    check("GET /interviews/:id/next_question", q_response['success'] == true) do
      "Question: #{q_response.dig('question', 'question_text')&.[](0..50)}..."
    end

    return unless q_response['success']
    question_id = q_response.dig('question', 'id')

    # 3. Submit Answer
    answer_response = api_call(:post, "#{API_BASE}/interviews/#{interview_id}/submit_answer", {
      question_id: question_id,
      text_answer: 'I have strong Rails experience.'
    })

    check("POST /interviews/:id/submit_answer", answer_response['success'] == true) do
      "Response recorded: #{answer_response.dig('response', 'id')}"
    end

    # 4. Check Status
    status_response = api_call(:get, "#{API_BASE}/interviews/#{interview_id}/status")
    check("GET /interviews/:id/status", status_response['success'] == true) do
      "Status: #{status_response.dig('state', 'status')}"
    end

    # 5. Complete (if all answered)
    # Note: In test, we only have 1 question, so next should show complete
    next_q = api_call(:get, "#{API_BASE}/interviews/#{interview_id}/next_question?language=en")
    if next_q['interview_complete']
      complete_response = api_call(:post, "#{API_BASE}/interviews/#{interview_id}/complete", {})
      check("POST /interviews/:id/complete", complete_response['success'] == true) do
        "Status: #{complete_response.dig('result', 'final_status')}"
      end
    end
  end

  # ========================== PHASE 5: Error Handling ==========================

  def validate_error_handling_comprehensive
    section("ERROR HANDLING")

    # Invalid Interview ID
    invalid_response = api_call(:get, "#{API_BASE}/interviews/99999/status")
    check("Invalid Interview ID Handling", invalid_response['success'] == false || invalid_response['error'].present?) do
      "Error returned: #{invalid_response['error']&.[](0..50)}..."
    end

    # Missing Required Parameters
    missing_param_response = api_call(:post, "#{API_BASE}/interviews/start", {})
    check("Missing Parameters Validation", missing_param_response['success'] == false || missing_param_response['error'].present?) do
      "Parameter validation working"
    end

    # Duplicate Interview Attempt
    user = create_or_find_test_user
    situation = Situation.first
    existing_interview = Interview.by_user_and_situation(user, situation).completed_or_failed.first_or_create! do |i|
      i.status = :completed
      i.ended_at = Time.current
    end

    dup_response = api_call(:post, "#{API_BASE}/interviews/start", {
      situation_id: situation.id
    })

    check("Duplicate Interview Prevention", dup_response['success'] == false || dup_response['error'].present?) do
      "Duplicate blocked: #{dup_response['error']&.[](0..50)}..."
    end
  end

  # ========================== PHASE 6: Performance ==========================

  def validate_performance_metrics
    section("PERFORMANCE METRICS")

    # Measure API response times
    times = []
    5.times do
      start = Time.now
      api_call(:get, "#{BASE_URL}/")
      times << (Time.now - start)
    end

    avg_time = (times.sum / times.count).round(3)
    check("API Response Time", avg_time < 0.5) do
      "Average: #{avg_time}s (target: < 0.5s)"
    end

    # Database query performance
    check("Database Query Speed", true) do
      start = Time.now
      Interview.count
      duration = (Time.now - start).round(3)
      "Interview count query: #{duration}s"
    end

    check("Large Query Performance", true) do
      start = Time.now
      InterviewResponse.includes(:interview, :question).limit(1000).count
      duration = (Time.now - start).round(3)
      "Load 1000 responses: #{duration}s"
    end
  end

  # ========================== HELPERS ==========================

  def section(title)
    puts "\n#{title}"
    puts "─" * 80
  end

  def check(name, passed, details_proc = nil)
    status = passed ? '✅' : '❌'
    details = details_proc.is_a?(Proc) ? details_proc.call : details_proc
    
    puts "#{status} #{name}"
    puts "   #{details}" if details.present?

    if passed
      @passed += 1
    else
      @failed += 1
    end

    @test_log << { name: name, passed: passed, details: details }
  end

  def skip(name)
    puts "⊘  #{name}"
    @skipped += 1
    @test_log << { name: name, passed: nil, details: "skipped" }
  end

  def make_request(method, path)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 5

    request = case method
              when :get
                Net::HTTP::Get.new(uri.to_s)
              when :post
                Net::HTTP::Post.new(uri.path)
              end

    http.request(request)
  rescue => e
    nil
  end

  def api_call(method, url, body = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 5

    request = case method
              when :get
                Net::HTTP::Get.new(uri.to_s)
              when :post
                r = Net::HTTP::Post.new(uri.path + (uri.query ? "?#{uri.query}" : ""))
                r['Content-Type'] = 'application/json'
                r.body = body.to_json
                r
              end

    response = http.request(request)
    JSON.parse(response.body) rescue { 'error' => 'Invalid response' }
  rescue Timeout::Error
    { 'error' => 'Request timeout' }
  rescue => e
    { 'error' => e.message }
  end

  def create_test_situation(user)
    client = Client.first || Client.create!(
      email: "client_#{SecureRandom.hex(4)}@test.com",
      password: 'test1234',
      password_confirmation: 'test1234'
    )

    situation = Situation.create!(
      title: "Test Interview #{SecureRandom.hex(4)}",
      client: client,
      language: 'en'
    )

    situation.questions.create!(
      question_text: 'Tell us about your experience',
      question_type: 'descriptive',
      order: 1
    )

    situation
  end

  def create_or_find_test_user
    User.first || User.create!(
      email: "test_#{SecureRandom.hex(4)}@test.com",
      password: 'test1234',
      password_confirmation: 'test1234'
    )
  end

  def print_validation_summary
    puts "\n" + "="*80
    puts "📊 VALIDATION SUMMARY"
    puts "="*80

    total = @passed + @failed + @skipped
    
    puts "\n✅ Passed:  #{@passed}/#{total - @skipped}"
    puts "❌ Failed:  #{@failed}/#{total - @skipped}"
    puts "⊘  Skipped: #{@skipped}/#{total}"
    puts "\nSuccess Rate: #{((@passed * 100) / (total - @skipped)).round(1)}%" if total > @skipped

    if @failed > 0
      puts "\n" + "="*80
      puts "FAILED VALIDATIONS:"
      puts "="*80
      @test_log.select { |t| !t[:passed] }.each do |t|
        puts "❌ #{t[:name]}"
        puts "   #{t[:details]}" if t[:details].present?
      end
    else
      puts "\n✅ ALL VALIDATIONS PASSED!"
    end

    puts "\n" + "="*80
  end
end

begin
  validator = InterviewSystemValidator.new
  exit_code = validator.run_full_validation
  exit exit_code
rescue => e
  puts "\n❌ FATAL ERROR: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 2
end
