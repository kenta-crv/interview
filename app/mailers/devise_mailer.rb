class DeviseMailer < Devise::Mailer
  def devise_mail(record, action, opts = {}, &block)
    I18n.with_locale(locale_for(record)) { super }
  end

  private

  def locale_for(record)
    loc = if record.respond_to?(:ui_locale)
            record.ui_locale.to_s
          elsif record.respond_to?(:preferred_locale)
            record.preferred_locale.to_s
          else
            I18n.locale.to_s
          end
    %w[ja en].include?(loc) ? loc : I18n.locale
  end
end
