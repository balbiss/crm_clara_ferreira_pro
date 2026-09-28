class MessageTemplate < ApplicationRecord
  belongs_to :account

  validates :nome, presence: true
  validates :mensagem, presence: true

  scope :ordered, -> { order(:nome) }
end
