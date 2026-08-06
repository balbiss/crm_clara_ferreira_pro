class RemapLegacyUserRoles < ActiveRecord::Migration[8.1]
  # role era: atendente:0, empresa:1, admin:2, consultor:3, gerente:4, diretoria:5, financeiro:6
  # vira:     consultor:0, gerente:1, diretoria:2, financeiro:3
  #
  # Remapeamento (briefing seção 30 — só os 4 perfis reais da Clara ficam):
  #   atendente(0) -> consultor(0)
  #   empresa(1)   -> diretoria(2)
  #   admin(2)     -> diretoria(2)  (console SaaS Master removido, ver commit)
  #   consultor(3) -> consultor(0)
  #   gerente(4)   -> gerente(1)
  #   diretoria(5) -> diretoria(2)
  #   financeiro(6)-> financeiro(3)
  #
  # UPDATE unico com CASE (nao sequencial) pra nao remapear duas vezes o mesmo valor.
  def up
    execute <<~SQL
      UPDATE users SET role = CASE role
        WHEN 0 THEN 0
        WHEN 1 THEN 2
        WHEN 2 THEN 2
        WHEN 3 THEN 0
        WHEN 4 THEN 1
        WHEN 5 THEN 2
        WHEN 6 THEN 3
        ELSE role
      END
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Remapeamento com perda de informacao (empresa/admin/diretoria colapsam em diretoria) - sem volta automatica."
  end
end
