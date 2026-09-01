<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import {
  MessageCircle, Users, UserCheck, UserX, ListChecks, LayoutGrid, Kanban,
  TrendingUp, Badge, Settings, BrainCircuit, Bell,
  BookOpen, ChevronRight, Search, Bot, Zap, Shield, ArrowRightLeft, GitBranch,
  Tag, Package, Users2, Timer, Smartphone
} from 'lucide-vue-next'

const activeSection = ref('visao-geral')
const searchQuery   = ref('')

const sections = [
  { id: 'visao-geral',    label: 'Visão Geral',             icon: BookOpen },
  { id: 'regua',          label: 'Régua Consignado',        icon: Timer },
  { id: 'conversas',      label: 'Conversas',               icon: MessageCircle },
  { id: 'transferencia',  label: 'Transferência de Conversa', icon: ArrowRightLeft },
  { id: 'contatos',       label: 'Contatos / Revendedoras',  icon: Users },
  { id: 'carteira',       label: 'Carteira Ativa',          icon: UserCheck },
  { id: 'inativas',       label: 'Revendedoras Inativas',   icon: UserX },
  { id: 'atacado',        label: 'Atacado',                 icon: Package },
  { id: 'etiquetas',      label: 'Etiquetas',               icon: Tag },
  { id: 'tarefas',        label: 'Tarefas',                 icon: ListChecks },
  { id: 'funil',          label: 'Pipelines (Kanban)',      icon: Kanban },
  { id: 'gatilhos',       label: 'Gatilhos de Pipeline',    icon: Zap },
  { id: 'times-vendas',   label: 'Times de Vendas',         icon: Users2 },
  { id: 'gerencial',      label: 'Visão Gerencial',         icon: LayoutGrid },
  { id: 'relatorios',     label: 'Relatórios',              icon: TrendingUp },
  { id: 'agentes',        label: 'Agentes',                 icon: Badge },
  { id: 'whatsapp',       label: 'Conectar WhatsApp',       icon: Smartphone },
  { id: 'configuracoes',  label: 'Configurações',           icon: Settings },
  { id: 'ia',             label: 'Inteligência Artificial', icon: BrainCircuit },
  { id: 'notificacoes',   label: 'Notificações Push',       icon: Bell },
  { id: 'permissoes',     label: 'Permissões',              icon: Shield },
  { id: 'fluxos',         label: 'Fluxos',                  icon: GitBranch },
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
          <p class="lead">O <strong>CRM Clara Ferreira</strong> é a plataforma de relacionamento com as revendedoras consignadas. Ele centraliza conversas do WhatsApp, o ciclo da régua (3º/10º/20º dia) e cobranças em um único lugar, sincronizado com o cadastro de revendedoras do ERP Jueri.</p>

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
                <p>Rodízio automático de leads entre consultoras, mensagens agendadas e notificações em tempo real.</p>
              </div>
            </div>
          </div>

          <h2>Estrutura do sistema (menu lateral)</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Módulo</th><th>Quem acessa</th><th>Função principal</th></tr></thead>
              <tbody>
                <tr><td>Início</td><td>Todos</td><td>Painel do dia: tarefas do dia, atendimento, acertos da semana</td></tr>
                <tr><td>Minhas Revendedoras</td><td>Todos, exceto Financeiro</td><td>Carteira ativa (dentro do ciclo da régua)</td></tr>
                <tr><td>Inativas</td><td>Todos</td><td>Fora do ciclo ativo — inclui as 7 sub-etapas de inadimplência/cadastro</td></tr>
                <tr><td>Atacado</td><td>Todos</td><td>Clientes de compra à vista do Jueri, fora do modelo consignado</td></tr>
                <tr><td>Tarefas</td><td>Todos, exceto Financeiro</td><td>Fila de ações pendentes geradas pela régua + tarefas manuais</td></tr>
                <tr><td>Gerencial / Relatórios</td><td>Gerente e Diretoria</td><td>Visão consolidada de todas as carteiras e métricas</td></tr>
                <tr><td>Times de Vendas</td><td>Gerente e Diretoria</td><td>Quem enxerga a carteira de cada time sincronizado do Jueri</td></tr>
                <tr><td>Comunicações</td><td>Todos</td><td>Inbox de chat (WhatsApp/Instagram) + Chat da Equipe</td></tr>
                <tr><td>Pipelines</td><td>Todos (criar pipeline novo é só Gerente/Diretoria)</td><td>Consignado (fixo, segue a régua) + pipelines próprios (Varejo etc.)</td></tr>
                <tr><td>Calendário</td><td>Todos</td><td>Agendamentos de acerto e mensagens programadas</td></tr>
                <tr><td>Fluxos</td><td>Diretoria</td><td>Robô de conversa no WhatsApp (automação por etapa de pipeline é o botão "Automatize" dentro de cada Pipeline, ver seção Gatilhos)</td></tr>
                <tr><td>Configurações</td><td>Diretoria</td><td>Conta, Caixas de Entrada (WhatsApp), Etiquetas, Agentes, Atividades</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">Não existe cobrança de PIX/boleto integrada ao CRM — cobrança e inadimplência são acompanhadas pela tela Inativas (sub-etapas "Inativa com Pendência", "Suspensa por Atraso" etc.), o pagamento em si é resolvido fora do sistema.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ RÉGUA -->
        <section id="regua">
          <h1>Régua Consignado — como o status de cada revendedora é decidido</h1>
          <p class="lead">Essa é a lógica principal do CRM: cada revendedora tem um único campo de <strong>status</strong>, e ele muda sozinho conforme o tempo passa e os pedidos que ela abre no Jueri. Nenhum consultor precisa mover isso manualmente no dia a dia — só em casos excepcionais.</p>

          <h2>1. Como uma revendedora vira Ativa</h2>
          <p>Toda madrugada (e a cada sincronização), o CRM soma as peças em aberto de cada revendedora no Jueri. Quando o total passa de <strong>25 peças</strong>, ela vira <span class="badge green">Revendedor Ativo</span> automaticamente e o ciclo começa a contar a partir da data do pedido mais antigo em aberto.</p>

          <h2>2. Avanço automático do ciclo</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Dia do ciclo</th><th>Status</th><th>O que a régua espera da equipe</th></tr></thead>
              <tbody>
                <tr><td>Dia 0</td><td><span class="badge green">Revendedor Ativo</span></td><td>Maleta acabou de sair</td></tr>
                <tr><td>Dia 3</td><td><span class="badge yellow">3° Dia</span></td><td>Mensagem de incentivo, perguntar se viu o catálogo</td></tr>
                <tr><td>Dia 10</td><td><span class="badge yellow">10° Dia</span></td><td>Perguntar como estão as vendas, lembrar do prazo</td></tr>
                <tr><td>Dia 20</td><td><span class="badge blue">20° Dia</span></td><td>Agendar o acerto, incentivar até o fim do prazo</td></tr>
                <tr><td>—</td><td><span class="badge blue">Agendado</span></td><td>Acerto marcado — depois de feito, volta pra Ativo com data de novo pedido</td></tr>
                <tr><td>Dia 35+</td><td><span class="badge red">Atrasada</span></td><td>Gerar alerta, acionar consultor, registrar tentativa de contato</td></tr>
                <tr><td>Virou o mês sem acerto</td><td><span class="badge gray">Suspensa por Atraso</span></td><td>Sai da Carteira Ativa, vai pra Inativas</td></tr>
              </tbody>
            </table>
          </div>
          <p>Cada linha da régua (3º/10º/20º dia e Atrasada) <strong>cria uma tarefa de verdade</strong> automaticamente — é o que alimenta a tela <router-link to="/tarefas">Tarefas</router-link>.</p>

          <h2>3. Pedido novo reinicia o ciclo sozinho</h2>
          <p>Se uma revendedora que já está em ciclo ativo (Ativo até Atrasada) abre um <strong>pedido novo</strong> no Jueri com data mais recente que o início do ciclo atual, o CRM detecta e reinicia a contagem pro 1º dia automaticamente — sem precisar de ninguém mexendo manualmente. Isso fica registrado no histórico da revendedora como "ciclo reiniciado".</p>

          <h2>4. Status Inativos (fora do ciclo)</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Status</th><th>Quando acontece</th></tr></thead>
              <tbody>
                <tr><td>Sem Maleta</td><td>Nunca teve pedido em aberto suficiente pra ativar (menos de 25 peças)</td></tr>
                <tr><td>Inativa com Pendência</td><td>Tem pendência financeira em aberto no Jueri</td></tr>
                <tr><td>Suspensa por Atraso</td><td>Ficou atrasada e o mês virou sem acerto — a mais comum</td></tr>
                <tr><td>Negativado/Jurídico</td><td>Caso encaminhado pro jurídico</td></tr>
                <tr><td>Resgate</td><td>Marcada manualmente pra uma segunda chance de reativação</td></tr>
                <tr><td>Reativação</td><td>Em processo de voltar a ficar ativa</td></tr>
                <tr><td>Descadastrada</td><td>Não faz mais parte do time de revendedoras</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">Importante: <strong>Resgate nunca reativa sozinho</strong> mesmo que a revendedora abra pedido novo — é o único status que exige mudança manual, de propósito, pra não pular a etapa de negociação com quem já teve problema sério.</p>

          <h2>5. O que o CRM nunca faz</h2>
          <p>O CRM <strong>não altera nenhum dado de cadastro do Jueri</strong> (CPF, nome, telefone, endereço, gerente etc.) — só lê. Os únicos campos que o CRM controla por conta própria são o status da régua e os campos de acompanhamento comercial (Venda, Meta, Observações, Etiquetas). Se precisar corrigir um dado de cadastro, sempre no Jueri — o link "Abrir cadastro no Jueri" no perfil da revendedora leva direto pra lá.</p>
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
            <li>Novas conversas entram automaticamente e são distribuídas via <strong>rodízio automático</strong> entre as consultoras disponíveis</li>
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

        <!-- ══════════════════════════════════════ TRANSFERÊNCIA -->
        <section id="transferencia">
          <h1>Transferência de Conversa entre Agentes</h1>
          <p class="lead">Transfira uma conversa para outra consultora com uma nota de contexto — a nota aparece como mensagem privada no chat, visível apenas para a equipe.</p>

          <h2>Como transferir</h2>
          <ol>
            <li>Abra a conversa que deseja transferir</li>
            <li>No painel direito, em <strong>Atendente</strong>, você verá a consultora atual</li>
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
            <li>A tag <strong>com_atendente</strong> é mantida indicando que há uma consultora responsável</li>
          </ul>

          <h2>Atribuição rápida sem nota</h2>
          <p>Se quiser apenas mudar o atendente sem escrever uma nota, use o <strong>dropdown de Atendente</strong> diretamente — a conversa é reatribuída imediatamente sem abrir o modal.</p>

          <h2>Quem pode transferir</h2>
          <p>Qualquer agente com acesso à conversa pode transferir. Consultoras só veem suas próprias conversas, portanto só conseguem transferir conversas que já estão atribuídas a elas.</p>

          <div class="info-card" style="margin-top: 1rem;">
            <ArrowRightLeft :size="20" />
            <div>
              <strong>Dica de uso</strong>
              <p>Use a transferência quando uma consultora sai de férias, quando o lead precisa de outro tipo de atendimento (ex: consultora para financeiro), ou quando há troca de plantão.</p>
            </div>
          </div>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONTATOS -->
        <section id="contatos">
          <h1>Contatos / Revendedoras</h1>
          <p class="lead">Toda revendedora sincronizada do ERP Jueri, ou captada pelo WhatsApp, é armazenada como contato — a entidade central do CRM.</p>

          <h2>Duas categorias de campo — não confundir</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Categoria</th><th>Exemplos</th><th>Quem edita</th></tr></thead>
              <tbody>
                <tr><td><strong>Dados do Jueri (sincronizado)</strong></td><td>Nome, CPF, RG, endereço, telefone, gerente/carteira, status cadastral</td><td>Ninguém no CRM — só lido, edição é sempre no Jueri</td></tr>
                <tr><td><strong>Campos personalizados do CRM</strong></td><td>Venda, Meta, Observação do mês, Próximo agendamento, Descrição, atributos livres</td><td>Equipe, pelo botão "Adicionar/editar campos"</td></tr>
              </tbody>
            </table>
          </div>
          <p>A aba <strong>Informações</strong> no perfil da revendedora mostra só a segunda categoria — nunca mistura com dado do Jueri, pra não confundir o que é editável do que não é.</p>

          <h2>Carteira × Atendente — a distinção mais importante</h2>
          <ul>
            <li><strong>Carteira</strong> — o time de vendas (do Jueri) dono permanente daquela revendedora. Não muda por causa de quem respondeu uma mensagem.</li>
            <li><strong>Atendente</strong> — quem está respondendo a conversa <em>agora</em>. É temporário: quando a conversa fecha, o CRM devolve o responsável de volta pra Carteira automaticamente.</li>
          </ul>
          <p class="note">Antes esses dois conceitos ficavam misturados num campo só chamado "Usuário responsável" (herança de um CRM genérico) — foram separados porque geravam confusão sobre quem realmente é dono da revendedora.</p>

          <h2>Notas</h2>
          <p>Na aba <strong>Notas</strong> do contato, qualquer agente pode registrar observações que ficam visíveis para toda a equipe. As notas têm data, hora e nome de quem registrou.</p>

          <h2>Mesclar contatos</h2>
          <p>Quando a mesma revendedora aparece duplicada, use <strong>Mesclar contato</strong> no menu "⋮" da conversa. O sistema mantém o histórico completo do contato principal e descarta o duplicado.</p>

          <h2>Bloquear contato</h2>
          <p>Contatos bloqueados não ativam mais a IA. Use para revendedoras que solicitaram não ser contactadas.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CARTEIRA ATIVA -->
        <section id="carteira">
          <h1>Carteira Ativa</h1>
          <p class="lead">Lista as revendedoras que estão dentro do ciclo ativo da régua (do dia 0 até o acerto), com o status atual de cada uma.</p>

          <h2>Como funciona o ciclo</h2>
          <p>Quando uma revendedora fica com status <strong>Ativa</strong>, o ciclo começa a contar (<code>cycle_started_at</code>). Um job automático (<strong>ReguaAutoAdvanceJob</strong>) avança o status dela sozinho conforme os dias passam: 3º dia → 10º dia → 20º dia → atrasada.</p>

          <h2>Ações disponíveis</h2>
          <ul>
            <li>Ver o histórico de conversa da revendedora</li>
            <li>Mover manualmente para outra etapa da régua</li>
            <li>Aplicar etiquetas (ex: <em>revendedora_engajada</em>, <em>revendedora_dificuldade</em>)</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ INATIVAS -->
        <section id="inativas">
          <h1>Revendedoras Inativas</h1>
          <p class="lead">Lista as revendedoras fora do ciclo ativo — suspensas por atraso ou que ainda não iniciaram um novo ciclo.</p>

          <h2>Quando uma revendedora fica inativa</h2>
          <p>O job de régua move a revendedora para <strong>suspensa_atraso</strong> quando ela permanece atrasada e o mês vira sem acerto. A partir daí ela some da Carteira Ativa e aparece aqui até reiniciar o ciclo.</p>

          <h2>Reativando o ciclo</h2>
          <p>Ao mover o status de volta para <strong>Ativa</strong>, o ciclo reinicia automaticamente e a contagem da régua recomeça do zero. Exceção: <strong>Resgate</strong> nunca reativa sozinho, precisa de mudança manual (ver seção Régua Consignado).</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ ATACADO -->
        <section id="atacado">
          <h1>Atacado</h1>
          <p class="lead">Clientes do Jueri que compram à vista, fora do modelo de revenda consignada — não passam pela régua de 3º/10º/20º dia. Ficam numa lista própria pra não misturar com a carteira de revendedoras.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ ETIQUETAS -->
        <section id="etiquetas">
          <h1>Etiquetas</h1>
          <p class="lead">Etiquetas existem pra <strong>facilitar filtragem</strong> — de conversas e de revendedoras. Todas as etiquetas da conta ficam num catálogo único (uma tabela de verdade), então a mesma etiqueta é sempre a mesma, em qualquer lugar do sistema.</p>

          <h2>Como criar/usar uma etiqueta</h2>
          <ol>
            <li>Clique no campo de etiqueta (na conversa ou no perfil da revendedora)</li>
            <li>Abre um dropdown com <strong>todas as etiquetas já usadas</strong> em qualquer lead da conta — clique numa pra aplicar na hora</li>
            <li>Se a etiqueta que você precisa ainda não existe, digite o nome novo e confirme — ela entra pro catálogo e já fica disponível pra reaproveitar em outros leads</li>
          </ol>
          <p class="note">Reaproveitar a etiqueta já existente (em vez de criar "vip" e depois "VIP importante" como coisas separadas) é o que faz a filtragem funcionar de verdade — etiqueta espalhada e duplicada quebra qualquer relatório por etiqueta.</p>

          <h2>Onde etiquetas aparecem</h2>
          <ul>
            <li><strong>Na conversa</strong> — etiqueta a conversa em si (ex: <code>agente_off</code>, marcada automaticamente quando um humano assume o atendimento)</li>
            <li><strong>Na revendedora</strong> — etiqueta o cadastro dela, independente de qual conversa está aberta</li>
          </ul>

          <h2>Gerenciar o catálogo</h2>
          <p>Em <strong>Configurações → Etiquetas</strong>, a Diretoria vê a lista completa de etiquetas da conta, edita cor/nome e apaga as que não fazem mais sentido.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ TAREFAS -->
        <section id="tarefas">
          <h1>Tarefas</h1>
          <p class="lead">Lista de ações que a equipe precisa tomar, geradas automaticamente pela régua (3º, 10º, 20º dia e Atrasada) e também criadas manualmente. Diferente de antes, toda tarefa é um registro de verdade — fica salva mesmo depois de concluída, pra auditoria.</p>

          <h2>Como uma tarefa nasce</h2>
          <p>Quando a régua avança o status de uma revendedora (3º/10º/20º dia ou Atrasada), o sistema cria a tarefa correspondente sozinho, com um checklist fixo de passos esperados naquela etapa. Ninguém precisa criar essas manualmente. Tarefas manuais (Ligar, Enviar mensagem, Agendar acerto, Cobrança, Acompanhamento, Outro) são criadas por Gerente/Diretoria pra qualquer revendedora, a qualquer momento.</p>

          <h2>Abas Pendentes / Concluídas</h2>
          <p>Tarefa concluída não desaparece — vai pra aba <strong>Concluídas</strong>, com data de conclusão e o resultado registrado (ver abaixo). A aba <strong>Pendentes</strong> agrupa automaticamente em Atrasadas / Hoje / Amanhã / Mais adiante, conforme o vencimento.</p>

          <h2>Concluindo uma tarefa</h2>
          <p>Clicar em <strong>Concluir</strong> abre um modal (não é um clique só):</p>
          <ul>
            <li><strong>Resultado</strong> — texto livre com o que aconteceu (ex: "Liguei, ela vai fechar até sexta"). Fica gravado e visível depois na aba Concluídas, pra gerência acompanhar.</li>
            <li><strong>Criar próxima tarefa</strong> (opcional) — marque a caixa, escolha o tipo (Ligar/Mensagem/Agendar acerto/Cobrança/Acompanhamento/Outro) e a data — a tarefa seguinte já nasce criada no mesmo clique.</li>
          </ul>

          <h2>Ordenar e filtrar</h2>
          <ul>
            <li><strong>Ordenar por data</strong> (crescente/decrescente) — botão ao lado dos filtros</li>
            <li><strong>Filtro de período</strong> (de/até) — nas pendentes filtra por vencimento, nas concluídas filtra por data de conclusão</li>
            <li>Filtros por responsável, prioridade e carteira (time do Jueri)</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ GERENCIAL -->
        <section id="gerencial">
          <h1>Visão Gerencial</h1>
          <p class="lead">Painel exclusivo do dono/admin com uma visão consolidada de todas as consultoras e o estágio da régua de cada carteira.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ FUNIL -->
        <section id="funil">
          <h1>Pipelines (Kanban)</h1>
          <p class="lead">Visualização em quadro das revendedoras, arrastando cards entre colunas. Existe o pipeline fixo <strong>Consignado</strong> (segue a régua automática) e pipelines próprios que a Diretoria/Gerência pode criar (ex: Varejo, Onboarding, Atacado, Prospecção).</p>

          <h2>Consignado (fixo)</h2>
          <p>Colunas: <strong>Revendedor Ativo → 3º Dia → 10º Dia → 20º Dia → Agendado</strong>, as mesmas etapas da régua. Mover um card de coluna muda o status oficial da revendedora — o mesmo status que aparece em Carteira Ativa/Tarefas.</p>

          <h2>Pipelines próprios</h2>
          <p>Em <strong>Pipelines → ⋮ → Adicionar funil de vendas</strong>, Gerente/Diretoria cria um funil com etapas livres (nome que quiser). Serve pra organizar processos que não são a régua consignada — ex: cadastro de revendedora nova (Onboarding) ou negociação de venda avulsa (Varejo).</p>

          <h2>Regra importante: nunca cria revendedora do zero</h2>
          <p>O botão <strong>"+"</strong> em qualquer coluna, de qualquer pipeline, <strong>busca uma revendedora que já existe</strong> (por nome ou telefone) e adiciona ela naquela etapa — nunca abre um formulário de cadastro novo. Toda revendedora só existe no CRM se veio de importação do Jueri.</p>

          <h2>Como usar</h2>
          <ul>
            <li><strong>Mover revendedora:</strong> arraste o card de uma coluna para outra, ou use o menu "⋮" do card → "Mover para..."</li>
            <li><strong>Adicionar à etapa:</strong> clique em "+" na coluna, busque pelo nome/telefone de quem já existe</li>
            <li><strong>Ver detalhes:</strong> clique no card para abrir o perfil completo</li>
            <li><strong>Ordenar A-Z:</strong> botão de ordenar ao lado do título do quadro</li>
          </ul>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ GATILHOS -->
        <section id="gatilhos">
          <h1>Gatilhos de Pipeline</h1>
          <p class="lead">Automação por etapa: quando um card entra numa coluna, o CRM pode executar uma ação sozinho — com ou sem atraso. Acessível pelo botão <strong>Automatize</strong> dentro de cada pipeline. Diferente dos <button type="button" class="inline-link" @click="scrollTo('fluxos')">Fluxos</button>: gatilho reage a <em>mudança de etapa no funil</em>, fluxo reage a <em>mensagem recebida no WhatsApp</em>.</p>

          <h2>Ações disponíveis</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Ação</th><th>O que faz</th></tr></thead>
              <tbody>
                <tr><td>Mudar etapa do lead</td><td>Move o card pra outra coluna do mesmo pipeline</td></tr>
                <tr><td>Alterar responsável</td><td>Reatribui a revendedora pra outro agente</td></tr>
                <tr><td>Adicionar nota</td><td>Registra uma nota automática no histórico</td></tr>
                <tr><td>Ligar / Pausar agente de IA</td><td>Liga ou pausa a resposta automática pra essa revendedora</td></tr>
                <tr><td>Enviar webhook</td><td>Manda os dados por POST pra uma URL externa</td></tr>
                <tr><td>Iniciar fluxo</td><td>Dispara um dos Fluxos de conversa já criados (ver seção Fluxos)</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Condição de tempo</h2>
          <p>Todo gatilho pode ser <strong>imediato</strong> (assim que o card entra na coluna) ou com <strong>atraso configurável</strong> (ex: "depois de 1h", "depois de 1 dia") — igual ao exemplo do Kommo que motivou o pedido.</p>

          <h2>Como criar</h2>
          <ol>
            <li>Abra o pipeline → <strong>Automatize</strong></li>
            <li>Na coluna desejada, clique em <strong>+ Adicionar gatilho</strong></li>
            <li>Escolha a ação, configure o atraso e salve</li>
          </ol>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ TIMES DE VENDAS -->
        <section id="times-vendas">
          <h1>Times de Vendas</h1>
          <p class="lead">Toda revendedora sincronizada do Jueri já vem vinculada a um time de vendas (o campo "gerente" da API do Jueri, exibido como <strong>Carteira</strong> no CRM). Essa tela controla <em>quem no CRM enxerga a carteira de cada time</em> — não cria nem edita times, eles vêm prontos do Jueri.</p>

          <h2>Os dois botões — o que cada um faz</h2>
          <ul>
            <li><strong>Gerenciar acesso</strong> — escolhe quais usuários do CRM podem ver e trabalhar a carteira <em>inteira</em> daquele time (ex: um gerente supervisionando várias consultoras de uma vez). Pode ter várias pessoas com acesso ao mesmo time.</li>
            <li><strong>Atribuir carteira</strong> — só aparece quando existem revendedoras daquele time <em>ainda sem responsável individual</em> (chegaram do Jueri sem ninguém atribuído). Define, revendedora por revendedora, quem é a consultora dona dela.</li>
          </ul>
          <p class="note">São coisas diferentes por design: "Gerenciar acesso" é visibilidade ampla (supervisão), "Atribuir carteira" é dono individual (responsabilidade). Uma pessoa pode ter as duas coisas ou só uma.</p>
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
                <tr><td>Visão Geral</td><td>Total de leads, temperatura, origem, funil da régua</td></tr>
                <tr><td>Por Consultora</td><td>Performance individual: leads, conversas, taxa de conversão</td></tr>
                <tr><td>Por Tag</td><td>Contagem de contatos por etiqueta</td></tr>
                <tr><td>Performance</td><td>Tendência dos últimos 7 dias, tempo médio de resposta</td></tr>
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
          <p class="lead">Gerencie os usuários que utilizam o CRM — consultoras, suporte, financeiro e manutenção.</p>

          <h2>Duas configurações diferentes, no mesmo cadastro de agente</h2>
          <p>Ao criar um agente, você escolhe um <strong>Papel de acesso</strong> (o que ele pode ver/fazer no CRM) e um <strong>Departamento</strong> (só controla se ele recebe leads pelo rodízio do WhatsApp) — são independentes.</p>

          <h2>Papel de acesso (permissões — ver seção Permissões pra detalhe completo)</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Papel</th><th>Vê</th></tr></thead>
              <tbody>
                <tr><td>Consultor</td><td>Só a própria carteira</td></tr>
                <tr><td>Gerente</td><td>Carteira inteira, reatribui responsáveis</td></tr>
                <tr><td>Financeiro</td><td>Inadimplência/cobrança + carteira inteira pra cruzar dados</td></tr>
                <tr><td>Diretoria</td><td>Acesso total, inclusive configurações críticas</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Departamento (rodízio de WhatsApp)</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Departamento</th><th>Função</th><th>Recebe leads via rodízio</th></tr></thead>
              <tbody>
                <tr><td>Consultora</td><td>Atendimento e vendas</td><td>Sim</td></tr>
                <tr><td>Suporte</td><td>Atendimento pós-venda</td><td>Não</td></tr>
                <tr><td>Financeiro</td><td>Cobranças e contratos</td><td>Não</td></tr>
                <tr><td>Manutenção</td><td>Solicitações técnicas</td><td>Não</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Criando um agente</h2>
          <ol>
            <li>Acesse <strong>Agentes → Novo Agente</strong></li>
            <li>Preencha nome, e-mail, telefone, senha temporária</li>
            <li>Escolha o <strong>Papel de acesso</strong> e o <strong>Departamento</strong></li>
          </ol>

          <h2>Rodízio automático (Round Robin)</h2>
          <p>O rodízio distribui leads automaticamente entre consultoras (departamento "Consultora") de forma equilibrada. Ativar/desativar um agente no rodízio controla se ele entra na fila de novos leads.</p>

          <h2>Bloquear agente</h2>
          <p>Agentes bloqueados não conseguem mais fazer login. Use quando um funcionário sai da empresa.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ WHATSAPP -->
        <section id="whatsapp">
          <h1>Conectar WhatsApp</h1>
          <p class="lead">Cada número de WhatsApp conectado é uma <strong>Caixa de Entrada</strong> (Inbox). O CRM funciona com dois motores diferentes de conexão — você escolhe qual usar ao criar a caixa.</p>

          <h2>Baileys × WAHA — qual escolher</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Motor</th><th>Quando usar</th></tr></thead>
              <tbody>
                <tr><td><strong>WAHA</strong> <span class="badge green">Recomendado</span></td><td>Opção padrão sugerida na tela de conexão — mais estável no dia a dia</td></tr>
                <tr><td>Baileys</td><td>Alternativa, mesmo conjunto de funções (texto, mídia, áudio, presença digitando)</td></tr>
              </tbody>
            </table>
          </div>
          <p>Também dá pra conectar <strong>Instagram</strong> como canal (mensagens diretas), via login oficial do Instagram — não precisa QR Code.</p>

          <h2>Passo a passo</h2>
          <ol>
            <li><strong>Configurações → Caixas de Entrada → Nova Caixa</strong></li>
            <li>Escolha o provedor de WhatsApp (WAHA vem marcado como recomendado) ou Instagram</li>
            <li>Escaneie o <strong>QR Code</strong> com o celular do número que vai atender pelo CRM (Instagram usa login direto, sem QR)</li>
            <li>Configure o <strong>prompt de IA</strong> desse canal (ver seção Inteligência Artificial)</li>
            <li>Defina horário de funcionamento e mensagem fora do horário, se quiser</li>
          </ol>

          <h2>Se a caixa desconectar</h2>
          <p>Um banner vermelho aparece no topo do CRM avisando qual caixa caiu. Em <strong>Configurações → Caixas de Entrada</strong>, use <strong>Reconectar</strong> (reabre o QR Code sem apagar a caixa nem o histórico de conversas) ou <strong>Desconectar</strong> (desloga a sessão de propósito, sem apagar nada).</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ CONFIGURAÇÕES -->
        <section id="configuracoes">
          <h1>Configurações</h1>
          <p class="lead">Área exclusiva da Diretoria. Reúne tudo que é configuração de infraestrutura do CRM, não operação do dia a dia.</p>

          <div class="table-wrap">
            <table>
              <thead><tr><th>Item</th><th>Onde encontrar o detalhe neste manual</th></tr></thead>
              <tbody>
                <tr><td>Caixas de Entrada</td><td>Seção <strong>Conectar WhatsApp</strong></td></tr>
                <tr><td>Etiquetas</td><td>Seção <strong>Etiquetas</strong></td></tr>
                <tr><td>Agentes</td><td>Seção <strong>Agentes</strong></td></tr>
                <tr><td>Atividades</td><td>Log de auditoria — quem fez o quê no sistema, só leitura</td></tr>
                <tr><td>Conta</td><td>Nome da empresa e senha de acesso</td></tr>
              </tbody>
            </table>
          </div>
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
            <li>Defina o nome da IA (ex: "Assistente Virtual da Clara Ferreira")</li>
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
            <li>Novo lead atribuído à consultora (via rodízio automático ou atribuição manual)</li>
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
          <p class="lead">O CRM tem 4 papéis de acesso. Todo usuário tem exatamente um.</p>

          <div class="table-wrap">
            <table>
              <thead><tr><th>Papel</th><th>Descrição</th></tr></thead>
              <tbody>
                <tr><td><strong>Consultor</strong></td><td>Só enxerga a própria carteira de revendedoras e suas próprias conversas/tarefas</td></tr>
                <tr><td><strong>Gerente</strong></td><td>Enxerga a carteira inteira (todos os consultores), reatribui responsáveis. Não mexe em Configurações</td></tr>
                <tr><td><strong>Financeiro</strong></td><td>Enxerga a carteira inteira pra cruzar dados de inadimplência/cobrança. Não vê Minhas Revendedoras/Tarefas (telas operacionais do consultor) — trabalha em Inativas e Conversas</td></tr>
                <tr><td><strong>Diretoria</strong></td><td>Acesso total: tudo dos outros três papéis + Configurações (Caixas de Entrada, Etiquetas, Agentes, Atividades, Conta) e Fluxos</td></tr>
              </tbody>
            </table>
          </div>

          <h2>Tabela de acesso por módulo</h2>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Módulo</th>
                  <th>Consultor</th>
                  <th>Gerente</th>
                  <th>Financeiro</th>
                  <th>Diretoria</th>
                </tr>
              </thead>
              <tbody>
                <tr><td>Minhas Revendedoras / Tarefas</td><td>✅ (só a própria)</td><td>✅ (toda a carteira)</td><td>❌</td><td>✅ (toda a carteira)</td></tr>
                <tr><td>Inativas / Conversas / Atacado</td><td>✅ (só a própria)</td><td>✅ (toda a carteira)</td><td>✅ (toda a carteira)</td><td>✅ (toda a carteira)</td></tr>
                <tr><td>Gerencial / Relatórios / Times de Vendas</td><td>❌</td><td>✅</td><td>❌</td><td>✅</td></tr>
                <tr><td>Criar/reordenar pipelines</td><td>❌</td><td>✅</td><td>❌</td><td>✅</td></tr>
                <tr><td>Fluxos</td><td>❌</td><td>❌</td><td>❌</td><td>✅</td></tr>
                <tr><td>Configurações (Caixas, Etiquetas, Agentes, Atividades, Conta)</td><td>❌</td><td>❌</td><td>❌</td><td>✅</td></tr>
                <tr><td>Criar etiqueta nova (não a lista existente)</td><td>❌</td><td>✅</td><td>❌</td><td>✅</td></tr>
                <tr><td>Excluir campo/atributo personalizado</td><td>❌</td><td>❌</td><td>❌</td><td>✅</td></tr>
              </tbody>
            </table>
          </div>
          <p class="note">"Toda a carteira" = todas as revendedoras da conta, de todos os consultores. Consultor sempre vê só a sua própria.</p>
        </section>

        <div class="divider" />

        <!-- ══════════════════════════════════════ FLUXOS -->
        <section id="fluxos">
          <h1>Fluxos</h1>
          <p class="lead">Construtor visual de automação de conversa (menu <strong>Fluxos</strong>, exclusivo da Diretoria). Monte uma sequência de blocos conectados que responde sozinha quando o cliente manda uma palavra-chave no WhatsApp.</p>

          <h2>Como criar um fluxo</h2>
          <ol>
            <li>No menu, clique em <strong>Fluxos → + Criar fluxo</strong></li>
            <li>Dê um nome, descrição e escolha o <strong>Canal</strong> (WhatsApp/Instagram)</li>
            <li>Escolha a <strong>Caixa</strong> — é a caixa de WhatsApp específica que vai escutar o gatilho. <strong>Sem escolher uma caixa, o fluxo não dispara em lugar nenhum</strong> (proposital: evita um fluxo de teste responder sem querer numa conversa de cliente real)</li>
            <li>Clique em <strong>Criar fluxo</strong> — o editor visual abre na hora</li>
          </ol>

          <h2>Montando o fluxo</h2>
          <p>Arraste um bloco da barra <strong>Elementos</strong> (esquerda) pro canvas. Puxe uma linha do círculo de saída de um bloco até a entrada de outro pra conectar. Clique num bloco pra abrir o painel de <strong>Configuração</strong> (direita) e preencher os dados dele. Tudo é salvo sozinho (indicador "Salvando.../Salvo" no topo) — também dá pra forçar com o botão <strong>Salvar</strong> ou <kbd>Ctrl+S</kbd>.</p>

          <h2>Os blocos</h2>

          <h3>⚡ Gatilho</h3>
          <p>Todo fluxo começa com um. Escolha o tipo em <strong>Tipo de gatilho</strong>. Hoje só <strong>Palavra-chave</strong> funciona de verdade: quando o cliente manda uma mensagem contendo a palavra configurada, o fluxo começa a rodar. Os outros tipos (Novo contato, Mensagem recebida, Evento, Webhook, Manual) já existem na tela mas ainda não disparam nada — ficam prontos pra quando isso for implementado.</p>

          <h3>💬 Enviar mensagem</h3>
          <p>Manda um texto pro cliente. Aceita variáveis: <code>{{nome}}</code>, <code>{{telefone}}</code>, <code>{{email}}</code> (dados da revendedora) e qualquer variável capturada por um bloco Perguntar mais cedo no mesmo fluxo (ex: <code>{{cor_favorita}}</code>).</p>

          <h3>❓ Perguntar</h3>
          <p>Manda uma pergunta e <strong>para o fluxo</strong>, esperando a resposta do cliente. Quando ele responde, o texto digitado vira o valor da variável que você definir em <strong>Guardar resposta na variável</strong> (ex: <code>nome_prato</code>) — dá pra usar essa variável nos blocos seguintes.</p>

          <h3>🖼️ Enviar mídia (imagem/áudio/documento)</h3>
          <p>Manda um arquivo. Use <strong>Enviar do computador</strong> pra subir o arquivo direto — é o jeito confiável. O campo "URL do arquivo" é uma alternativa, mas um link externo pode não funcionar dependendo de como o WhatsApp está conectado.</p>

          <h3>👆 Botões / 📋 Lista de opções</h3>
          <p>Mostra opções pro cliente escolher e <strong>para o fluxo</strong> esperando a resposta. Como o WhatsApp não permite botão/lista nativo fora da API oficial da Meta, isso vira uma mensagem numerada (<em>"1. Opção A / 2. Opção B"</em>) — o cliente responde digitando o número ou o texto da opção. Se a resposta não bater com nenhuma, o fluxo pede pra responder de novo em vez de travar.</p>

          <h3>🔀 Condição</h3>
          <p>Compara uma variável (capturada num Perguntar, por exemplo) contra um valor e segue por um de dois caminhos: <strong>Sim</strong> ou <strong>Não</strong>. Escolha o que <strong>Verificar</strong>, o <strong>Operador</strong> (é igual a / é diferente de / contém) e o <strong>Valor</strong> de comparação.</p>

          <h3>⏱️ Aguardar</h3>
          <p>Pausa o fluxo pelo tempo definido (segundos/minutos/horas/dias) antes de continuar pro próximo bloco. A pausa é de verdade — o fluxo realmente espera, mesmo que isso leve horas ou dias.</p>

          <h3>🏷️ Ação</h3>
          <p>Executa uma operação no CRM, sem mandar mensagem nenhuma:</p>
          <ul>
            <li><strong>Adicionar/Remover etiqueta</strong> — aplica na conversa (mesma etiqueta que aparece no topo da tela de conversa)</li>
            <li><strong>Atribuir atendente</strong> — muda o responsável pela revendedora</li>
            <li><strong>Atualizar variável</strong> — define/sobrescreve uma variável na mão, pra usar depois em mensagens ou condições</li>
            <li><strong>Enviar webhook</strong> — manda os dados da execução (contato + variáveis capturadas) por POST pra uma URL externa</li>
          </ul>

          <h3>⛔ Encerrar fluxo</h3>
          <p>Marca o fim da linha. Não precisa de configuração.</p>

          <h2>O que já funciona de verdade vs. só editor</h2>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Bloco</th><th>Status</th></tr></thead>
              <tbody>
                <tr><td>Gatilho por Palavra-chave</td><td><span class="badge green">Funciona</span></td></tr>
                <tr><td>Enviar mensagem / mídia</td><td><span class="badge green">Funciona</span></td></tr>
                <tr><td>Perguntar / Botões / Lista</td><td><span class="badge green">Funciona</span></td></tr>
                <tr><td>Condição / Aguardar / Ação</td><td><span class="badge green">Funciona</span></td></tr>
                <tr><td>Gatilho: Novo contato / Mensagem recebida / Evento / Webhook / Manual</td><td><span class="badge yellow">Só editor</span></td></tr>
                <tr><td>Publicar (rascunho x publicado) / Testar fluxo / Modelos prontos</td><td><span class="badge gray">Ainda não existe</span></td></tr>
              </tbody>
            </table>
          </div>

          <h2>Gerenciando fluxos</h2>
          <p>Na listagem (<strong>Fluxos</strong>), cada card mostra o status (Ativo/Inativo), quantidade de etapas e a caixa vinculada. No menu de <strong>⋮</strong> (três pontos) ou nos ícones do card: <strong>Editar</strong>, <strong>Duplicar</strong> (cria uma cópia inativa), <strong>Renomear</strong>, <strong>Ativar/Desativar</strong> (o interruptor) e <strong>Excluir</strong>.</p>
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
    background: rgba(255, 0, 127,0.08);
    color: #ff007f;
    font-weight: 600;
    .arrow { opacity: 1; color: #ff007f; }
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
  border-bottom: 2px solid #ff007f;
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

h3 {
  font-size: 0.88rem;
  font-weight: 700;
  color: var(--text-main);
  margin: 1.1rem 0 0.3rem;
}

p { font-size: 0.88rem; color: var(--text-muted); line-height: 1.7; margin: 0.4rem 0; }

code, kbd {
  font-family: 'SFMono-Regular', Consolas, monospace;
  font-size: 0.82rem;
  background: var(--bg-tertiary);
  color: var(--text-main);
  padding: 0.1rem 0.35rem;
  border-radius: 4px;
}

kbd {
  border: 1px solid var(--border-color);
  border-bottom-width: 2px;
  font-size: 0.78rem;
}

ul, ol {
  padding-left: 1.3rem;
  font-size: 0.88rem;
  color: var(--text-muted);
  line-height: 1.8;
  margin: 0.4rem 0 0.8rem;

  strong { color: var(--text-main); }
}

a { color: #ff007f; }

.inline-link {
  background: none;
  border: none;
  padding: 0;
  color: #ff007f;
  font-size: inherit;
  font-family: inherit;
  cursor: pointer;
  text-decoration: underline;
}

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

  svg { color: #ff007f; flex-shrink: 0; margin-top: 2px; }

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
  &.blue   { background: rgba(255, 0, 127,0.1);   color: #cc0066; }
  &.red    { background: rgba(239,68,68,0.1);    color: #dc2626; }
}

.code-block {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-left: 3px solid #ff007f;
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
  background: rgba(255, 0, 127,0.05);
  border: 1px solid rgba(255, 0, 127,0.15);
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
