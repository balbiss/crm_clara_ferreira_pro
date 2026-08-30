# Base de Conhecimento da Secretária Virtual (RAG simples, por caixa de
# entrada) — texto colado direto ou extraído de PDF pelo usuário, injetado
# no prompt da IA (ver AiAssistantService#build_system_prompt). Texto
# moderado (não é uma base gigante com busca vetorial), por isso injeção
# direta no prompt em vez de embeddings/vector search.
class AddKnowledgeBaseToInboxes < ActiveRecord::Migration[8.1]
  def change
    add_column :inboxes, :knowledge_base, :text
  end
end
