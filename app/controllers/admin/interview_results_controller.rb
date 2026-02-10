# app/controllers/admin/interview_results_controller.rb
class Admin::InterviewResultsController < ApplicationController
  before_action :authenticate_admin!

  def index
    @results = InterviewResult.includes(interview: [:user, :situation]).order(created_at: :desc)
  end

  def show
    @result = InterviewResult.includes(interview: [:user, :situation, :interview_responses]).find(params[:id])
  end
end
