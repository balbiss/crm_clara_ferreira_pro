class CreateFlows < ActiveRecord::Migration[8.1]
  def change
    # "Fluxos" — construtor visual de automação de conversa (MVP). Mesmo
    # padrão de pipelines/pipeline_stages/pipeline_triggers (container +
    # nós + config jsonb), mas com grafo livre (nós+conexões) em vez de
    # etapas lineares.
    create_table :flows do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :channel
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :flows, [:account_id, :active]

    # key = UUID gerado no frontend, é o identificador que o Vue Flow usa
    # pro node (não o id interno do Rails) — evita ter que remapear id
    # depois de criar durante o autosave/drag.
    create_table :flow_nodes do |t|
      t.references :flow, null: false, foreign_key: true
      t.string :key, null: false
      t.string :node_type, null: false
      t.jsonb :position, null: false, default: {}
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end

    add_index :flow_nodes, [:flow_id, :key], unique: true

    create_table :flow_edges do |t|
      # t.references já cria o índice em flow_id sozinho — não duplicar com
      # add_index (foi exatamente esse duplicate index que quebrou o boot
      # em produção na primeira tentativa de deploy: PG::DuplicateTable).
      t.references :flow, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :target_key, null: false
      t.string :source_handle
      t.string :target_handle

      t.timestamps
    end
  end
end
