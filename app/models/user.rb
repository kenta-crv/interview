class User < ApplicationRecord
  GUEST_EMAIL_DOMAIN = "guest.meetia.local".freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews
  has_many :contracts, dependent: :destroy
  has_many :user_progresses, dependent: :destroy

  validates :name, presence: true
  validates :job_title, presence: true
  validates :email, presence: true, uniqueness: true

  def full_name
    "#{company} #{name}".strip
  end

  def guest?
    email.to_s.end_with?("@#{GUEST_EMAIL_DOMAIN}")
  end

  def self.guest_email
    "guest-#{SecureRandom.uuid}@#{GUEST_EMAIL_DOMAIN}"
  end

  def self.build_guest!(attrs = {})
    create!(
      email: attrs[:email].presence || guest_email,
      name: attrs[:name].presence || "ゲスト",
      job_title: attrs[:job_title].presence || "-",
      company: attrs[:company],
      tel: attrs[:tel],
      address: attrs[:address],
      url: attrs[:url],
      password: SecureRandom.hex(16)
    )
  end
end
