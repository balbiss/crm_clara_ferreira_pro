class Note < ApplicationRecord
  belongs_to :contact
  belongs_to :user, optional: true
  belongs_to :account
end
