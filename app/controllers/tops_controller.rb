class TopsController < ApplicationController

  def index
  end
  
  def interview
    # ログイン中のクライアントがいれば、モデル側に定義したトライアル自動アップグレードを実行
    current_client&.check_and_upgrade_expired_trial

    # 既存のロジック
    @situations = Situation.where(archived: false).order(:title)
  end

  private

end