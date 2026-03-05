class Question < ApplicationRecord
  belongs_to :situation
  has_many :interview_responses, dependent: :destroy
  has_many :question_audios, dependent: :destroy
  
  validates :question_text, :question_type, presence: true

  validate :options_required_for_multiple_choice

  scope :ordered, -> { order(:order) }
  scope :required_only, -> { where(required: true) }

  def has_branching_rules?
    branching_rules.present?
  end

  def parsed_branching_rules
    return nil unless has_branching_rules?

    rules = branching_rules
    rules = JSON.parse(rules) if rules.is_a?(String)
    rules.deep_symbolize_keys
  rescue JSON::ParserError
    nil
  end

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
