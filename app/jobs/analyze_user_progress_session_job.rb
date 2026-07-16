class AnalyzeUserProgressSessionJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(user_progress_id)
    user_progress = UserProgress.find_by(id: user_progress_id)
    return unless user_progress

    DealEngine::SessionAnalysisService.call(user_progress: user_progress)
  end
end
