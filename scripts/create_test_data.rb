#!/usr/bin/env ruby
# Script to create test data

require_relative 'config/environment'

puts "\n🔄 Creating test data...\n"

# Create test user
user = User.create!(
  email: 'test@interview.com',
  password: 'password123',
  password_confirmation: 'password123'
)
puts "✅ Created user: #{user.email}"

# Create test client
client = Client.create!(
  email: 'client@interview.com',
  password: 'password123'
)
puts "✅ Created client: #{client.email}"

# Create situation
situation = Situation.create!(
  title: 'Software Engineer Interview',
  client: client,
  description: 'AI-powered interview for backend engineers',
  language: 'en'
)
puts "✅ Created situation: #{situation.title} (ID: #{situation.id})"

# Create questions
questions_data = [
  {
    situation: situation,
    question_text: 'Tell us about your experience with Ruby on Rails',
    question_type: 'long_answer',
    order: 1
  },
  {
    situation: situation,
    question_text: 'How do you handle errors and debugging in production?',
    question_type: 'long_answer',
    order: 2
  },
  {
    situation: situation,
    question_text: 'Describe a challenging project you worked on',
    question_type: 'long_answer',
    order: 3
  }
]

questions_data.each { |q| Question.create!(q) }
puts "✅ Created #{questions_data.length} questions"

puts "\n📊 Test Data Summary:"
puts "=================="
puts "User Email: #{user.email}"
puts "Password: password123"
puts "Situation ID: #{situation.id}"
puts "Questions: #{situation.questions.count}"
puts "\n✅ Test data created successfully!"
