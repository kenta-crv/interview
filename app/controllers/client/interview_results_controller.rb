# app/controllers/client/interview_results_controller.rb
class Client::InterviewResultsController < ApplicationController
  before_action :authenticate_client!

  def index
    @results = InterviewResult
      .joins(interview: :situation)
      .where(situations: { client_id: current_client.id })
      .includes(interview: [:user, :situation])
      .order(created_at: :desc)
  end

  def show
    @result = InterviewResult
      .joins(interview: :situation)
      .where(situations: { client_id: current_client.id })
      .includes(interview: [:user, :situation, :interview_responses])
      .find(params[:id])
  end
end
