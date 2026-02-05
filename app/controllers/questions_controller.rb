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
    params.require(:question).permit(:question_text, :question_type, :options, :order)
  end
end
