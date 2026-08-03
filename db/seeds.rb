# Seed mínimo: só a conta e os usuários de login. Dados de revendedora (Contact) NÃO
# são mais seedados aqui — vêm exclusivamente da sincronização com o Jueri
# (JueriApiService). Idempotente de propósito: não apaga dados reais existentes.
#
# ATENÇÃO: troque essas senhas antes de rodar em qualquer ambiente compartilhado.

account = Account.find_or_create_by!(name: 'Clara Ferreira Acessórios')

User.find_or_create_by!(email: 'admin@claraferreira.example.com') do |u|
  u.account = account
  u.password = 'MudeEstaSenha123!'
  u.password_confirmation = 'MudeEstaSenha123!'
  u.first_name = 'Clara'
  u.last_name = 'Ferreira'
  # 'admin' aqui seria admin GLOBAL do SaaS (equipe técnica, vê todas as empresas) —
  # a dona da Clara Ferreira precisa de 'empresa' (dono/acesso total só na própria
  # conta). Login.vue redireciona role 'admin' pro painel /admin (SaaS Master), não
  # pro dashboard normal — usar :admin aqui por engano manda a dona pro painel errado.
  u.role = :empresa
end

# Vendedora (papel "atendente" no schema atual — vira "consultor" na Fase 2)
User.find_or_create_by!(email: 'vendedora@claraferreira.example.com') do |u|
  u.account = account
  u.password = 'MudeEstaSenha123!'
  u.password_confirmation = 'MudeEstaSenha123!'
  u.first_name = 'Beatriz'
  u.last_name = 'Lima'
  u.role = :atendente
  u.department = 'vendedora'
end

# Pipelines customizáveis (espelham o Kommo que a empresa já usava — Varejo,
# Onboarding, Atacado, Prospecção). Consignado NÃO entra aqui: usa a régua automática
# em Contact#status, não esse sistema genérico. Idempotente — find_or_create_by! não
# duplica se já existir.
{
  'Varejo'      => %w[Novo\ Lead Qualificando Negociando Fechado],
  'Onboarding'  => %w[Cadastro\ Recebido Documentação Primeira\ Maleta Concluído],
  'Atacado'     => %w[Novo\ Contato Proposta\ Enviada Negociando Fechado],
  'Prospecção'  => %w[Novo\ Lead Em\ Contato Qualificado Descartado]
}.each_with_index do |(nome, etapas), index|
  pipeline = Pipeline.find_or_create_by!(account: account, name: nome) do |p|
    p.position = index + 1
  end
  next if pipeline.pipeline_stages.any?

  etapas.each_with_index do |etapa, stage_index|
    pipeline.pipeline_stages.create!(name: etapa, position: stage_index)
  end
end

puts "Seed concluído — conta, usuários de login e pipelines prontos. Revendedoras vêm do Jueri."
