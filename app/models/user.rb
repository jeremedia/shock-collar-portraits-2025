class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :invitable, :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Ahoy associations
  has_many :visits, class_name: "Ahoy::Visit"
  has_many :events, class_name: "Ahoy::Event"
end
