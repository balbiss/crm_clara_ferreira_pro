class PipelineStage < ApplicationRecord
  belongs_to :pipeline
  has_many :pipeline_cards, dependent: :destroy
  has_many :pipeline_triggers, -> { order(:position) }, dependent: :destroy

  validates :name, presence: true
end
