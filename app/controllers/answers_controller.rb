# app/controllers/answers_controller.rb
class AnswersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_situation

  def new
    @questions = @situation.questions.order(:order)
    @answer = @situation.answers.new(user: current_user)
    @current_index = params[:index].to_i || 0
    @question = @questions[@current_index]
  end

  def create
    @answer = @situation.answers.find_or_initialize_by(user: current_user)
    @answer.responses ||= {}

    # パラメータから現在の質問の回答を追加
    question_id = params[:question_id]
    @answer.responses[question_id] = params[:response]

    # 最初の回答なら開始時間をセット
    @answer.started_at ||= Time.current

    # 次の質問があれば new にリダイレクト
    next_index = params[:next_index].to_i

    if next_index >= @situation.questions.count
      @answer.finished_at = Time.current
      if @answer.save
        redirect_to situation_answer_path(@situation, @answer), notice: '面接が完了しました。'
      else
        flash.now[:alert] = '保存に失敗しました'
        render :new
      end
    else
      @answer.save(validate: false) # 一時保存
      redirect_to new_situation_answer_path(@situation, index: next_index)
    end
  end

  def show
    @answer = @situation.answers.find_by(user: current_user)
    @questions = @situation.questions.order(:order)
  end

  private

  def set_situation
    @situation = Situation.find(params[:situation_id])
  end
end
