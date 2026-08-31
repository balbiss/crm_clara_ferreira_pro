class CreateJueriActivities < ActiveRecord::Migration[8.1]
  def change
    # Feed de atividade genérico pra TODO evento que a Jueri manda pro nosso
    # webhook (revendedor.*/pedido.*/venda.*/financeiro.*) — inspirado no
    # painel "Atividades do Dia" da própria Jueri, que mostra muito mais
    # coisa do que o CRM hoje reflete (cadastro novo, pré-baixa de pedido,
    # etc). Sem notificação/push aqui de propósito (volume alto — pedido
    # aberto muda de valor várias vezes por dia); é só uma tela de consulta
    # pra gerência. contact_id é opcional porque revendedor.created pode
    # chegar pra alguém que ainda nem virou Contact (sem pedido aberto ainda,
    # ver Contact::ACTIVE_STATUSES).
    create_table :jueri_activities do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: true, foreign_key: true

      t.string :evento, null: false
      t.string :descricao, null: false
      t.datetime :ocorrido_em, null: false
      t.jsonb :payload, default: {}

      t.timestamps
    end

    add_index :jueri_activities, [:account_id, :ocorrido_em]
  end
end
