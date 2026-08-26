# frozen_string_literal: true

class Clients::PasswordsController < Devise::PasswordsController
  layout "auth"

  def new
    super
  end

  def edit
    if !request.path.to_s.match?(%r{\A/en(/|\z)})
      client = resource_class.with_reset_password_token(params[:reset_password_token].to_s)
      if client&.preferred_locale.to_s == "en"
        redirect_to edit_client_password_en_path(
          locale: :en,
          reset_password_token: params[:reset_password_token]
        ) and return
      end
    end

    super
  end

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  end

  protected

  def after_sending_reset_password_instructions_path_for(_resource_name)
    helpers.client_sign_in_path_for_locale
  end
end
