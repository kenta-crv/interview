class Question < ApplicationRecord
  belongs_to :situation
  has_many :interview_responses, dependent: :destroy
  has_many :question_audios, dependent: :destroy
  
  validates :question_text, :question_type, presence: true

  validate :options_required_for_multiple_choice

  scope :ordered, -> { order(:order) }

  def multiple_choice?
    %w[choice multiple_choice mcq].include?(question_type)
  end

  def descriptive?
    !multiple_choice?
  end

  def parsed_options
    return {} if options.blank?
    return options if options.is_a?(Hash)
    return { choices: options } if options.is_a?(Array)

    JSON.parse(options.to_s)
  rescue JSON::ParserError
    {}
  end

  private

  def options_required_for_multiple_choice
    return unless multiple_choice?
    parsed = parsed_options
    choices = parsed['choices'] || parsed[:choices] || []
    errors.add(:options, 'must include choices for multiple choice questions') if choices.blank?
  end
end
