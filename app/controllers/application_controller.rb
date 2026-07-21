class ApplicationController < ActionController::Base
  include MetaTags::ControllerHelper

  layout :layout_for_request

  before_action :set_locale
  before_action :init_breadcrumbs
  helper_method :breadcrumbs, :current_locale, :locale_root_href, :href_for_locale, :available_ui_locales
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

  def current_locale
    I18n.locale
  end

  def available_ui_locales
    %i[ja en]
  end

  def locale_root_href
    if params[:locale].present?
      localized_root_path(locale: params[:locale])
    else
      root_path
    end
  end

  # /plans <-> /en/plans 。対象外ページではトップへ。
  # *_path 名は Rails のルートヘルパーと衝突するため使わない。
  def href_for_locale(target_locale)
    target = target_locale.to_s.to_sym
    return locale_root_href if target.blank?

    path = request.path.to_s.sub(%r{\A/en(?=/|$)}, "")
    path = "/" if path.blank?

    public_page = controller_path == "tops" || controller_path == "plans"
    if public_page
      target == :ja ? path : (path == "/" ? "/en" : "/en#{path}")
    else
      target == :ja ? root_path : "/en"
    end
  end
  protected

  def set_locale
    requested = params[:locale].presence&.to_sym
    I18n.locale = if requested && I18n.available_locales.map(&:to_sym).include?(requested)
                    requested
                  else
                    I18n.default_locale
                  end
  end

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

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  def layout_for_request
    return "auth" if devise_controller?

    if controller_path == "public/deal_sessions"
      return "presentation" if action_name == "conversation"
      return "deal_public" if %w[show create_user_info].include?(action_name)
    end

    "application"
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