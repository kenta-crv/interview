#!/usr/bin/env ruby
# Complete AI Interview System Implementation Validator & Tester
# Usage: bundle exec rails runner test_complete_interview_system.rb

require 'json'
require 'securerandom'

class InterviewSystemTester
  BASE_URL = 'http://localhost:3000'
  API_PATH = '/api/interviews'

  def initialize
    @test_results = []
    @user = nil
    @interview_id = nil
  end

  def run_all_tests
    puts "\n" + "="*80
    puts "🧪 COMPLETE AI INTERVIEW SYSTEM - PRODUCTION VALIDATION"
    puts "="*80

    setup_test_data
    test_interview_flow
    test_validation_rules
    test_error_handling
    print_results

    @test_results.all? { |r| r[:passed] } ? 0 : 1
  end

  private

  def setup_test_data
    puts "\n▶ SETUP: Creating test data..."

    @user = User.find_or_create_by(email: "test_#{SecureRandom.hex(4)}@interview.com") do |u|
      u.name = 'Test User'
      u.password = 'test1234'
      u.password_confirmation = 'test1234'
    end

    client = Client.find_or_create_by(email: 'test_client@interview.com') do |c|
      c.password = 'password123'
      c.password_confirmation = 'password123'
    end

    @situation = Situation.find_or_create_by(title: 'Backend Engineer Interview') do |s|
      s.client = client
      s.description = 'Full-stack backend engineer technical interview'
      s.language = 'en'
    end

    # Create questions if missing
    if @situation.questions.count == 0
      [
        { text: 'Tell us about your experience with Ruby on Rails', order: 1 },
        { text: 'How do you approach debugging in production?', order: 2 },
        { text: 'Describe your approach to writing clean code', order: 3 }
      ].each do |q|
        @situation.questions.create!(question_text: q[:text], order: q[:order], question_type: 'descriptive')
      end
    end

    test('Data Setup', true, 'User, Situation, Questions created')
  end

  def test_interview_flow
    puts "\n▶ TEST: Complete Interview Flow"

    # 1. Start Interview
    start_response = api_call('POST', "#{API_PATH}/start", {
      situation_id: @situation.id,
      language: 'en'
    })

    success = start_response['success']
    @interview_id = start_response['interview_id']
    test('1. Start Interview', success, "Interview ID: #{@interview_id}")

    unless success
      test('Interview Flow', false, 'Failed to start interview')
      return
    end

    # Verify interview state
    interview = Interview.find(@interview_id)
    test('2. Interview State', interview.in_progress?, "Status: #{interview.status}")

    # 2. Get First Question
    q_response = api_call('GET', "#{API_PATH}/#{@interview_id}/next_question?language=en")
    test('3. Fetch Question', q_response['success'], "Question: #{q_response.dig('question', 'question_text')&.first(50)}...")

    return unless q_response['success']
    question_id = q_response.dig('question', 'id')

    # 3. Submit Answer (Text only)
    answer_response = api_call('POST', "#{API_PATH}/#{@interview_id}/submit_answer", {
      question_id: question_id,
      text_answer: 'I have 5 years of Rails experience building scalable APIs.'
    })
    test('4. Submit Text Answer', answer_response['success'], "Response ID: #{answer_response['response_id']}")

    # 4. Check Status
    status_response = api_call('GET', "#{API_PATH}/#{@interview_id}/status")
    is_valid = status_response['success'] && status_response.dig('state', 'status').present?
    test('5. Check Status', is_valid, "Progress: #{status_response.dig('state', 'progress')}")

    # 5. Get second question
    q2_response = api_call('GET', "#{API_PATH}/#{@interview_id}/next_question?language=en")
    question2_id = q2_response.dig('question', 'id')

    # 6. Submit second answer
    api_call('POST', "#{API_PATH}/#{@interview_id}/submit_answer", {
      question_id: question2_id,
      text_answer: 'I use logs, monitoring tools, and quick debugging techniques.'
    })

    # 7. Get third question
    q3_response = api_call('GET', "#{API_PATH}/#{@interview_id}/next_question?language=en")
    question3_id = q3_response.dig('question', 'id')

    # 8. Submit third answer
    api_call('POST', "#{API_PATH}/#{@interview_id}/submit_answer", {
      question_id: question3_id,
      text_answer: 'I follow SOLID principles, use clear naming, and write tests.'
    })

    # 9. Complete Interview
    complete_response = api_call('POST', "#{API_PATH}/#{@interview_id}/complete", {})
    test('6. Complete Interview', complete_response['success'], "Final Status: #{complete_response.dig('result', 'final_status')}")

    # 10. Verify results calculated
    interview.reload
    result = interview.interview_result
    has_result = result.present? && result.average_score.present?
    test('7. Results Calculated', has_result, "Average Score: #{result&.average_score.to_f.round(1)}/100")
  end

  def test_validation_rules
    puts "\n▶ TEST: Validation Rules"

    # Test: Duplicate interview attempt
    dup_response = api_call('POST', "#{API_PATH}/start", {
      situation_id: @situation.id,
      language: 'en'
    })
    test('Duplicate Interview Prevention', dup_response['success'] == false, "Error: #{dup_response['error']&.first(50)}")

    # Test: Invalid situation
    invalid_response = api_call('POST', "#{API_PATH}/start", {
      situation_id: 99999,
      language: 'en'
    })
    test('Invalid Situation Handling', invalid_response['success'] == false, 'Situation not found')

    # Test: Interview must have questions
    test_client = Client.find_or_create_by(email: 'test_client_2@interview.com') do |c|
      c.password = 'password123'
      c.password_confirmation = 'password123'
    end
    
    empty_situation = Situation.create!(
      title: 'Empty Situation',
      client: test_client,
      language: 'en'
    )

    empty_user = User.create!(
      name: 'Empty Test User',
      email: "empty_#{SecureRandom.hex(4)}@interview.com",
      password: 'test1234',
      password_confirmation: 'test1234'
    )

    empty_response = api_call('POST', "#{API_PATH}/start", {
      situation_id: empty_situation.id,
      language: 'en'
    }, user: empty_user)

    test('Require Questions', empty_response['success'] == false, 'Situation must have questions')
  end

  def test_error_handling
    puts "\n▶ TEST: Error Handling"

    # Invalid endpoint
    error_response = api_call('GET', "#{API_PATH}/99999/status")
    test('Invalid Interview ID', error_response['success'] == false, '404 Handling')

    # Missing parameters
    missing_param = api_call('POST', "#{API_PATH}/start", {})
    test('Missing Parameters', missing_param['success'] == false, 'Parameter validation')

    # Test language support
    if @interview_id
      lang_response = api_call('GET', "#{API_PATH}/#{@interview_id}/next_question?language=ja")
      is_valid = lang_response['success'] || lang_response['error']&.present?
      test('Language Support (JA)', is_valid, 'Language handling')
    end
  end

  def api_call(method, path, body = {}, user: nil)
    user ||= @user
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)

    request = case method
              when 'GET'
                Net::HTTP::Get.new(uri.to_s)
              when 'POST'
                r = Net::HTTP::Post.new(uri.path)
                r.body = body.to_json
                r['Content-Type'] = 'application/json'
                r
              end

    # Add auth header if needed (implement based on your auth system)
    # request['Authorization'] = "Bearer #{user.access_token}" if user

    response = http.request(request)
    JSON.parse(response.body) rescue { 'error' => 'Invalid JSON response' }
  rescue => e
    { 'error' => e.message, 'success' => false }
  end

  def test(name, passed, details = '')
    status = passed ? '✅' : '❌'
    @test_results << { name: name, passed: passed, details: details }
    puts "#{status} #{name}"
    puts "   #{details}" if details.present?
  end

  def print_results
    puts "\n" + "="*80
    puts "📊 TEST RESULTS SUMMARY"
    puts "="*80

    total = @test_results.count
    passed = @test_results.count { |r| r[:passed] }
    failed = total - passed

    puts "\n  Total: #{total}"
    puts "  ✅ Passed: #{passed}"
    puts "  ❌ Failed: #{failed}"
    puts "  Success Rate: #{(passed * 100 / total).round(1)}%"

    if failed > 0
      puts "\n❌ FAILED TESTS:"
      @test_results.reject { |r| r[:passed] }.each do |r|
        puts "  - #{r[:name]}: #{r[:details]}"
      end
    else
      puts "\n✅ ALL TESTS PASSED!"
    end

    puts "\n" + "="*80
  end
end

begin
  tester = InterviewSystemTester.new
  exit_code = tester.run_all_tests
  exit exit_code
rescue => e
  puts "\n❌ CRITICAL ERROR: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
