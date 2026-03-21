# app/controllers/questions_controller.rb
class QuestionsController < ApplicationController
  before_action :authenticate_client!
  before_action :set_situation
  before_action :set_question, only: [:edit, :update, :destroy]

  def index
    @questions = @situation.questions.order(:order)
  end

  def new
    @question = @situation.questions.new
  end

  def create
    @question = @situation.questions.new(question_params)
    if @question.save
      redirect_to situation_questions_path(@situation), notice: '質問を作成しました。'
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @question.update(question_params)
      redirect_to situation_questions_path(@situation), notice: '質問を更新しました。'
    else
      render :edit
    end
  end

  def destroy
    @question.destroy
    redirect_to situation_questions_path(@situation), notice: '質問を削除しました。'
  end

  private

  def set_situation
    @situation = Situation.find(params[:situation_id])
  end

  def set_question
    @question = @situation.questions.find(params[:id])
  end

  def question_params
    permitted = params.require(:question).permit(
      :question_text, :question_type, :options, :order,
      :required, :category, :branching_rules
    )
    parse_options_json(permitted)
    parse_branching_rules_json(permitted)
  end

  def parse_options_json(permitted)
    raw = permitted[:options]
    return permitted if raw.blank? || !raw.is_a?(String)

    permitted[:options] = JSON.parse(raw)
    permitted
  rescue JSON::ParserError
    permitted
  end

  def parse_branching_rules_json(permitted)
    raw = permitted[:branching_rules]
    return permitted if raw.blank? || !raw.is_a?(String)

    permitted[:branching_rules] = JSON.parse(raw)
    permitted
  rescue JSON::ParserError
    permitted
  end
end
