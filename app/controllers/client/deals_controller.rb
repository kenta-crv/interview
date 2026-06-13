# app/controllers/client/deals_controller.rb
class Client::DealsController < ApplicationController
  before_action :authenticate_client!
  before_action :set_deal, only: [:show, :edit, :update, :destroy, :presentation]

  before_action :load_deal_associations, only: [:show, :presentation]

  def index
    @deals = current_client.deals.includes(:deal_documents, :deal_audios, :deal_transcript, :deal_summary, :deal_speeches).order(created_at: :desc)
  end

  def show
    @deal_audio = @deal.deal_audios.first
    @segments = @deal_audio&.deal_segments&.in_order || []
    @situations = current_client.situations.active
  end

  def presentation
    @deal_pages = @deal.deal_pages.order(:page_number)
  end

  def new
    @deal = current_client.deals.build
  end

  def create
    @deal = current_client.deals.build(deal_params)

    if @deal.save
      redirect_to client_deal_path(@deal), notice: '商談を作成しました'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @deal.update(deal_params)
      redirect_to client_deal_path(@deal), notice: '商談を更新しました'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @deal.destroy
    redirect_to client_deals_path, notice: '商談を削除しました'
  end

  private

  def set_deal
    @deal = current_client.deals.find(params[:id])
  end

  def load_deal_associations
    @deal = Deal.includes(:deal_summary, :deal_speeches).find(@deal.id)
  end

  def deal_params
    params.require(:deal).permit(:title, :description, :deal_date, :language)
  end
end
