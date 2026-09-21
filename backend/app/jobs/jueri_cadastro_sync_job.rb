# Recorrente separado do JueriSyncJob (30min) — só cadastro (nome/telefone/
# endereço etc), sem histórico de pedido. Existe porque o Jueri não manda
# webhook pra mudança de cadastro (ver comentário em
# JueriSyncService#sync_cadastro), então uma troca de telefone só era vista
# no próximo ciclo completo de 30min. Como esse fast path é bem mais barato
# (só pagina /revendedor, sem find_revendedor nem pedido), roda a cada 5min
# sem risco de rate limit.
class JueriCadastroSyncJob < ApplicationJob
  queue_as :default

  def perform
    return unless JueriApiService.configured?

    Account.find_each do |account|
      resultado = JueriSyncService.new(account: account).sync_cadastro
      Rails.logger.info("[JueriCadastroSyncJob] account=#{account.id} erros=#{resultado[:erros]}")
    rescue JueriApiService::ApiError => e
      Rails.logger.error("[JueriCadastroSyncJob] account=#{account.id} falhou: #{e.message}")
    end
  end
end
