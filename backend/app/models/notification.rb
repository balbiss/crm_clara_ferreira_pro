class Notification < ApplicationRecord
  belongs_to :account

  # audience nulo = conta inteira (todo mundo vê no sino); 'owner_level' =
  # só gerente/diretoria (User::OWNER_LEVEL_ROLES) — ver aviso de
  # revendedor.created em Webhooks::JueriController.
  AUDIENCES = %w[owner_level].freeze

  scope :visible_to, ->(user) {
    audiences = [nil]
    audiences << 'owner_level' if user.owner_level?
    where(audience: audiences)
  }
end
