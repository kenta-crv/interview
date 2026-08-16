class ProblemsController < ApplicationController
  layout :problems_layout

  # before_action :authenticate_admin!, only: [:index, :destroy, :send_mail]
  def index
    @problems = Problem.order(created_at: "DESC").page(params[:page])
  end

  def new
    @embed = embed_request?
    @problem = Problem.new
    prefill_from_client
  end

  def create
    @problem = Problem.new(problem_params)
    @embed = embed_request?

    if @problem.save
      flash[:notice] = t("meetia.problems.submitted")
      begin
        ProblemMailer.report_email(@problem).deliver
      rescue StandardError => e
        Rails.logger.error("[ProblemsController#create] mail failed: #{e.class}: #{e.message}")
      end

      if @embed
        render :submitted_embed, layout: false
      else
        redirect_to dashboard_index_path
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @problem = Problem.find(params[:id])
  end

  def edit
    @problem = Problem.find(params[:id])
  end

  def destroy
    @problem = Problem.find(params[:id])
    @problem.destroy
    redirect_to problems_path, alert: t("meetia.problems.deleted")
  end

  def update
    @problem = Problem.find(params[:id])

    if @problem.update(problem_params)
      redirect_to root_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def problem_params
    params.require(:problem).permit(
      :company,
      :email,
      :body,
      :photo
    )
  end

  def embed_request?
    params[:embed].to_s == "1" || params.dig(:problem, :embed).to_s == "1"
  end

  def problems_layout
    return "application" if %w[index show edit update destroy].include?(action_name)
    return "problem_embed" if embed_request? && %w[new create].include?(action_name)

    "dashboard_focus"
  end

  def prefill_from_client
    return unless client_signed_in?

    @problem.company = current_client.company if @problem.company.blank?
    @problem.email = current_client.email if @problem.email.blank?
  end
end
