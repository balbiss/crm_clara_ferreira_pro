# Representa um contato dentro de um pipeline customizado (não confundir com
# Contact#status, que é a régua do Consignado). Um mesmo contato pode estar em vários
# pipelines ao mesmo tempo (ex: Varejo e Prospecção), mas só uma vez em cada.
class PipelineCard < ApplicationRecord
  belongs_to :pipeline
  belongs_to :pipeline_stage
  belongs_to :contact

  validates :contact_id, uniqueness: { scope: :pipeline_id }
  validate :stage_belongs_to_pipeline

  private

  def stage_belongs_to_pipeline
    return if pipeline_stage.nil? || pipeline.nil?
    errors.add(:pipeline_stage, 'não pertence a este pipeline') if pipeline_stage.pipeline_id != pipeline_id
  end
end
