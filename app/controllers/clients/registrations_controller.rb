# frozen_string_literal: true

class Clients::RegistrationsController < Devise::RegistrationsController
  layout "auth"

  before_action :reject_client_auth_while_admin!, only: [:new, :create]
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]
  before_action :stash_oauth_locale_from_auth_page, only: [:new]

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :company,
      :name,
      :tel,
      :address,
      :url,
      :preferred_locale
    ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :company,
      :name,
      :tel,
      :address,
      :url,
      :preferred_locale
    ])
  end

  def new
    if !request.path.to_s.match?(%r{\A/en(/|\z)}) && english_auth_entry_bounce?
      redirect_to new_client_registration_en_path(locale: :en) and return
    end

    super
  end

  def create
    build_resource(sign_up_params)
    resource.preferred_locale = resolved_signup_locale
    resource.save
    yield resource if block_given?
    if resource.persisted?
      persist_ui_locale!(resource.preferred_locale)
      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, resource)
        persist_ui_locale!(resource.preferred_locale)
        I18n.locale = resource.preferred_locale.to_sym
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  def after_sign_up_path_for(_resource)
    resource = _resource
    resource.initialize_trial_subscription! if resource.respond_to?(:initialize_trial_subscription!)
    mark_yahoo_trial_conversion!
    dashboard_index_path
  end

  private

  def stash_oauth_locale_from_auth_page
    session[:omniauth_locale] = auth_url_locale
  end

  def resolved_signup_locale
    auth_url_locale
  end
end
