class ApplicationController < ActionController::Base
  include MetaTags::ControllerHelper

  before_action :init_breadcrumbs
  helper_method :breadcrumbs
  before_action :check_trial_expiration

  def check_trial_expiration
    return unless current_client.present?
    current_client.check_and_upgrade_expired_trial
  end

  def breadcrumbs
    @breadcrumbs
  end

  def add_breadcrumb(label, path = nil)
    @breadcrumbs << { label: label, path: path }
  end
  protected

  def after_sign_in_path_for(resource)
    case resource
    when Admin
      dashboard_root_path
    when Client
      dashboard_root_path
    else
      root_path
    end
  end
  
  private

  def init_breadcrumbs
    @breadcrumbs = []
  end

  # ここを修正：生のJSONではなく、普通のブラウザアクセス時はログイン画面へ強制リダイレクトさせます
  def authenticate_client!
    unless client_signed_in?
      respond_to do |format|
        # APIや非同期通信からのリクエストに対してはJSONを返す
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
        # 通常のブラウザによるリンク移動やアクセスに対しては、企業用ログイン画面へリダイレクト
        format.all  { redirect_to new_client_session_path, alert: 'ログインが必要です。' }
      end
    end
  end
end