class Contact < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  has_many :conversations, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :pipeline_cards, dependent: :destroy
  has_many :pedidos, dependent: :destroy
  has_many :reseller_phones, dependent: :destroy
  has_many :lifecycle_events, dependent: :destroy
  has_many :tarefas, dependent: :destroy

  BROADCAST_FIELDS = %w[name first_name last_name phone temperature status source intention user_id avatar_url].freeze

  # Status "ativo" que reinicia o ciclo da régua consignada (briefing seção 12) quando o
  # consultor move a revendedora de volta pra cá após um acerto.
  CYCLE_RESTART_STATUS = 'revendedor_ativo'

  # Grupo "Inativas" do briefing (seção 14) — espelha constants/regua.js do frontend.
  # Usado pelo JueriSyncService pra saber quando uma revendedora que voltou a ter
  # pedido em aberto está "reativando" um ciclo (em vez de só continuando um já ativo).
  INACTIVE_STATUSES = %w[sem_maleta inativa_pendencia suspensa_atraso negativado_juridico resgate reativacao descadastrada].freeze

  # Grupo "Ativas" do briefing (seção 11) — espelha constants/regua.js do frontend.
  # Usado pelo JueriSyncService pra saber quem saiu do ciclo (não tem mais pedido
  # aberto acima do limiar) e precisa deixar de ser tratada como Ativa.
  ACTIVE_STATUSES = %w[revendedor_ativo terceiro_dia decimo_dia vigesimo_dia agendado reagendar atrasada].freeze

  # Decisão manual PERMANENTE (briefing seção 19/29.9) — nunca reativa sozinha
  # via sync, e nunca conta como Ativa em nenhuma data (Time Travel incluso),
  # mesmo que os pedidos no Jueri digam o contrário. Fonte única usada por
  # JueriSyncService (não-reativação automática) e AtivasSnapshotService
  # (exclusão do Time Travel) — não duplicar essa lista em outro lugar.
  STATUS_OVERRIDE_PERMANENTE = %w[resgate negativado_juridico descadastrada].freeze

  # Dias inativa + sem pendência financeira exigidos pra virar elegível pra
  # Reativação de verdade (briefing seção 20; distinto do marco de ciclo de
  # vida "reativacao" em lifecycle_events, que é mais estrito que "só voltou
  # a ficar ativa" — exige esse tempo mínimo dormente).
  DIAS_MINIMOS_PARA_REATIVACAO = 60

  before_save :track_regua_status_change
  before_save :extrair_telefones_adicionais_do_jsonb
  after_save :persistir_telefones_adicionais_na_tabela
  after_save :broadcast_contact_update, if: -> { saved_changes.keys.any? { |k| BROADCAST_FIELDS.include?(k) } }
  after_save :run_regua_triggers, if: -> { saved_change_to_status? && status.present? }

  def channel_identifier
    jid.presence || instagram_id.presence || phone
  end

  # Uma revendedora pode falar por vários números (dela, da irmã, da filha etc. —
  # briefing seção 7). Casa pelo telefone principal OU por qualquer telefone na
  # tabela reseller_phones, pra nunca criar um contato duplicado só porque a
  # mensagem chegou de outro número.
  #
  # Migrado do containment jsonb (custom_attributes->telefones_adicionais @>)
  # pra JOIN com reseller_phones — o jsonb não usava índice nenhum nessa busca
  # (containment sem GIN dedicado é sequential scan); agora é um índice B-Tree
  # comum em reseller_phones.phone.
  def self.find_by_any_phone(account_id, phone)
    return nil if phone.blank?
    where(account_id: account_id)
      .left_joins(:reseller_phones)
      .where("contacts.phone = :phone OR reseller_phones.phone = :phone", phone: phone)
      .first
  end

  scope :not_blacklisted, -> { where(desconsiderado: false) }

  private

  def track_regua_status_change
    return unless status_changed?
    self.status_changed_at = Time.current unless will_save_change_to_attribute?(:status_changed_at)
    if status == CYCLE_RESTART_STATUS || status.blank?
      self.cycle_started_at = Time.current unless will_save_change_to_attribute?(:cycle_started_at)
    end
  end

  # A tabela reseller_phones é a fonte de verdade agora (ver find_by_any_phone),
  # mas o frontend (EditContactModal) e o JueriSyncService continuam mandando
  # os telefones adicionais dentro de custom_attributes["telefones_adicionais"]
  # — zero mudança de contrato pro chamador. Aqui a gente intercepta esse valor
  # antes de salvar, tira do jsonb (não duplica fonte de verdade) e guarda pra
  # gravar na tabela relacional depois que o contato tiver id (after_save).
  def extrair_telefones_adicionais_do_jsonb
    return unless custom_attributes.is_a?(Hash) && custom_attributes.key?('telefones_adicionais')
    @telefones_adicionais_pendentes = custom_attributes['telefones_adicionais']
    self.custom_attributes = custom_attributes.except('telefones_adicionais')
  end

  def persistir_telefones_adicionais_na_tabela
    return unless @telefones_adicionais_pendentes
    tels = Array(@telefones_adicionais_pendentes)
    numeros_novos = tels.filter_map { |t| t.is_a?(Hash) ? (t['numero'] || t[:numero]) : nil }.reject(&:blank?)

    reseller_phones.where.not(phone: numeros_novos).destroy_all
    tels.each do |t|
      numero = t.is_a?(Hash) ? (t['numero'] || t[:numero]) : nil
      next if numero.blank?
      label = t.is_a?(Hash) ? (t['label'] || t[:label]) : nil
      rp = reseller_phones.find_or_initialize_by(phone: numero)
      rp.label = label if label.present?
      rp.save!
    end
    @telefones_adicionais_pendentes = nil
  end

  def broadcast_contact_update
    ActionCable.server.broadcast("conversations_channel_#{account_id}", {
      event: 'contact_updated',
      contact_id: id
    })
  end

  def run_regua_triggers
    ReguaTriggerRunnerService.new(self).call
  end
end
