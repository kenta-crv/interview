class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :interviews, dependent: :destroy
  has_many :interview_results, through: :interviews
  has_many :contracts, dependent: :destroy
  has_many :user_progresses, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  def full_name
    "#{company} #{name}".strip
  end
end
