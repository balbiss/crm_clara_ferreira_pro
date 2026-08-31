class AddAudienceToNotifications < ActiveRecord::Migration[8.1]
  def change
    # Notification hoje é conta inteira (sem user_id) — nunca tinha sido usada
    # de verdade (0 linhas em produção, Notification.create não existia em
    # lugar nenhum do código antes disso). audience nulo preserva esse
    # comportamento (visível pra todo mundo); 'owner_level' restringe a quem
    # é gerente/diretoria (User::OWNER_LEVEL_ROLES) — usado pelo aviso de
    # revendedor.created, que só interessa a quem gerencia carteira.
    add_column :notifications, :audience, :string
  end
end
