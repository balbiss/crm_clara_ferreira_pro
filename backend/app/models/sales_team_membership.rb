# Quem (além do responsável direto via User#jueri_gerente_id) pode ver a
# carteira inteira de um SalesTeam — múltiplos operadores por time, igual ao
# "gerenciar agendas" do próprio Jueri (ver briefing/vídeo do cliente).
class SalesTeamMembership < ApplicationRecord
  belongs_to :sales_team
  belongs_to :user
end
