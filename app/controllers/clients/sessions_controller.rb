# frozen_string_literal: true

class Clients::SessionsController < Devise::SessionsController
  layout "auth"

  before_action :reject_client_auth_while_admin!, only: [:new, :create]

  def new
    if !request.path.to_s.match?(%r{\A/en(/|\z)}) && english_auth_entry_bounce?
      redirect_to new_client_session_en_path(locale: :en) and return
    end

    session[:omniauth_locale] = auth_url_locale
    super
  end

  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    # ログイン画面の言語を優先（preferred_locale でダッシュボード言語が逆転しないようにする）
    locale = auth_url_locale
    if resource.respond_to?(:preferred_locale) && resource.preferred_locale != locale
      resource.update(preferred_locale: locale)
    end
    persist_ui_locale!(locale)
    I18n.locale = locale.to_sym
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  protected

  def after_sign_out_path_for(_resource_or_scope)
    locale_root_href
  end
end
