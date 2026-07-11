# IA_FUNDED_GOLD V1.2.3.3 — AUDITORIA DO LIFECYCLE DE PENDENTES

Data da auditoria: 2026-07-11
Escopo: eliminar o loop CRIAR PENDENTE → CANCELAR ~1s DEPOIS → RECRIAR → CANCELAR → REPETIR.

---

## 1. ARQUIVOS RECEBIDOS (FASE 0)

| Arquivo | Tamanho | SHA-256 |
|---|---|---|
| IA_FUNDED_GOLD_V1.2.3.2_PENDING_HANDOFF_FIXED.mq5 (original, intocado) | 239.822 bytes / 6.939 linhas | `7e85d6d413cdbe687adcd34c3783a956e709d22c4a93ff033d042b83ff9b39bc` |
| pedindoffhand.html (relatório Strategy Tester) | 5.390.948 bytes (UTF-16LE) | `84be9c263977125e05e4ba9c36359f5da45a153fade9c6e01861bde931f5a4f8` |

Pertencimento confirmado no cabeçalho do HTML: `Expert: IA_FUNDED_GOLD_V1.2.3.2_PENDING_HANDOFF_FIXED`, XAUUSD, M15 (2026.07.01–2026.07.03), FTMO-Demo Build 5836. O original **não** foi sobrescrito; a correção está em `IA_FUNDED_GOLD_V1.2.3.3_PENDING_LIFECYCLE_FIXED.mq5` (7.438 linhas).

---

## 2. NÚMEROS RECALCULADOS DO HTML (FASE 1)

Recalculados diretamente da tabela **Orders** (9.845 linhas de ordem parseadas: 176 a mercado + 9.669 pendentes) e da tabela **Deals** (205 linhas).

### 2.1 Totais de pendentes

| Métrica | BUY | SELL | TOTAL | Referência do prompt |
|---|---|---|---|---|
| Creates | 1.765 | 7.904 | **9.669** | ~9.669 ✔ |
| Cancels | 1.748 | 7.887 | **9.635 (99,65%)** | ~9.635 / 99,65% ✔ |
| Executions (filled) | 14 | 14 | **28 (0,29%)** | ~28 ✔ |
| Expirations | 3 | 3 | **6 (0,06%)** | ~6 ✔ |
| Ativas no encerramento | 0 | 0 | 0 | — |

Por tipo: buy limit 1.312 canceladas / 2 expiradas / 1 executada; buy stop 436 / 1 / 13; sell limit 1.623 / 0 / 2; sell stop **6.264** / 3 / 12.

### 2.2 Latência criação→cancelamento

| Métrica | ALL | BUY | SELL |
|---|---|---|---|
| Média | 9,42 s | 23,28 s | 6,34 s |
| Mediana | **1,0 s** | 1,0 s | 1,0 s |
| Mesmo segundo | 68 (0,71%) | 12 (0,69%) | 56 (0,71%) |
| ≤ 1 s | **8.602 (89,28%)** | 83,58% | 90,54% |
| ≤ 2 s | 9.117 (94,62%) | 88,50% | 95,98% |
| ≤ 5 s | 9.263 (96,14%) | 90,45% | 97,40% |
| ≤ 10 s | 9.291 (96,43%) | 90,96% | 97,64% |

Histograma: **8.534 cancelamentos com exatamente 1 s de vida** — a assinatura de "criar → esperar 1 segundo → cancelar". Gap cancelamento→recriação seguinte: média 1,11 s, mediana **1,0 s** (n=9.142). Ciclo completo típico: **2 s**.

### 2.3 Financeiro (bate com o resumo do HTML)

Depósito 97.000,00; Total Net Profit **-104,19**; Profit Factor **0,88**; Total Trades **102** (204 deals); Balance DD 356,15 (0,37%); Equity DD **209,76 (0,22%)**; Profit Trades **76 (74,51%)**; Largest profit 56,07 / loss -91,76; Bars 184; Ticks 532.759; History Quality 100%.

Confirmação da hipótese central do prompt: a V1.2.3.2 **apenas transformou** CRIAR→CANCELAR-no-mesmo-segundo (V1.2.3.1: 82,84% same-second) em CRIAR→ESPERAR ~1s→CANCELAR (V1.2.3.2: 0,71% same-second, 89,28% ≤1s). **PROVADA** — ver seção 7.

### 2.4 Sequências CREATE→CANCEL→CREATE (cadeias)

81 cadeias com ≥3 cancelamentos consecutivos (gap ≤10 s) contendo **9.223 ordens = 95,7% de todos os cancelamentos**. Máx 832, média 113,9, mediana 11. Apenas **7 trocas stop↔limit** dentro de cadeias (o loop mantém direção E tipo). Delta de preço entre ordens consecutivas: mediana **11 points** (US$ 0,11), 49% ≤10 pts — muito abaixo de `PendingRepositionStepPoints=300`, provando que o loop NÃO passa pela reposição por distância. 30/81 cadeias têm entrada a mercado em ±10 s da janela; 20/81 começam exatamente em abertura de candle M15 (recalculo de bias/regime).

Casos concretos (estado de posições reconstruído da tabela Deals):

| Caso | Tickets | Direção/Tipo | Janela | n | Posições B/S | Pend | Vida típica |
|---|---|---|---|---|---|---|---|
| SELL mais longa | 8570..9401 | SELL STOP | 02/07 15:00:00→15:29:09 | 832 | 3/4 | 1 SELL | 1 s |
| SELL (fim=entrada mercado) | 1478..2147 | SELL LIMIT | 01/07 12:15:00→12:40:15 | 670 | 4/2 | 1 SELL | 1 s |
| SELL (fim=SL+BUY 08:00:07) | 5333..6102 | SELL STOP | 02/07 07:30:00→08:00:07 | 770 | 3/4 | 1 SELL | 1 s |
| BUY mais longa | 4292..4889 | BUY LIMIT | 02/07 02:24:58→03:08:39 | 597 | 2/4 | 1 BUY | 1 s (a 1ª viveu 21 min até o fill do ticket 4290 às 02:45:58 + virada de candle) |
| Perto de Rebalance | 2549 (`IA_FG_V122_REBALANCE_SELL` 01/07 17:00:51) | — | cadeias 2298..2556 ao redor | — | — | — | — |

Amostra (ticket/criação/cancelamento): 8570 15:00:00→15:00:01; 8571 15:00:02→15:00:03; 8572 15:00:04→15:00:05 … preços 4059.12, 4058.49, 4057.98 (deltas 63/51 pts, depois ~6-20 pts).

---

## 3. FASE 2 — TABELA COMPLETA DE MUTAÇÕES (V1.2.3.2, linhas do original)

Toda mutação passa por CTrade em modo síncrono (não há `SetAsyncMode`, `OrderSend`, `OrderSendAsync` nem `MqlTradeRequest` manual). `OnTradeTransaction` (883) apenas marca `g_tradeStateDirty` e persiste — idempotente por construção.

| # | Função | Linha | Chamada | Tipo | Autoridade | Condição de disparo | Confirmação | Pode gerar CREATE→CANCEL→CREATE? |
|---|---|---|---|---|---|---|---|---|
| M1 | SendMarketOrderV122 | 1828/1830 | trade.Buy/trade.Sell | DEAL mercado | própria (retcode + ConfirmMarketPosition + MarkMarketRequestPending) | par/direcional/rebalance/handoff | contagem + timeout 10 s | não (consome slot) |
| M2 | RequestPendingCreateV1231 | 2392-2398 | trade.BuyStop/BuyLimit/SellStop/SellLimit | PENDING create | V1231 (única) | PlaceDynamicBuy/SellPending | lifecycle CREATE_REQUESTED→ACTIVE via servidor | **SIM — metade do loop** |
| M3 | RequestPendingModifyV1231 | 2460 | trade.OrderModify | PENDING modify | V1231 (única) | Reposition (toward-market, ≥300 pts) | lifecycle MODIFY_REQUESTED→confirm por preço | não |
| M4 | RequestPendingCancelV1231 | 2508 | trade.OrderDelete | PENDING cancel | V1231 (única) | 6 call sites (abaixo) | lifecycle CANCEL_REQUESTED→ticket ausente | **SIM — outra metade** |
| M5 | CloseAllBasket/CloseBuy/CloseSell | 5139/5171/5203 | trade.PositionClose | DEAL close | escopo de fechamento V122 | metas/DD/extração | EXIT_RECONCILING + dirty | não |
| M6 | ModifyPositionSL | 6672 | trade.PositionModify | SL | própria + confirmação servidor | BE/trailing | releitura do SL | não |

Call sites de M4 (cancel): FreeSlotForPriorityRebalanceV122 (1235, "liberar_slot_rebalance"); FreePendingSlotForMarketEntryV123 (1289, "liberar_slot_entrada_mercado"); RepositionDynamicPendingOrders (4616 "invalida_<motivo>", 4636 "mudanca_tipo_pendente"); CancelInvalidPendingOrders (4779 "expirada/invalida_ou_duplicada"); CancelAllPendingOrders (4814 "cancelar_todas_pendentes", chamado de 724, 909, 951, 4358, 4365, 4371, 4687, 4694, 4700, 5125, 5573, 5622).

**Não existem mutações diretas fora da autoridade V1231 para pendentes** (`DeletePendingOrderV122` é código morto — declarado em 539, nunca chamado). Trava de 1 mutação/tick: `g_pendingMutationSentThisTickV1231` (resetada no início do OnTick, linha 763), verificada em todos os caminhos, compartilhada entre create/modify/cancel/handoff/rebalance/cancelall. `OnTradeTransaction` não envia mutações → não fura a trava.

---

## 4. CHECKPOINT DA CAUSA RAIZ

```
[CHECKPOINT_CAUSA_RAIZ_V1232]
ARQUIVO_AUDITADO:
IA_FUNDED_GOLD_V1.2.3.2_PENDING_HANDOFF_FIXED.mq5, 239.822 bytes,
SHA-256 7e85d6d413cdbe687adcd34c3783a956e709d22c4a93ff033d042b83ff9b39bc

RELATORIO_AUDITADO:
pedindoffhand.html, 5.390.948 bytes

NUMEROS_RECALCULADOS_DO_HTML:
creates=9.669 (B1.765/S7.904) cancels=9.635 (99,65%) executions=28 expirations=6
mediana_vida=1,0s same-second=0,71% <=1s=89,28% ciclo_tipico=2s
95,7% dos cancels em 81 cadeias CREATE->CANCEL->CREATE

CAUSA_RAIZ_PRIMARIA:
GetDesiredPendingOrderV121 (linha 4225) valida a pendente EXISTENTE contando o
proprio ticket como slot ocupado: CountBuy/SellExposureSlots (4908/4913) =
posicoes + pendentes; IsGeometryApplicableV121 (3519/3525) -> CanAddTowardBiasV122
(1507: side_slots >= target -> false) / CanAddCounterBiasRecoveryV122 (1523).
Quando posicoes_do_lado == target_bias - 1, a propria pendente fecha o target:
com ela viva side_slots == target -> GetDesired falha ("bias_bloqueia_momentum"/
"bias_limite_recovery") -> RepositionDynamicPendingOrders linha 4616 CANCELA
("invalida_<motivo>"); sem ela side_slots == target-1 -> a MESMA validacao passa
-> PlaceDynamicBuy/SellPending (4476/4547) RECRIA. O exclude_order_ticket
existia apenas para a zona (4318), nao para os checks de slot/bias.
Variante da mesma familia: "limite_recovery_contra_extrema" (4255-4265) usa
CountRecoveryContraExtremaV121 = side_slots-1 incluindo a propria pendente.

CAUSAS_SECUNDARIAS:
(1) Handoff valida a troca DEPOIS de cancelar: BuildDirectionalCandidateV121
    chama FreePendingSlotForMarketEntryV123 (3982, cancela) ANTES de
    HasDirectionalSlotRoom (3989); ExecuteEntryCandidateV121 refaz cooldown/
    exposicao/direcional/zona (4083-4108) APOS o cancelamento -> caminho
    CANCELAR -> FALHAR ENTRADA -> LIMPAR HANDOFF (2644-2647) -> RECRIAR.
(2) Rebalance identico: CanExecuteRebalanceV122 chama FreeSlotForPriorityRebalance
    (1159, cancela) ANTES de HasDirectionalSlotRoom (1168); slot liberado nao e
    reservado -> ManageDynamic pode recriar antes do rebalance consumir.
(3) Replacement de tipo nao transacional: Reposition 4636 cancela
    ("mudanca_tipo_pendente") e conta com recriacao generica do gerenciador.

SEQUENCIA_BUY_RECONSTRUIDA:
Tickets 4292..4889 (buy limit, 02/07 02:24:58->03:08:39, 597 ordens, 2 BUY/4 SELL).
Ticket 4292 vive 21 min; as 02:45:58 o sell stop 4290 executa e o candle 02:45
recalcula bias -> target_buy passa a posicoes+1 -> buy_slots(2 pos+1 pend)=3 >=
target(3) -> GetDesired(BUY) falha "bias_limite_recovery" -> Reposition 4616
cancela; Place (buy_slots=2<3) recria 1s depois; repete ate 03:08:39.

SEQUENCIA_SELL_RECONSTRUIDA:
Tickets 8570..9401 (sell stop, 02/07 15:00:00->15:29:09, 832 ordens, 3 BUY/4 SELL,
bias=SELL target_sell=5, regime<0 -> geometria MOMENTUM -> sell stop):
sell_slots(4 pos+1 pend)=5 >= 5 -> "bias_bloqueia_momentum" -> cancel 4616;
sem a pendente 4<5 -> Place 4547 recria; cadencia exata de 2s imposta pelos
guards de mesmo-segundo (cancel: 2487; create: 2346).

FUNCAO_QUE_CRIA:
ManageDynamicPendingOrders (4349) -> PlaceDynamicBuyPending (4418) /
PlaceDynamicSellPending (4489) -> RequestPendingCreateV1231 (2342).

FUNCAO_QUE_CANCELA:
RepositionDynamicPendingOrders (4560), linha 4616, motivo "invalida_<reason>"
com reason de GetDesiredPendingOrderV121 -> IsGeometryApplicableV121 ->
CanAddTowardBiasV122 / CanAddCounterBiasRecoveryV122.

FUNCAO_QUE_RECRIA:
ManageDynamicPendingOrders (4382-4395: need_side = pending_side < 1) ->
PlaceDynamic*Pending -> RequestPendingCreateV1231. Recria porque a mesma
condicao, avaliada sem a pendente, passa.

CONDICAO_QUE_DISPARA_O_CANCELAMENTO:
side_slots (INCLUINDO a propria pendente) >= target do bias
(ou side_slots-1 >= MaxEntradasRecoveryContraExtremaV121 em regime extremo).

CONDICAO_QUE_DISPARA_A_RECRIACAO:
CountPending<lado> == 0 && side_slots (SEM a pendente) < target && demais checks
identicos aos que a propria criacao anterior ja havia passado.

POR_QUE_O_BLOQUEIO_DE_MESMO_SEGUNDO_FALHOU:
RequestPendingCancelV1231 (2487) bloqueia cancel apenas enquanto
TimeCurrent() <= last_create; RequestPendingCreateV1231 (2346) bloqueia create
apenas enquanto TimeCurrent() <= last_cancel. Sao guards de SERIALIZACAO por
segundo, nao removem a contradicao logica criar-e-invalidar. Resultado: cancel
em create+1s e create em cancel+1s -> loop perfeito de 2s (8.534 vidas de
exatamente 1s no HTML). Delay nao e atomicidade.

REPOSICIONAMENTO_USA_MODIFY:
PARCIALMENTE. Reposicao por distancia usa OrderModify (2460, toward-market,
threshold 300 pts) — correto e preservado. Mas a INVALIDACAO (4616) e a mudanca
de tipo (4636) usavam cancel+recreate sem transacao.

RECRIACAO_AUTOMATICA_APOS_CANCELAMENTO:
SIM. need_buy/need_sell = pendingCount<lado> < 1 (4386-4387) sem distinguir por
que a pendente sumiu (executada/expirada/cancelada por quem).

HANDOFF_VALIDA_TROCA_ANTES_DO_CANCELAMENTO:
NAO. Distancia/zona/score/cooldown sim (Build 3890-3978), mas viabilidade
direcional (HasDirectionalSlotRoom) e margem so depois do cancel (3989, 4097).

REBALANCE_RESERVA_REALMENTE_O_SLOT:
NAO. FreeSlotForPriorityRebalanceV122 cancela e retorna; nada impede o
gerenciador de recriar a pendente antes da entrada de rebalance (alem do guard
de 1s), e a viabilidade direcional do rebalance so e checada depois (1168).

CONFLITO_ENTRE_AUTORIDADES:
SIM (indireto). Reposition/CancelInvalid/Handoff/Rebalance nao disputam o mesmo
ticket simultaneamente (trava de tick + lifecycle busy), mas Handoff/Rebalance
cancelam e o ManageDynamic recria sem saber do contexto -> ping-pong entre
autoridades legitimas.

CONFIRMACAO_DO_SERVIDOR:
PARCIAL-ADEQUADA. Retorno booleano NAO e tratado como terminal: ha maquina
V1231 (CREATE/MODIFY/CANCEL_REQUESTED -> CONFIRMING -> ACTIVE/NONE) reconciliada
contra OrdersTotal() a cada tick com timeout de 10s. O problema nao era a
confirmacao, era a DECISAO de cancelar.

UMA_MUTACAO_POR_CICLO:
COMPROVADA (g_pendingMutationSentThisTickV1231, resetada em OnTick 763,
verificada em todos os caminhos de pendentes; OnTradeTransaction nao muta).
Mas 1 mutacao/tick nao impede 1 cancel no tick N e 1 create no tick N+1 — o
loop respeita a trava.

FUNCOES_MINIMAS_QUE_PRECISAM_SER_ALTERADAS:
GetDesiredPendingOrderV121, IsGeometryApplicableV121, CanAddTowardBiasV122,
CanAddCounterBiasRecoveryV122 (autoexclusao do proprio slot);
FreePendingSlotForMarketEntryV123, FreeSlotForPriorityRebalanceV122 (simulacao
da troca ANTES do cancel); RepositionDynamicPendingOrders (replacement
transacional + motivos); RequestPendingCancelV1231, CancelAllPendingOrders,
CancelInvalidPendingOrders (motivo estrutural obrigatorio);
ManageDynamicPendingOrders, PlaceDynamicBuy/SellPending (driver/gates de
replacement); OnDeinit (sumario); prototipos; + novas funcoes auxiliares V1233.

FUNCOES_QUE_DEVEM_PERMANECER_INTOCADAS:
OnTick, OnTradeTransaction, OnInit (exceto call site de CancelAll),
SendMarketOrderV122, OpenBuySellPair, OpenDirectionalOrder,
CanOpenDirectionalEntry, SelectAndExecuteCandidatesV121,
BuildDirectionalCandidateV121, ExecuteEntryCandidateV121,
ScoreEntryCandidateV121, EntryThresholdV121, CanUseDirectionalCooldownV121,
IsDistinctEntryZoneV121, GetAdaptiveDistancePoints*, DetectRegime*,
UpdateDirectionalBiasV122, GetTarget*SlotsV122, ManageBilateralPresenceV122,
BuildRebalanceCandidateV122, CanExecuteRebalanceV122, ExecuteRebalanceV122,
ManageBreakEven, ManageSmartTrailing, ManageBasketClosing,
ManagePriceBasedBasketClosing, ManageBasketDrawdown, ManageDailyRisk,
ManageDailyProfitTarget, GerenciarProtecaoLucroCestaMFE, TryExtractWeakSideV123,
CloseAllBasket/CloseBuy/CloseSell (exceto call site), RequestPendingCreateV1231,
RequestPendingModifyV1231, ReconcilePendingLifecycleV1231,
ProcessMarketEntryHandoffV1232, ClearMarketEntryHandoffV1232,
HasDirectionalSlotRoom, HasExposureRoomIncludingPendings, Count*/Limit*/Get*,
RebuildExposureStateFromServer, Persist/RestoreBasketState, todos os inputs.

PLANO_DO_PATCH_MINIMO:
1) Autoexclusao: GetDesiredPendingOrderV121 passa ajuste -1 (se o ticket
   excluido e pendente viva do lado) para os checks de bias e contra-extrema.
   Cancel-condicao vira o complemento exato da create-condicao -> o flip-flop
   estrutural desaparece sem tocar na politica de alocacao.
2) Troca validada antes do cancel: SimulatePendingSwapV1233 (estado menos
   pendente, mais posicao: limites direcionais, desequilibrio, exposicao
   liquida, margem) obrigatoria em Handoff e Rebalance antes do OrderDelete.
3) Replacement transacional de tipo: reserva estado (lado, ticket antigo, tipo),
   cancela uma vez com motivo REPLACE_ORDER_TYPE, aguarda confirmacao V1231,
   cria exatamente a substituta reservada (REPLACED) ou libera (RELEASED/
   TIMEOUT); gerenciador do lado bloqueado durante o fluxo.
4) Motivo estrutural obrigatorio (enum V1233) em todo cancel + log completo +
   contadores por motivo + sumario de reconciliacao no OnDeinit.

RISCO_DE_REGRESSAO:
BAIXO. Nenhum input, sinal, lote, saida ou risco alterado; caminhos de mercado
intactos; a autoexclusao so muda a avaliacao da PROPRIA pendente existente.

VEREDITO_ANTES_DO_PATCH:
NAO CORRIGIDO (V1.2.3.2 apenas espacou o loop em 1s).
```

---

## 5. HIPÓTESES A–P — CLASSIFICAÇÃO FINAL

| # | Hipótese | Veredito | Evidência |
|---|---|---|---|
| A | Handoff cancela mas entrada não consome slot | **CAUSA SECUNDÁRIA** | Execute falha pós-cancel (4083-4108) → release (2644) → recreate; 30/81 cadeias com mercado em ±10 s |
| B | Viabilidade da troca avaliada depois do cancelamento | **CAUSA SECUNDÁRIA** (confirmada) | HasDirectionalSlotRoom em 3989 APÓS FreePendingSlot em 3982; margem idem |
| C | Reposition cancela+recria em vez de Modify | **DESCARTADA como primária / PARCIAL** | Reposição por preço USA Modify (2460); o cancel vem da INVALIDAÇÃO (4616), não da distância (deltas ~11 pts ≪ 300) |
| D | Alternância contínua stop↔limit | **DESCARTADA** | 7 trocas de tipo em 9.142 transições de cadeia |
| E | A mesma condição que cria passa a invalidar no tick seguinte | **CAUSA PRIMÁRIA** | side_slots inclui a própria pendente; prova nas 8 cadeias (3/4+1, 2/4+1, 4/2+1 vs targets 5/3/3) |
| F | Presença bilateral recria ordem removida por outra autoridade | **NÃO COMPROVADA** | ManageBilateralPresence só abre POSIÇÕES a mercado |
| G | Rebalance cancela e não consome/reserva o slot | **CONTRIBUINTE** (estrutura idêntica a B; 1 rebalance no teste) | 1157→1159 antes de 1168 |
| H | Autoridades disputam o mesmo ticket | **CONTRIBUINTE** (ping-pong entre cancel de Handoff/Rebalance e recreate do gerenciador; nunca 2 mutações no mesmo tick) | trava única + lifecycle busy comprovados |
| I | Estado local limpo antes da confirmação | **DESCARTADA** | lifecycle V1231 espera servidor/timeout antes de NONE |
| J | TimeCurrent() em segundos apenas adiou o cancelamento | **CAUSA SECUNDÁRIA** (mecanismo da cadência) | guards 2346/2487; 8.534 vidas de exatamente 1 s |
| K | Variação normal de preço tratada como substituição | **DESCARTADA** | threshold 300 pts respeitado; deltas medidos ~11 pts vêm do loop, não o causam |
| L | pendingCount==0 autoriza criar automaticamente | **CAUSA SECUNDÁRIA** | need_side = pending<lado> < 1 (4386-4387), sem reconciliar destino |
| M | Ticket limpo antes de reconciliar | **DESCARTADA** | SetPendingLifecycle mantém ticket até confirm/timeout |
| N | OnTradeTransaction processa transação atrasada como atual | **DESCARTADA** | handler só marca dirty flag (idempotente) |
| O | Mais de uma mutação permitida no mesmo ciclo | **DESCARTADA** | trava única compartilhada comprovada |
| P | Outro caminho | **CONFIRMADO = E** (variante "limite_recovery_contra_extrema", mesma família da primária) | 4255-4265 |

---

## 6. AUDITORIA DAS FUNÇÕES OBRIGATÓRIAS (resumo dos achados)

- **OnInit (667)**: reconstrói via RestoreBasketState + RebuildExposureStateFromServer + InitializePendingLifecycleV1231 (lados a partir de OrdersTotal do servidor) — recuperação adequada; pendentes órfãs em conta flat são canceladas (724). Estado de replacement V1233 não é persistido: após restart o gerenciador converge pelo estado do servidor (aceitável; documentado).
- **OnTick (759)**: ordem Reconcile→risco→saídas→bilateral→candidatas→CancelInvalid→ManageDynamic; 1 mutação/tick.
- **ReconcilePendingLifecycleV1231 (2304)**: confirma CREATE por existência do lado, CANCEL por ausência do ticket, MODIFY por preço±tick_size; timeout 10 s com rebuild — correto.
- **ProcessMarketEntryHandoffV1232 (2571)**: CANCEL_REQUESTED→SLOT_READY exige ticket ausente E lifecycle ocioso; timeout 2×10 s; porém re-validações pós-cancel (risco/slot/execução) eram tardias → corrigido na origem (simulação pré-cancel).
- **CancelAllPendingOrders (4788)**: 1 cancel/tick mesmo em fechamento (demais ficam para os próximos ticks) — mantido; agora com motivo estrutural e liberação de replacement.
- **GetDesiredPendingOrder legado (6522)**: não usado no modo atual (motor agressivo ativo); intocado.
- **UpdateSymbolData/HasValidQuoteV122**: idade máxima de tick 3 s — ok.
- Demais funções da lista obrigatória: auditadas; sem outras vias de mutação de pendentes.

---

## 7. PROVA DA CADÊNCIA (mecanismo do "1 segundo")

1. Tick em T (novo segundo): `PlaceDynamicSellPending` cria (create-guard livre: T > last_cancel). `last_create = T`.
2. Ticks restantes do segundo T: cancel bloqueado (`TimeCurrent() <= last_create`, 2487).
3. Primeiro tick de T+1: `Reconcile` confirma CREATE (ACTIVE). `Reposition` → `GetDesired` falha (side_slots==target) → cancel (M4). `last_cancel = T+1`.
4. Ticks restantes de T+1: create bloqueado (`TimeCurrent() <= last_cancel`, 2346); Reconcile confirma CANCEL (ticket ausente → NONE).
5. Primeiro tick de T+2: create de novo. **Ciclo = 2 s; vida = 1 s; gap = 1 s** — exatamente as distribuições medidas (mediana 1,0 s / 1,0 s).

Os 68 cancels de mesmo segundo (0,71%) vêm de `CancelAllPendingOrders` (bypass legítimo do guard em fechamentos/risco/flat).

---

## 8. PATCH APLICADO (V1.2.3.3) — blocos marcados `// V1.2.3.3 PENDING LIFECYCLE FIX`

### 8.1 Funções alteradas (lista definitiva)

| Função | Mudança |
|---|---|
| `GetDesiredPendingOrderV121` | calcula `side_slots_adjust = PendingSideSlotAdjustV1233(lado, exclude_ticket)` e o repassa aos checks de bias e contra-extrema |
| `IsGeometryApplicableV121` | novo parâmetro opcional `side_slots_adjust=0` repassado aos dois checks de bias (callers de mercado inalterados) |
| `CanAddTowardBiasV122` / `CanAddCounterBiasRecoveryV122` | novo parâmetro opcional `side_slots_adjust=0` somado ao side_slots (clamp ≥0); política de targets intacta |
| `FreePendingSlotForMarketEntryV123` | `SimulatePendingSwapV1233` obrigatória ANTES do cancel (limites direcionais/desequilíbrio/exposição líquida/margem no estado pós-troca); skip de lado sob replacement; motivo MARKET_HANDOFF |
| `FreeSlotForPriorityRebalanceV122` | idem para o Rebalance; motivo REBALANCE |
| `RepositionDynamicPendingOrders` | skip de lado sob replacement; invalidação genuína → STRUCTURAL_INVALIDATION/INVALID_PRICE; `wrong_type` → replacement transacional (valida margem da substituta ANTES, reserva tipo+ticket, cancela com REPLACE_ORDER_TYPE) |
| `ManageDynamicPendingOrders` | chama `ProcessPendingReplacementV1233()` antes da reposição/criação; CancelAll com motivos |
| `PlaceDynamicBuyPending` / `PlaceDynamicSellPending` | gate: lado sob replacement não recria (log `[V1233_PENDING_RECREATE_BLOCKED]` + contador) |
| `RequestPendingCancelV1231` | assinatura `(lado, ticket, MOTIVO_V1233, detalhe, global_scope=false)`; captura idade/contexto antes do OrderDelete; log `[V1233_PENDING_CANCEL_REASON]` completo (ticket, direção, tipo, preço, idade, motivo, posições B/S, pendentes B/S, exposição, handoff/rebalance/replacement ativos, mutation_id); contador por motivo |
| `CancelAllPendingOrders` | assinatura com motivo; libera replacements; repassa `global_scope=true` (bypass do guard de mesmo segundo preservado, idêntico ao comportamento V1.2.3.2) |
| `CancelInvalidPendingOrders` | motivo por condição (EXPIRED / STRUCTURAL / RECONCILIATION-duplicada / RISK / SYMBOL_DISABLED / GLOBAL_CLOSE); skip de lado sob replacement |
| `OnDeinit` | `[V1233_PENDING_LIFECYCLE_SUMMARY]` com cancels por motivo, replacement requests/completed/released/timeouts, recriações bloqueadas, trocas reprovadas na simulação e pendentes ativas |
| call sites | OnInit(RECONCILIATION), DetectBasketStateTransitionV122/ManageFlatPairReopenV122/CloseAllBasket(GLOBAL_CLOSE), ManageBasketDrawdown/ManageDailyRisk(RISK_EMERGENCY) |
| protótipos | atualizados/adicionados |

### 8.2 Funções novas

`PendingCancelReasonTextV1233`, `PendingSideSlotAdjustV1233`, `SimulatePendingSwapV1233`, `PendingReplaceActiveV1233`, `ReleasePendingReplacementV1233`, `ProcessPendingReplacementV1233` + enum `ENUM_PENDING_CANCEL_REASON_V1233` + estado/contadores globais. Nenhum novo input.

### 8.3 Como cada regra obrigatória foi cumprida

1. **Mesma direção+tipo, só preço** → continua em `RequestPendingModifyV1231`/OrderModify (inalterado); a invalidação espúria que impedia chegar ao Modify foi removida na raiz.
2. **Mudança real de tipo** → replacement transacional: validação prévia (margem), reserva (lado/ticket/tipo), 1 cancel (REPLACE_ORDER_TYPE), confirmação V1231, 1 create da substituta reservada, conclusão REPLACED/RELEASED/TIMEOUT, gerenciador do lado bloqueado (Reposition/Place/CancelInvalid/Handoff/Rebalance pulam o lado).
3. **Recriação** → só após lifecycle ocioso (busy-gate preexistente) + fora de handoff/replacement + condição recalculada; com a autoexclusão, cancel estrutural ⇒ create nega — simetria exata, sem recriação cega.
4. **Handoff** → troca inteira simulada antes do cancel; candidata/ticket continuam reservados no estado V1232; concorrência bloqueada como antes.
5. **Rebalance** → ativo; cancel só passa se a troca simulada é viável; fluxo transacional equivalente ao handoff.
6. **Autoridade única** → mantida (V1231) e agora com motivo obrigatório.
7. **Servidor** → confirmações V1231 inalteradas (booleano nunca é terminal).
8. **Uma mutação por ciclo** → trava única preservada; driver de replacement também a respeita.
9. **Reinicialização** → InitializePendingLifecycleV1231 + RebuildExposureStateFromServer (inalterados); replacement não persistido converge pelo servidor.

---

## 9. CENÁRIOS A–Z

| Cenário | Estado inicial → função → resultado | PASS/FAIL |
|---|---|---|
| A. Pendente normal permanece | GetDesired c/ autoexclusão passa → Reposition não cancela; Place não duplica (count≥1) | **PASS** (GetDesiredPendingOrderV121) |
| B. Mesmo tipo, novo preço | far_from_target ≥300 pts e toward-market → `RequestPendingModifyV1231` (OrderModify), mesmo ticket | **PASS** (4666 orig / 5090 novo) |
| C. Buy stop→buy limit | wrong_type → margem validada → reserva → cancel REPLACE_ORDER_TYPE → confirm → create BUY LIMIT reservado → REPLACED | **PASS** (Reposition + ProcessPendingReplacementV1233) |
| D. Sell stop→sell limit | idem lado SELL | **PASS** |
| E–H. Handoff BUY/SELL removendo BUY/SELL | FreePendingSlot: dois passes (mesmo lado preferido) + SimulatePendingSwap por pendente; só cancela troca viável | **PASS** |
| I. Falha direcional antes do cancel | SimulatePendingSwap reprova (troca_limite_*/troca_desequilibrio) → `[V1233_PENDING_MUTATION_BLOCKED]`, sem cancel | **PASS** |
| J. Falha de exposição antes do cancel | exposição líquida simulada pós-troca reprova → sem cancel | **PASS** |
| K. Falha de zona antes do cancel | zona checada no Build (3965) ANTES de FreePendingSlot (inalterado) | **PASS** |
| L. Falha de cooldown antes do cancel | cooldown/budget checados no Build (3890) ANTES de FreePendingSlot | **PASS** |
| M. Spread sobe após cancel | Execute→SendMarketOrder preflight falha → release; recriação segue validação completa; sem cadeia (Build revalida antes de novo cancel) | **PASS** (autolimitado) |
| N. DD bloqueia durante handoff | ProcessMarketEntryHandoff SLOT_READY: bloqueio de risco → release; CancelInvalid cancela pendentes com RISK_EMERGENCY; creates bloqueados por IsPendingFiltersOK | **PASS** |
| O. Margem insuficiente | simulada ANTES do cancel (handoff/rebalance/replacement); Place já checava | **PASS** |
| P. Ticket executa antes da confirmação do cancel | OrderDelete falha/ticket ausente → lifecycle reconcilia ausência como destino (executada); replacement: release "cancelamento_nao_confirmado" ou create revalidado | **PASS** |
| Q. Timeout | lifecycle 10 s (2263-2297) + replacement 10 s + handoff 20 s → estados sempre com saída | **PASS** |
| R. Rebalance tenta usar o slot | com handoff ativo FreeSlotForPriorityRebalance retorna false (1205); replacement-gate novo | **PASS** |
| S. CancelAll durante handoff | CancelAllPendingOrders limpa handoff (4790-4794) e agora libera replacements | **PASS** |
| T. Duas candidatas, mesmo slot | handoff único (IsMarketHandoffActive bloqueia 2º, 1260); 1 mutação/tick | **PASS** |
| U. BUY e SELL mutam no mesmo ciclo | trava única: 2º pedido vira ACTION_BUSY | **PASS** |
| V. Vários ticks no mesmo TimeCurrent() | guards de mesmo segundo (2346/2487) + trava por tick; driver de replacement espera segundo seguinte | **PASS** |
| W. Transação atrasada | OnTradeTransaction só marca dirty; reconciliação por estado do servidor, não por evento | **PASS** |
| X. Restart durante mutação | InitializePendingLifecycleV1231 reconstrói do servidor; replacement não persistido → gerenciador converge; sem recriação antes da reconciliação inicial | **PASS** |
| Y. Gerenciador tenta recriar após liberação | pós-release o create refaz TODA a validação; com autoexclusão, condição de cancel ⇒ create nega | **PASS** |
| Z. Preço oscila entre stop e limit | tipo muda só com regime/bias confirmados por candle fechado (DetectRegimeConfirmadoV121 usa candles fechados + persistência); replacement transacional serializa; sem alternância por tick | **PASS** |

---

## 10. AUDITORIA DO DIFF (V1232_TO_V1233_PENDING_LIFECYCLE.diff)

535 linhas adicionadas / 36 removidas (arquivo: 6.939 → 7.438 linhas). As 36 remoções: 2 do cabeçalho de versão, 7 protótipos/assinaturas estendidos, 27 call sites recebendo o motivo estrutural. **Nenhuma linha de sinal, entrada legítima, saída, lote, risco, DD, basket, trailing, breakeven, ATR, Price Action, Volume Flow, score, Recovery, Momentum, filtro, input ou valor padrão foi alterada** (verificação automática: inputs idênticos byte a byte; corpos de 53 funções sensíveis comparados idênticos — incluindo OnTick, ScoreEntryCandidateV121, ExecuteEntryCandidateV121, SendMarketOrderV122, ManageBasketClosing, ManageDailyRisk*, UpdateDirectionalBiasV122, HasDirectionalSlotRoom, RequestPendingCreate/ModifyV1231, ReconcilePending*, ProcessMarketEntryHandoffV1232; os únicos corpos alterados fora do lifecycle são call sites de CancelAll em OnInit/ManageFlatPairReopen/CloseAllBasket/ManageBasketDrawdown/ManageDailyRisk).

Resultado: **NENHUMA ALTERAÇÃO FUNCIONAL FORA DO LIFECYCLE DE PENDENTES, HANDOFF, REPLACEMENT E REBALANCE TRANSACIONAL.**

Validação estática: chaves 705/705, parênteses 4.074/4.074, colchetes 108/108; 212 definições únicas (0 duplicatas); 0 TODO/FIXME/Sleep/placeholder; 0 chamadas com assinatura antiga; todos os 12 valores do enum referenciados; nenhum input alterado.

---

## 11. FASE 6 — COMPILAÇÃO

**COMPILAÇÃO NÃO EXECUTADA.** O ambiente desta auditoria é um contêiner Linux sem MetaEditor/MetaTrader 5 e sem Wine. Nenhum log de compilação é declarado. A validação sintática foi apenas estática (seção 10). Recomenda-se compilar no MetaEditor (build ≥ 5836) — exigência: 0 errors / 0 warnings.

## 12. FASE 7 — BACKTEST

**BACKTEST NÃO EXECUTADO** (sem Strategy Tester no ambiente). Especificação obrigatória para o teste de validação: XAUUSD, M15, 2026.07.01–2026.07.03, ticks reais, depósito US$ 97.000, lote 0.01, parâmetros padrão, FTMO-Demo, conta hedge.

### Critérios de aprovação a conferir no novo HTML
- Cancels totais ≤ ~308 (99% de redução vs 30.783 históricos) e taxa de cancelamento ≪ 99%.
- Sumário `[V1233_PENDING_LIFECYCLE_SUMMARY]`: `creates_total = executions + expirations + cancels_total + pendentes_ativas`; cancels por motivo somando `cancels_total`; `replace_requests = completed + released + timeouts + ativos`; handoff idem (V1232 summary).
- Cadeias CREATE→CANCEL→CREATE ausentes; pendentes BUY/SELL criadas E executadas; entradas a mercado BUY/SELL, Rebalance, presença bilateral e teto de 8 exposições preservados; reposição normal via Modify; cancelamentos ≤1 s deixando de ser maioria.

## 13. CAMINHOS RESIDUAIS CONHECIDOS (declarados)

1. Handoff/replacement podem, legitimamente, cancelar e depois falhar por mudança REAL de mercado entre dois ticks (spread/margem/retcode). O fluxo agora é autolimitado: a próxima tentativa revalida TUDO antes de novo cancel — sem cadeia possível com estado estável; custo residual: cancelamentos individuais justificados e logados por motivo.
2. Estado de replacement não sobrevive a restart (memória): após reinício, o gerenciador reconstrói do servidor e recoloca a pendente pelo caminho normal validado — sem loop, com possível 1 cancel/1 create adicionais de convergência.
3. Confirmações continuam baseadas em polling do estado do servidor (OrdersTotal) e não em TRADE_TRANSACTION_ORDER_* individualizados — comportamento herdado da V1.2.3.1/2, adequado ao tester e conservador em conta real (timeout 10 s).

## 14. VEREDITO

**CORREÇÃO ESTÁTICA APLICADA, MAS AINDA NÃO COMPROVADA 100% EM EXECUÇÃO** — causa raiz comprovada por função/linha/condição e pelos dados do HTML; patch mínimo aplicado e diff auditado; compilação e backtest reais pendentes de ambiente com MetaTrader 5.
