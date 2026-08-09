class ApplicationController < ActionController::Base
  include MetaTags::ControllerHelper

  layout :layout_for_request

  before_action :set_locale
  before_action :init_breadcrumbs
  helper_method :breadcrumbs, :current_locale, :locale_root_href, :href_for_locale,
                :available_ui_locales, :locale_switch_path_for
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
    if I18n.locale.to_s == "en"
      localized_root_path(locale: :en)
    else
      root_path
    end
  end

  # 公開ページは / <-> /en。認証・plans も同様。それ以外は locale 切替エンドポイントへ。
  def href_for_locale(target_locale)
    target = target_locale.to_s
    return locale_root_href if target.blank?

    path = request.path.to_s.sub(%r{\A/en(?=/|$)}, "")
    path = "/" if path.blank?

    if public_switchable_path?(path)
      target == "ja" ? path : (path == "/" ? "/en" : "/en#{path}")
    else
      locale_switch_path_for(target, return_to: request.fullpath)
    end
  end

  def locale_switch_path_for(target_locale, return_to: nil)
    switch_locale_path(locale: target_locale, return_to: return_to.presence || request.fullpath)
  end

  protected

  def set_locale
    locale = resolve_ui_locale
    I18n.locale = locale
    session[:ui_locale] = locale.to_s
  end

  def resolve_ui_locale
    requested = params[:locale].presence.to_s
    return requested.to_sym if Client::LOCALES.include?(requested)

    # /en なしの公開URLは明示的に日本語（session に en が残っていても上書き）
    path = request.path.to_s.sub(%r{\A/en(?=/|$)}, "")
    path = "/" if path.blank?
    return :ja if public_switchable_path?(path)

    if client_signed_in? && current_client.preferred_locale.present?
      return current_client.ui_locale
    end

    session_locale = session[:ui_locale].to_s
    return session_locale.to_sym if Client::LOCALES.include?(session_locale)

    :ja
  end

  def public_switchable_path?(path)
    path == "/" ||
      path == "/plans" ||
      path.start_with?("/plans") ||
      path == "/interview" ||
      path.start_with?("/interview") ||
      path.start_with?("/clients/sign_in") ||
      path.start_with?("/clients/sign_up") ||
      path.start_with?("/clients/password")
  end

  def after_sign_in_path_for(resource)
    case resource
    when Admin
      dashboard_root_path
    when Client
      dashboard_root_path
    else
      locale_root_href
    end
  end

  def after_sign_out_path_for(_resource_or_scope)
    locale_root_href
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

  def authenticate_client!
    unless client_signed_in?
      respond_to do |format|
        format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
        format.all do
          redirect_to(
            (I18n.locale.to_s == "en" ? new_client_session_en_path(locale: :en) : new_client_session_path),
            alert: t("meetia.auth.login_required")
          )
        end
      end
    end
  end
end
