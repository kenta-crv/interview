class ProblemMailer < ApplicationMailer
  default to: "info@j-work.jp"

  def report_email(problem)
    @problem = problem
    attach_photo_if_present!(problem)

    mail(
      to: "info@j-work.jp",
      from: @problem.email,
      subject: t("meetia.problems.mail_subject", company: @problem.company)
    )
  end

  private

  def attach_photo_if_present!(problem)
    return unless problem.photo.present?

    filename = problem.photo.identifier.presence
    return if filename.blank?

    content = problem.photo.read
    return if content.blank?

    attachments.inline[filename] = content
  rescue StandardError => e
    Rails.logger.warn("[ProblemMailer] photo attach skipped: #{e.class}: #{e.message}")
  end
end
