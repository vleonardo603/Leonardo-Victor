# V1.2.3.3 — RESUMO DOS CONTADORES E COMPARAÇÃO

## 1. Contadores implementados no EA (novos ou preexistentes preservados)

| Contador | Variável | Onde incrementa |
|---|---|---|
| creates BUY/SELL | `g_pendingCreatesBuyV1231` / `g_pendingCreatesSellV1231` | RequestPendingCreateV1231 |
| modifies BUY/SELL | `g_pendingModifiesBuyV1231` / `g_pendingModifiesSellV1231` | RequestPendingModifyV1231 |
| cancels BUY/SELL | `g_pendingCancelsBuyV1231` / `g_pendingCancelsSellV1231` | RequestPendingCancelV1231 |
| executions | `g_pendingExecutionsV1231` | ReconcilePendingSideV1231 (ACTIVE→ausente) |
| cancels por motivo (12) | `g_pendingCancelsByReasonV1233[]` | RequestPendingCancelV1231 |
| recriações bloqueadas | `g_pendingRecreateBlockedV1233` | PlaceDynamic*Pending (replacement-gate) |
| mutações bloqueadas | `g_pendingBusyBlocksV1231` | PendingActionGuardV1231 |
| trocas reprovadas na simulação | `g_pendingSwapSimBlockedV1233` | FreePendingSlot / FreeSlotForPriorityRebalance |
| handoff requests/executed/released/timeouts | `g_marketHandoffRequestsV1232` etc. | fluxo V1232 (preservado) |
| replacement requests/executed/released/timeouts | `g_pendingReplaceRequestsV1233` etc. | Reposition + ProcessPendingReplacementV1233 |
| rebalance | `g_lastBuy/SellRebalanceTime`, confirmações V122 | fluxo V122 (preservado) |
| id de mutação | `g_pendingMutationSeqV1233` | cada cancel logado |

## 2. Reconciliação matemática (impressa no OnDeinit — [V1233_PENDING_LIFECYCLE_SUMMARY])

```
creates_total  = executions + expirations + cancels_total + pendentes_ativas
cancels_total  = Σ g_pendingCancelsByReasonV1233[motivo]
replace_requests  = replace_completed + replace_released + replace_timeouts + replace_ativos
handoff_requests  = handoff_executed + handoff_released + handoff_timeouts + handoff_ativos
```
(expirations são reconciliadas pela contagem de executions do lifecycle — ordem ausente
sem cancel = executada ou expirada; o relatório do tester distingue os dois estados.)

## 3. HTML antigo (V1.2.3.2, recalculado) vs alvo do novo teste (V1.2.3.3)

| Métrica | V1.2.3.1 (histórico) | V1.2.3.2 (recalculado do HTML) | Alvo V1.2.3.3 |
|---|---|---|---|
| Pendentes criadas | 30.820 | 9.669 | ~dezenas (uma por lado + reposições Modify) |
| Pendentes canceladas | 30.783 (99,88%) | 9.635 (99,65%) | ≤ ~308 (−99% vs 30.783), cada uma com motivo legítimo logado |
| Cancel no mesmo segundo | 82,84% | 0,71% | ~0 fora de fechamentos globais |
| Cancel ≤ 1 s | 97,01% | 89,28% | deixa de ser maioria |
| Mediana de vida da pendente | ~0 s | 1,0 s | minutos (expiração 30 min / execução / invalidação real) |
| Cadeias CREATE→CANCEL→CREATE | massivas | 81 cadeias, 95,7% dos cancels | ausentes |
| Executadas / Expiradas | — | 28 / 6 | preservadas ou maiores (pendentes vivem) |
| Trades / Net / PF / eqDD | 104 / −154,21 / 0,82 / 0,27% | 102 / −104,19 / 0,88 / 0,22% | métricas financeiras NÃO são critério de aprovação do lifecycle |

**BACKTEST NÃO EXECUTADO** neste ambiente (sem MT5) — a coluna "Alvo" define os critérios de aprovação a verificar no novo HTML, conforme seção 12 do relatório de auditoria.
