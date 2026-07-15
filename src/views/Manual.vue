<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import {
  MessageCircle, Users, Home, Building, CalendarDays, Kanban,
  TrendingUp, Badge, Settings, CreditCard, BrainCircuit, Bell,
  BookOpen, ChevronRight, Search, Bot, Zap, Shield, ArrowRightLeft
} from 'lucide-vue-next'

const activeSection = ref('visao-geral')
const searchQuery   = ref('')

const sections = [
  { id: 'visao-geral',    label: 'Visão Geral',             icon: BookOpen },
  { id: 'conversas',      label: 'Conversas',               icon: MessageCircle },
  { id: 'matching',       label: 'Matching Lead ↔ Imóvel',  icon: Zap },
  { id: 'transferencia',  label: 'Transferência de Conversa', icon: ArrowRightLeft },
  { id: 'contatos',       label: 'Contatos / Leads',        icon: Users },
  { id: 'imoveis',        label: 'Imóveis',                 icon: Home },
  { id: 'condominios',    label: 'Condomínios',             icon: Building },
  { id: 'agendamentos',   label: 'Agendamentos',            icon: CalendarDays },
  { id: 'funil',          label: 'Funil de Vendas',         icon: Kanban },
  { id: 'relatorios',     label: 'Relatórios',              icon: TrendingUp },
  { id: 'agentes',        label: 'Agentes',                 icon: Badge },
  { id: 'configuracoes',  label: 'Configurações',           icon: Settings },
  { id: 'cobranca',       label: 'Cobrança (Asaas)',        icon: CreditCard },
  { id: 'ia',             label: 'Inteligência Artificial', icon: BrainCircuit },
  { id: 'notificacoes',   label: 'Notificações Push',       icon: Bell },
  { id: 'permissoes',     label: 'Permissões',              icon: Shield },
]

const filteredSections = ref(sections)

const filterSections = () => {
  const q = searchQuery.value.toLowerCase()
  filteredSections.value = q
    ? sections.filter(s => s.label.toLowerCase().includes(q))
    : sections
}

const scrollTo = (id) => {
  activeSection.value = id
  const el = document.getElementById(id)
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

const handleScroll = () => {
  for (const s of [...sections].reverse()) {
    const el = document.getElementById(s.id)
    if (el && el.getBoundingClientRect().top <= 120) {
      activeSection.value = s.id
      break
    }
  }
}

onMounted(() => document.querySelector('.manual-content')?.addEventListener('scroll', handleScroll))
onUnmounted(() => document.querySelector('.manual-content')?.removeEventListener('scroll', handleScroll))
</script>

<template>
  <div class="manual-page">

    <!-- Sidebar nav -->
    <aside class="manual-nav">
      <div class="nav-header">
        <BookOpen :size="16" />
        <span>Manual do Sistema</span>
      </div>

      <div class="nav-search">
        <Search :size="13" />
        <input v-model="searchQuery" @input="filterSections" placeholder="Buscar seção..." />
      </div>

      <nav>
        <button
          v-for="s in filteredSections"
          :key="s.id"
          class="nav-link"
          :class="{ active: activeSection === s.id }"
          @click="scrollTo(s.id)"
        >
          <component :is="s.icon" :size="14" />
          {{ s.label }}
          <ChevronRight :size="12" class="arrow" />
        </button>
      </nav>
    </aside>

    <!-- Content -->
    <div class="manual-content">
      <div class="content-inner">

        <!-- ══════════════════════════════════════ VISÃO GERAL -->
        <section id="visao-geral">
          <h1>Visão Geral do Sistema</h1>
          <p class="lead">O <strong>VisitaIA CRM</strong> é uma plataforma completa de gestão de relacionamento para imobiliárias. Ele centraliza conversas do WhatsApp, leads, imóveis, agendamentos e cobranças em um único lugar.</p>

          <div class="cards-row">
            <div class="info-card">
              <MessageCircle :size="20" />
              <div>
                <strong>Atendimento unificado</strong>
                <p>Todas as conversas do WhatsApp em um painel único, com histórico completo e atendimento por múltiplos agentes.</p>
              </div>
            </div>
            <div class="info-card">
              <Bot :size="20" />
              <div>
                <strong>IA integrada</strong>
                <p>Assistente de IA responde automaticamente, resume conversas e sugere prompts personalizados por canal.</p>
              </div>
            </div>
            <div class="info-card">
              <Zap :size="20" />
              <div>
                <strong>Automação</strong>
                <p>Rodízio automático de leads entre corretores, mensagens agendadas e notificações em tempo real.</p>
              </div>
            </div>
          </div>

          <h2>Estrutura do sistema</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Módulo</th><th>Quem acessa</th><th>Função principal</th></tr></thead>
              <tbody>
                <tr><td>Dashboard</td><td>Todos</td><td>KPIs, leads do dia, funil</td></tr>
                <tr><td>Conversas</td><td>Todos</td><td>Chat WhatsApp em tempo real</td></tr>
                <tr><td>Contatos</td><td>Todos*</td><td>Base de leads com histórico</td></tr>
                <tr><td>Imóveis</td><td>Todos*</td><td>Catálogo de propriedades</td></tr>
                <tr><td>Condomínios</td><td>Todos*</td><td>Lançamentos e empreendimentos</td></tr>
                <tr><td>Agendamentos</td><td>Todos</td><td>Visitas e compromissos</td></tr>
                <tr><td>Funil</td><td>Todos</td><td>Pipeline visual de vendas</td></tr>
                <tr><td>Relatórios</td><td>Todos</td><td>Performance e métricas</td></tr>
                <tr><td>Agentes</td><td>Dono/Admin</td><td>Gerenciar equipe</td></tr>
                <tr><td>Configurações</td><td>Dono/Admin</td><td>Canais, tags, integrações</td></tr>
                <tr><td>Cobrança</td><td>Financeiro+</td><td>PIX e boleto pelo WhatsApp</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">* Corretores veem apenas seus próprios registros. Donos e admins veem tudo.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONVERSAS -->
        <section id="conversas">
          <h1>Conversas</h1>
          <p class="lead">O painel de conversas é o centro operacional do CRM. Todas as mensagens recebidas pelo WhatsApp aparecem aqui em tempo real.</p>

          <h2>Layout do painel</h2>
          <p>O painel é dividido em três colunas:</p>
          <ol>
            <li><strong>Lista de conversas</strong> (esquerda) — todas as conversas com filtros e busca</li>
            <li><strong>Chat</strong> (centro) — histórico completo de mensagens</li>
            <li><strong>Detalhes do contato</strong> (direita) — informações do lead em tempo real</li>
          </ol>

          <h2>Status das conversas</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Status</th><th>Significado</th></tr></thead>
              <tbody>
                <tr><td><span class="badge green">Aberta</span></td><td>Conversa ativa, aguardando ou em atendimento</td></tr>
                <tr><td><span class="badge yellow">Pendente</span></td><td>Aguardando resposta do cliente</td></tr>
                <tr><td><span class="badge gray">Resolvida</span></td><td>Atendimento encerrado</td></tr>
                <tr><td><span class="badge blue">Adiada</span></td><td>Pausada com data para retomar automaticamente</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Envio de mensagens</h2>
          <ul>
            <li><strong>Texto:</strong> Digite e pressione Enter ou clique em enviar</li>
            <li><strong>Anexos:</strong> Clique no ícone de clipe para enviar arquivos, imagens ou áudio</li>
            <li><strong>Emojis:</strong> Clique no ícone de emoji para abrir o seletor</li>
            <li><strong>Mensagem privada:</strong> Ative o modo "nota interna" para mensagens visíveis apenas para a equipe</li>
            <li><strong>Agendar mensagem:</strong> Clique no ícone de relógio para enviar em horário específico</li>
          </ul>

          <h2>Atribuição de conversas</h2>
          <ul>
            <li>Novas conversas entram automaticamente e são distribuídas via <strong>rodízio automático</strong> entre os corretores disponíveis</li>
            <li>O gestor pode reatribuir manualmente no painel lateral direito</li>
            <li>O agente recebe notificação pelo WhatsApp pessoal e push notification no celular</li>
          </ul>

          <h2>Tags</h2>
          <p>Tags colorem e categorizam conversas. Para adicionar: clique no ícone de etiqueta na conversa → selecione a tag. As tags são criadas em <strong>Configurações → Etiquetas</strong>.</p>

          <h2>Resumo por IA</h2>
          <p>Clique em <strong>"Resumo IA"</strong> no menu da conversa para gerar automaticamente um resumo do histórico da conversa usando inteligência artificial. Útil para quando um agente assume uma conversa de outro.</p>

          <h2>Filtros disponíveis</h2>
          <ul>
            <li>Por status (aberta, pendente, resolvida, adiada)</li>
            <li>Por agente atribuído</li>
            <li>Por canal (inbox/WhatsApp)</li>
            <li>Por tag</li>
            <li>Por temperatura do lead</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ MATCHING -->
        <section id="matching">
          <h1>Matching Automático Lead ↔ Imóvel</h1>
          <p class="lead">Quando um novo imóvel é cadastrado, o sistema usa Inteligência Artificial para comparar automaticamente com todos os leads ativos e notifica os compatíveis via WhatsApp.</p>

          <h2>Como funciona</h2>
          <ol>
            <li>Você cadastra um novo imóvel com tipo, bairro, quartos e preço</li>
            <li>O sistema compara o imóvel com a <strong>intenção de busca</strong> de cada lead ativo</li>
            <li>A IA (GPT) decide: "Este imóvel atende a intenção do lead?" (SIM ou NÃO)</li>
            <li>Os leads compatíveis recebem automaticamente uma mensagem no WhatsApp com os detalhes do imóvel</li>
            <li>Uma notificação aparece no painel: <strong>"X leads compatíveis foram notificados"</strong></li>
          </ol>

          <h2>Executar matching manualmente</h2>
          <p>Para imóveis já cadastrados, você pode re-executar o matching a qualquer momento:</p>
          <ol>
            <li>Acesse <strong>Imóveis</strong></li>
            <li>No card do imóvel, clique no botão <span class="badge yellow">⚡ Matching</span> (ícone de raio amarelo)</li>
            <li>Aguarde a notificação com o resultado na tela</li>
          </ol>

          <h2>Configurar a intenção do lead</h2>
          <p>O matching usa o campo <strong>Intenção</strong> do contato. Quanto mais detalhado, melhor o resultado:</p>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Exemplo de intenção bem preenchida</th><th>Resultado</th></tr></thead>
              <tbody>
                <tr><td>"Quer comprar apartamento de 2 quartos no Setor Bueno até R$ 400 mil"</td><td><span class="badge green">Match preciso</span></td></tr>
                <tr><td>"Quer comprar imóvel"</td><td><span class="badge yellow">Match amplo</span></td></tr>
                <tr><td>(vazio)</td><td><span class="badge gray">Não participa</span></td></tr>
              </tbody>
            </table>
          </div>
          <p>Para editar a intenção: abra o contato → clique em <strong>Editar atributos</strong> → campo "Intenção".</p>

          <h2>Mensagem enviada ao lead</h2>
          <p>O lead recebe automaticamente no WhatsApp uma mensagem como:</p>
          <div class="code-block">
            "João! Temos um novo Apartamento em Setor Bueno, 2 quartos por R$ 380.000 que pode ser exatamente o que você procura! Posso te contar mais detalhes?"
          </div>

          <h2>Requisitos</h2>
          <ul>
            <li>A chave da OpenAI deve estar configurada em <strong>Admin → Configurações → OpenAI API Key</strong></li>
            <li>O lead deve ter o campo <strong>Intenção</strong> preenchido</li>
            <li>O lead não deve estar com status <strong>Ganho (won)</strong></li>
            <li>O lead deve ter uma conversa ativa com um inbox de WhatsApp associado</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ TRANSFERÊNCIA -->
        <section id="transferencia">
          <h1>Transferência de Conversa entre Agentes</h1>
          <p class="lead">Transfira uma conversa para outro corretor com uma nota de contexto — a nota aparece como mensagem privada no chat, visível apenas para a equipe.</p>

          <h2>Como transferir</h2>
          <ol>
            <li>Abra a conversa que deseja transferir</li>
            <li>No painel direito, em <strong>Atendente</strong>, você verá o corretor atual</li>
            <li>Clique em <strong>"Transferir com nota"</strong></li>
            <li>No modal, selecione o <strong>agente de destino</strong></li>
            <li>Escreva a <strong>nota de contexto</strong> — explique o motivo da transferência e o que o próximo agente precisa saber</li>
            <li>Clique em <strong>Transferir</strong></li>
          </ol>

          <h2>O que acontece após a transferência</h2>
          <ul>
            <li>A conversa é atribuída ao novo agente</li>
            <li>O novo agente recebe uma <strong>notificação push</strong> e uma mensagem no WhatsApp pessoal</li>
            <li>A nota de transferência aparece no chat como <strong>mensagem privada</strong> (fundo amarelado), visível apenas para a equipe — o lead não vê</li>
            <li>A tag <strong>com_atendente</strong> é mantida indicando que há um corretor responsável</li>
          </ul>

          <h2>Atribuição rápida sem nota</h2>
          <p>Se quiser apenas mudar o atendente sem escrever uma nota, use o <strong>dropdown de Atendente</strong> diretamente — a conversa é reatribuída imediatamente sem abrir o modal.</p>

          <h2>Quem pode transferir</h2>
          <p>Qualquer agente com acesso à conversa pode transferir. Corretores só veem suas próprias conversas, portanto só conseguem transferir conversas que já estão atribuídas a eles.</p>

          <div class="info-card" style="margin-top: 1rem;">
            <ArrowRightLeft :size="20" />
            <div>
              <strong>Dica de uso</strong>
              <p>Use a transferência quando um corretor sai de férias, quando o lead precisa de outro tipo de atendimento (ex: corretor para financeiro), ou quando há troca de plantão.</p>
            </div>
          </div>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONTATOS -->
        <section id="contatos">
          <h1>Contatos / Leads</h1>
          <p class="lead">Todos os leads captados pelo WhatsApp, portais imobiliários ou cadastro manual são armazenados como contatos.</p>

          <h2>Campos do contato</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Campo</th><th>Descrição</th></tr></thead>
              <tbody>
                <tr><td>Nome</td><td>Nome completo do lead</td></tr>
                <tr><td>Telefone / WhatsApp</td><td>Número principal de contato</td></tr>
                <tr><td>E-mail</td><td>E-mail para envios</td></tr>
                <tr><td>CPF/CNPJ</td><td>Necessário para gerar cobranças via Asaas</td></tr>
                <tr><td>Temperatura</td><td>Quente / Morno / Frio — indica nível de interesse</td></tr>
                <tr><td>Intenção</td><td>Comprar / Alugar / Vender</td></tr>
                <tr><td>Origem</td><td>WhatsApp, Portal, Indicação, Site etc.</td></tr>
                <tr><td>Profissão / Renda</td><td>Dados para qualificação financeira</td></tr>
                <tr><td>Data de nascimento</td><td>Para personalização de atendimento</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Temperatura do lead</h2>
          <ul>
            <li><span class="badge red">Quente</span> — demonstrou interesse real, pronto para avançar</li>
            <li><span class="badge yellow">Morno</span> — em consideração, pode avançar com estímulo</li>
            <li><span class="badge gray">Frio</span> — sem interesse imediato</li>
          </ul>

          <h2>Notas</h2>
          <p>Na aba <strong>Notas</strong> do contato, qualquer agente pode registrar observações que ficam visíveis para toda a equipe. As notas têm data, hora e nome de quem registrou.</p>

          <h2>Mesclar contatos</h2>
          <p>Quando o mesmo lead aparece duplicado, use <strong>Contatos → Mesclar</strong>. O sistema mantém o histórico completo do contato principal e descarta o duplicado.</p>

          <h2>Bloquear contato</h2>
          <p>Contatos bloqueados não ativam mais a IA e são marcados com status inativo. Use para leads que solicitaram não ser contactados.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ IMÓVEIS -->
        <section id="imoveis">
          <h1>Imóveis</h1>
          <p class="lead">Cadastre e gerencie todo o portfólio de imóveis da imobiliária com fotos, características técnicas e dados do proprietário.</p>

          <h2>Cadastrando um imóvel</h2>
          <ol>
            <li>Acesse <strong>Imóveis → Novo Imóvel</strong></li>
            <li>Preencha: título, código de referência, tipo (casa, apartamento, terreno etc.), endereço completo</li>
            <li>Informe: preço, área total, área construída, quartos, suítes, banheiros, vagas de garagem</li>
            <li>Adicione fotos (arraste ou clique para upload — múltiplas fotos aceitas)</li>
            <li>Preencha dados do proprietário se necessário</li>
            <li>Clique em <strong>Salvar</strong></li>
          </ol>

          <h2>Tipos de imóvel suportados</h2>
          <p>Casa, Apartamento, Terreno, Sala Comercial, Galpão, Sítio/Chácara, Cobertura e outros.</p>

          <h2>Visibilidade por agente</h2>
          <p>Corretores visualizam apenas os imóveis que cadastraram. Donos e administradores visualizam todos.</p>

          <h2>Vinculação com agendamentos</h2>
          <p>Ao criar um agendamento de visita, você vincula o lead a um imóvel específico. O histórico de visitas por imóvel aparece nos relatórios.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONDOMÍNIOS -->
        <section id="condominios">
          <h1>Condomínios / Lançamentos</h1>
          <p class="lead">Gerencie empreendimentos e lançamentos imobiliários com informações de construtora, amenidades e faixas de preço.</p>

          <h2>O que é um condomínio no CRM</h2>
          <p>Um condomínio representa um <strong>empreendimento</strong> (prédio, loteamento, complexo) — diferente de um imóvel unitário. Permite agrupar múltiplas unidades sob um mesmo projeto.</p>

          <h2>Campos principais</h2>
          <ul>
            <li><strong>Nome do empreendimento</strong></li>
            <li><strong>Construtora / Incorporadora</strong></li>
            <li><strong>Status de construção:</strong> Lançamento, Em obras, Pronto para morar</li>
            <li><strong>Faixa de preço:</strong> valor mínimo e máximo das unidades</li>
            <li><strong>Amenidades:</strong> piscina, academia, playground, segurança 24h etc.</li>
            <li><strong>Fotos:</strong> imagens do projeto e das áreas comuns</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ AGENDAMENTOS -->
        <section id="agendamentos">
          <h1>Agendamentos</h1>
          <p class="lead">Gerencie visitas a imóveis e outros compromissos com leads, vinculando contato, imóvel e corretor responsável.</p>

          <h2>Criando um agendamento</h2>
          <ol>
            <li>Acesse <strong>Agendamentos → Novo Agendamento</strong> ou clique no botão de calendário na conversa</li>
            <li>Selecione o <strong>contato</strong> (lead)</li>
            <li>Selecione o <strong>imóvel</strong> que será visitado</li>
            <li>Defina <strong>data e horário</strong></li>
            <li>Selecione o <strong>corretor responsável</strong></li>
            <li>Clique em <strong>Salvar</strong></li>
          </ol>

          <h2>Status dos agendamentos</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Status</th><th>Significado</th></tr></thead>
              <tbody>
                <tr><td><span class="badge blue">Agendado</span></td><td>Visita marcada, aguardando realização</td></tr>
                <tr><td><span class="badge green">Realizado</span></td><td>Visita aconteceu</td></tr>
                <tr><td><span class="badge red">Cancelado</span></td><td>Visita cancelada</td></tr>
                <tr><td><span class="badge yellow">Reagendado</span></td><td>Nova data definida</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Exportar relatório</h2>
          <p>Em <strong>Agendamentos → Relatório</strong>, filtre por período, corretor ou imóvel e exporte em CSV para análise externa.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ FUNIL -->
        <section id="funil">
          <h1>Funil de Vendas (Kanban)</h1>
          <p class="lead">Visualize e gerencie o pipeline de vendas em formato Kanban, movendo leads entre etapas com arrastar e soltar.</p>

          <h2>Etapas do funil</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Coluna</th><th>Significado</th></tr></thead>
              <tbody>
                <tr><td>Novos Leads</td><td>Lead acabou de entrar, ainda não qualificado</td></tr>
                <tr><td>Visita Agendada</td><td>Visita marcada, lead demonstrou interesse</td></tr>
                <tr><td>Proposta Feita</td><td>Proposta ou oferta enviada ao lead</td></tr>
                <tr><td>Negócio Fechado</td><td>Venda ou locação concluída</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Como usar</h2>
          <ul>
            <li><strong>Mover lead:</strong> Arraste o card de uma coluna para outra</li>
            <li><strong>Criar lead direto:</strong> Clique em "+" em qualquer coluna para adicionar um lead manualmente</li>
            <li><strong>Ver detalhes:</strong> Clique no card para abrir o perfil completo do contato</li>
          </ul>

          <h2>Informações nos cards</h2>
          <p>Cada card mostra: nome do lead, temperatura (cor), telefone e intenção (comprar/alugar).</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ RELATÓRIOS -->
        <section id="relatorios">
          <h1>Relatórios</h1>
          <p class="lead">Acompanhe a performance da equipe e do negócio com relatórios detalhados e exportáveis.</p>

          <h2>Abas disponíveis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Aba</th><th>O que mostra</th></tr></thead>
              <tbody>
                <tr><td>Visão Geral</td><td>Total de leads, temperatura, origem, intenção, funil de conversão</td></tr>
                <tr><td>Por Corretor</td><td>Performance individual: leads, conversas, agendamentos, taxa de conversão</td></tr>
                <tr><td>Por Tag</td><td>Contagem de contatos por etiqueta</td></tr>
                <tr><td>Performance</td><td>Tendência dos últimos 7 dias, tempo médio de resposta, imóveis mais vistos</td></tr>
                <tr><td>Agendamentos</td><td>Relatório de visitas por período, corretor ou imóvel</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Filtro de período</h2>
          <p>Todos os relatórios aceitam filtro por: <strong>Hoje, Esta semana, Este mês, Período personalizado</strong>.</p>

          <h2>Exportar CSV</h2>
          <p>Clique em <strong>Exportar</strong> em qualquer relatório para baixar os dados em formato CSV compatível com Excel ou Google Sheets.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ AGENTES -->
        <section id="agentes">
          <h1>Agentes</h1>
          <p class="lead">Gerencie os usuários que utilizam o CRM — corretores, suporte, financeiro e manutenção.</p>

          <h2>Departamentos disponíveis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Departamento</th><th>Função</th><th>Recebe leads via rodízio</th></tr></thead>
              <tbody>
                <tr><td>Corretor</td><td>Atendimento e vendas</td><td>Sim</td></tr>
                <tr><td>Suporte</td><td>Atendimento pós-venda</td><td>Não</td></tr>
                <tr><td>Financeiro</td><td>Cobranças e pagamentos</td><td>Não</td></tr>
                <tr><td>Manutenção</td><td>Solicitações técnicas</td><td>Não</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Criando um agente</h2>
          <ol>
            <li>Acesse <strong>Agentes → Novo Agente</strong></li>
            <li>Preencha nome, e-mail, departamento e senha temporária</li>
            <li>O agente receberá um e-mail com os dados de acesso automaticamente</li>
          </ol>

          <h2>Rodízio automático (Round Robin)</h2>
          <p>O rodízio distribui leads automaticamente entre corretores de forma equilibrada. Para cada corretor:</p>
          <ul>
            <li><strong>Ativar no rodízio:</strong> toggle verde na lista de agentes — o corretor entra na fila</li>
            <li><strong>Desativar:</strong> toggle cinza — o corretor não recebe novos leads automáticos</li>
          </ul>
          <p>A fila de posição está visível em <strong>Agentes → Fila de Rodízio</strong>.</p>

          <h2>Bloquear agente</h2>
          <p>Agentes bloqueados não conseguem mais fazer login. Use quando um funcionário sai da empresa.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONFIGURAÇÕES -->
        <section id="configuracoes">
          <h1>Configurações</h1>
          <p class="lead">Área exclusiva do dono/administrador para configurar canais, integrações e personalizações do CRM.</p>

          <h2>Caixas de Entrada (Inboxes)</h2>
          <p>Cada inbox representa um número de WhatsApp conectado. Para conectar:</p>
          <ol>
            <li>Acesse <strong>Configurações → Caixas de Entrada → Nova Caixa</strong></li>
            <li>Escanear o QR Code com o WhatsApp do número que deseja conectar</li>
            <li>Configure o <strong>prompt de IA</strong> para esse canal (tom de voz, apresentação, regras)</li>
            <li>Defina <strong>horário de funcionamento</strong> e mensagem fora do horário</li>
          </ol>

          <h2>Etiquetas (Tags)</h2>
          <p>Crie e personalize as etiquetas usadas nas conversas em <strong>Configurações → Etiquetas</strong>. Cada tag tem nome e cor.</p>

          <h2>Portais Imobiliários</h2>
          <p>Integre com portais para receber leads automaticamente:</p>
          <ul>
            <li><strong>Canal Pro / Zap Imóveis / Viva Real</strong> — configure em <strong>Configurações → Portais Imobiliários</strong></li>
            <li>Copie a URL do webhook gerada e cadastre no painel do portal</li>
            <li>Leads chegam automaticamente como novos contatos no CRM</li>
          </ul>

          <h2>Conta</h2>
          <p>Em <strong>Configurações → Conta</strong>, altere o nome da empresa e a senha de acesso.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ COBRANÇA -->
        <section id="cobranca">
          <h1>Cobrança via Asaas (PIX e Boleto)</h1>
          <p class="lead">Gere cobranças diretamente pelo painel de conversas e envie automaticamente para o cliente pelo WhatsApp.</p>

          <h2>Configuração inicial (apenas dono)</h2>
          <ol>
            <li>Acesse <strong>Configurações → Cobrança (Asaas)</strong></li>
            <li>Cole a sua <strong>API Key do Asaas</strong> (encontrada em: Asaas → Configurações → Integrações → API)</li>
            <li>Selecione o ambiente: <strong>Sandbox</strong> para testes ou <strong>Produção</strong> para uso real</li>
            <li>Clique em <strong>Salvar</strong> e depois <strong>Testar conexão</strong> para confirmar</li>
          </ol>

          <h2>Gerando uma cobrança</h2>
          <ol>
            <li>Abra uma conversa com o cliente</li>
            <li>Clique no botão verde <strong>Cobrança</strong> no painel de ações</li>
            <li>Se o cliente não tiver CPF cadastrado, o sistema solicitará antes de continuar</li>
            <li>Escolha o tipo: <strong>PIX</strong> ou <strong>Boleto</strong></li>
            <li>Informe: valor, data de vencimento e descrição (opcional)</li>
            <li>Clique em <strong>Gerar</strong></li>
          </ol>

          <h2>Como é enviado</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Tipo</th><th>O que é enviado no WhatsApp</th></tr></thead>
              <tbody>
                <tr><td>PIX</td><td>Imagem do QR Code + código Copia e Cola como texto</td></tr>
                <tr><td>Boleto</td><td>Arquivo PDF do boleto como documento</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Quem pode gerar cobranças</h2>
          <p>Financeiro, Suporte, Manutenção, Dono e Admin. <strong>Corretores não têm acesso</strong> à função de cobrança.</p>

          <h2>Sandbox (ambiente de testes)</h2>
          <p>Use a chave de Sandbox para testar o fluxo sem movimentação financeira real. Obtenha a chave em <a href="https://sandbox.asaas.com" target="_blank">sandbox.asaas.com</a> (conta gratuita).</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ IA -->
        <section id="ia">
          <h1>Inteligência Artificial</h1>
          <p class="lead">O CRM usa IA (OpenAI GPT) para responder leads automaticamente, resumir conversas e gerar prompts personalizados.</p>

          <h2>Resposta automática</h2>
          <p>Quando a IA está ativa em um canal, ela responde automaticamente as mensagens recebidas fora do horário de atendimento ou enquanto nenhum agente está disponível. O comportamento é definido pelo <strong>Prompt de IA</strong> configurado no canal.</p>

          <h2>Pausa da IA</h2>
          <p>Para pausar a IA em uma conversa específica, use a opção <strong>Pausar IA</strong> no menu da conversa. A conversa passa a ser atendida manualmente. Para reativar, use <strong>Retomar IA</strong>.</p>

          <h2>Resumo automático de conversa</h2>
          <p>Em qualquer conversa, clique em <strong>Resumo IA</strong> para gerar automaticamente um resumo do histórico. Ideal para quando um agente assume uma conversa de outro sem precisar ler tudo.</p>

          <h2>Gerador de Prompt</h2>
          <p>Em <strong>Configurações → Caixas de Entrada → editar inbox</strong>, use o botão <strong>Gerar Prompt com IA</strong>. O sistema cria automaticamente um prompt profissional baseado nas informações que você fornecer sobre a empresa.</p>

          <h2>Boas práticas para o Prompt</h2>
          <ul>
            <li>Defina o nome da IA (ex: "Assistente Virtual da Imobiliária XYZ")</li>
            <li>Liste o que a IA pode e não pode responder</li>
            <li>Inclua o horário de atendimento humano</li>
            <li>Defina o tom: formal, amigável, direto</li>
            <li>Instrua a IA a sempre coletar nome e telefone de novos leads</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ NOTIFICAÇÕES -->
        <section id="notificacoes">
          <h1>Notificações Push</h1>
          <p class="lead">Receba alertas no celular mesmo quando o CRM não está aberto — igual a um app nativo.</p>

          <h2>Como ativar</h2>
          <ol>
            <li>Acesse o CRM pelo celular no navegador (<strong>Chrome no Android</strong> ou <strong>Safari no iOS</strong>)</li>
            <li>Instale o app: no Android, o Chrome exibe o banner automaticamente. No iOS, toque em Compartilhar → Adicionar à Tela de Início</li>
            <li>Ao fazer login, o sistema solicita permissão para notificações</li>
            <li>Toque em <strong>Permitir</strong></li>
          </ol>

          <h2>O que gera notificações</h2>
          <ul>
            <li>Novo lead atribuído ao corretor (via rodízio automático ou atribuição manual)</li>
          </ul>

          <h2>Compatibilidade</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Dispositivo</th><th>Suporte</th><th>Observação</th></tr></thead>
              <tbody>
                <tr><td>Android (Chrome)</td><td><span class="badge green">Completo</span></td><td>Funciona sem instalar</td></tr>
                <tr><td>iOS 16.4+</td><td><span class="badge yellow">Parcial</span></td><td>App deve estar instalado na tela inicial</td></tr>
                <tr><td>iOS abaixo de 16.4</td><td><span class="badge gray">Não suportado</span></td><td>Limitação da Apple</td></tr>
              </tbody>
            </table>
          </div>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ PERMISSÕES -->
        <section id="permissoes">
          <h1>Permissões por Papel</h1>
          <p class="lead">O CRM tem dois papéis principais e quatro departamentos, cada um com níveis de acesso distintos.</p>

          <h2>Papéis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Papel</th><th>Descrição</th></tr></thead>
              <tbody>
                <tr><td><strong>Empresa / Dono</strong></td><td>Acesso total ao CRM, configurações, agentes e relatórios</td></tr>
                <tr><td><strong>Atendente</strong></td><td>Acesso às suas próprias conversas, leads e imóveis</td></tr>
                <tr><td><strong>Admin (global)</strong></td><td>Painel administrativo do SaaS — exclusivo da equipe técnica</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Tabela de permissões por departamento</h2>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Função</th>
                  <th>Corretor</th>
                  <th>Suporte</th>
                  <th>Financeiro</th>
                  <th>Manutenção</th>
                </tr>
              </thead>
              <tbody>
                <tr><td>Ver suas conversas</td><td>✅</td><td>✅</td><td>✅</td><td>✅</td></tr>
                <tr><td>Ver todas as conversas</td><td>❌</td><td>❌</td><td>❌</td><td>❌</td></tr>
                <tr><td>Receber leads (rodízio)</td><td>✅</td><td>❌</td><td>❌</td><td>❌</td></tr>
                <tr><td>Gerar cobrança PIX/Boleto</td><td>❌</td><td>✅</td><td>✅</td><td>✅</td></tr>
                <tr><td>Gerenciar agentes</td><td>❌</td><td>❌</td><td>❌</td><td>❌</td></tr>
                <tr><td>Acessar configurações</td><td>❌</td><td>❌</td><td>❌</td><td>❌</td></tr>
                <tr><td>Ver relatórios</td><td>✅*</td><td>✅*</td><td>✅*</td><td>✅*</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">* Relatórios mostram apenas dados do próprio atendente. Donos veem dados de toda a equipe.</p>

          <h2>Permissões exclusivas do Dono/Admin</h2>
          <ul>
            <li>Criar, editar e bloquear agentes</li>
            <li>Configurar canais WhatsApp (inboxes)</li>
            <li>Configurar a chave de API do Asaas</li>
            <li>Integrar portais imobiliários</li>
            <li>Gerenciar etiquetas</li>
            <li>Ver relatórios de toda a equipe</li>
            <li>Visualizar todos os leads e conversas</li>
          </ul>
        </section>

        <div class="divider" />

        <div class="footer-note">
          <p>Dúvidas ou problemas? Acesse <strong>Suporte</strong> no menu lateral para abrir um chamado com a equipe técnica.</p>
        </div>

      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.manual-page {
  display: flex;
  height: 100%;
  overflow: hidden;
  background: var(--bg-primary);
}

// ── Sidebar nav ─────────────────────────────────────────────
.manual-nav {
  width: 220px;
  flex-shrink: 0;
  border-right: 1px solid var(--border-color);
  background: var(--bg-secondary);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.nav-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1rem 0.75rem;
  font-size: 0.78rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
  border-bottom: 1px solid var(--border-color);
}

.nav-search {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6rem 0.75rem;
  border-bottom: 1px solid var(--border-color);
  color: var(--text-muted);

  input {
    flex: 1;
    background: none;
    border: none;
    outline: none;
    font-size: 0.8rem;
    color: var(--text-main);
    &::placeholder { color: var(--text-muted); }
  }
}

nav {
  flex: 1;
  overflow-y: auto;
  padding: 0.4rem 0;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.55rem 1rem;
  font-size: 0.82rem;
  color: var(--text-muted);
  background: none;
  border: none;
  text-align: left;
  cursor: pointer;
  transition: background 0.12s, color 0.12s;

  .arrow { margin-left: auto; opacity: 0; transition: opacity 0.12s; }

  &:hover {
    background: var(--bg-hover);
    color: var(--text-main);
    .arrow { opacity: 0.5; }
  }

  &.active {
    background: rgba(67,56,202,0.08);
    color: #4338ca;
    font-weight: 600;
    .arrow { opacity: 1; color: #4338ca; }
  }
}

// ── Content ─────────────────────────────────────────────────
.manual-content {
  flex: 1;
  overflow-y: auto;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  scroll-behavior: smooth;
}

.content-inner {
  max-width: 820px;
  padding: 2rem 2.5rem 4rem;
}

section {
  scroll-margin-top: 1.5rem;
  margin-bottom: 0.5rem;
}

h1 {
  font-size: 1.35rem;
  font-weight: 800;
  color: var(--text-main);
  margin: 0 0 0.4rem;
  padding-bottom: 0.5rem;
  border-bottom: 2px solid #4338ca;
  display: inline-block;
}

.lead {
  font-size: 0.92rem;
  color: var(--text-muted);
  margin: 0.6rem 0 1.25rem;
  line-height: 1.65;
}

h2 {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--text-main);
  margin: 1.4rem 0 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
}

p { font-size: 0.88rem; color: var(--text-muted); line-height: 1.7; margin: 0.4rem 0; }

ul, ol {
  padding-left: 1.3rem;
  font-size: 0.88rem;
  color: var(--text-muted);
  line-height: 1.8;
  margin: 0.4rem 0 0.8rem;

  strong { color: var(--text-main); }
}

a { color: #4338ca; }

// Cards row
.cards-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.75rem;
  margin: 1rem 0 1.5rem;
}

.info-card {
  display: flex;
  gap: 0.75rem;
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.9rem 1rem;

  svg { color: #4338ca; flex-shrink: 0; margin-top: 2px; }

  strong { display: block; font-size: 0.83rem; color: var(--text-main); margin-bottom: 0.2rem; }
  p { font-size: 0.78rem; color: var(--text-muted); margin: 0; line-height: 1.5; }
}

// Tables
.table-wrap {
  overflow-x: auto;
  margin: 0.6rem 0 1rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.83rem;

  th {
    background: var(--bg-secondary);
    color: var(--text-muted);
    font-weight: 700;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    padding: 0.6rem 1rem;
    text-align: left;
    border-bottom: 1px solid var(--border-color);
  }

  td {
    padding: 0.65rem 1rem;
    color: var(--text-muted);
    border-bottom: 1px solid var(--border-color);
    vertical-align: middle;
    strong { color: var(--text-main); }
  }

  tr:last-child td { border-bottom: none; }
}

// Badges
.badge {
  display: inline-flex;
  align-items: center;
  padding: 0.18rem 0.6rem;
  border-radius: 4px;
  font-size: 0.75rem;
  font-weight: 600;

  &.green  { background: rgba(16,185,129,0.1);   color: #059669; }
  &.yellow { background: rgba(245,158,11,0.1);   color: #d97706; }
  &.gray   { background: rgba(107,114,128,0.1);  color: #6b7280; }
  &.blue   { background: rgba(59,130,246,0.1);   color: #2563eb; }
  &.red    { background: rgba(239,68,68,0.1);    color: #dc2626; }
}

.code-block {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-left: 3px solid #4338ca;
  border-radius: 6px;
  padding: 0.8rem 1rem;
  font-size: 0.83rem;
  color: var(--text-main);
  font-style: italic;
  margin: 0.5rem 0 0.8rem;
  line-height: 1.6;
}

.note {
  font-size: 0.78rem;
  color: var(--text-muted);
  opacity: 0.75;
  font-style: italic;
  margin-top: 0.3rem;
}

.divider {
  height: 1px;
  background: var(--border-color);
  margin: 2.5rem 0;
}

.footer-note {
  background: rgba(67,56,202,0.05);
  border: 1px solid rgba(67,56,202,0.15);
  border-radius: 8px;
  padding: 1rem 1.25rem;
  font-size: 0.85rem;
  color: var(--text-muted);
  p { margin: 0; }
  strong { color: var(--text-main); }
}

@media (max-width: 768px) {
  .manual-page {
    flex-direction: column;
    overflow: hidden;
  }

  .manual-nav {
    width: 100%;
    max-height: 200px;
    border-right: none;
    border-bottom: 1px solid var(--border-color);
  }

  .content-inner {
    padding: 1.25rem 1rem 3rem;
  }
}
</style>
