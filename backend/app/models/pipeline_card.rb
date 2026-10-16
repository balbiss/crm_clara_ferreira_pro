# Representa um contato dentro de um pipeline customizado (não confundir com
# Contact#status, que é a régua do Consignado). Um mesmo contato pode estar em vários
# pipelines ao mesmo tempo (ex: Varejo e Prospecção), mas só uma vez em cada.
class PipelineCard < ApplicationRecord
  belongs_to :pipeline
  belongs_to :pipeline_stage
  belongs_to :contact

  validates :contact_id, uniqueness: { scope: :pipeline_id }
  validate :stage_belongs_to_pipeline

  # Mudou de etapa: o gatilho "quando o cliente responder" da etapa NOVA volta
  # a valer (ver PipelineTriggerRunnerService#call_for_client_reply).
  before_update :reset_reply_trigger_flag, if: :pipeline_stage_id_changed?

  private

  def reset_reply_trigger_flag
    self.reply_triggered_at = nil
  end

  def stage_belongs_to_pipeline
    return if pipeline_stage.nil? || pipeline.nil?
    errors.add(:pipeline_stage, 'não pertence a este pipeline') if pipeline_stage.pipeline_id != pipeline_id
  end
end
