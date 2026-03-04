# Backlog técnico fechado (execução por sprint)

## Objetivo

Converter o plano de prioridade em backlog executável, com:

- tarefas claras
- critérios de aceite objetivos
- risco por tarefa
- dependências mínimas

Ordem de execução mantida:
1. Suspensão
2. Pneus
3. Rodas
4. Motor

---

## Sprint 1 — Suspensão (ponte Rust real + segurança de contrato)

### S1-T1 — Bridge Rust real para núcleo base de suspensão
**Escopo**
- Conectar `SuspensionSystem` ao backend Rust para:
  - `compute_deformation_clamped`
  - `compute_effective_radius`

**Critérios de aceite**
- `CoreBackendMode.RUST` executa as duas rotinas via bridge real (não stub).
- Fallback para GDScript em erro de bridge sem crash de runtime.
- Saídas finitas (sem NaN/Inf) em 100% dos ticks de teste.

**Risco**: Alto (integração bridge/runtime).
**Dependências**: contratos de input/output estáveis.

### S1-T2 — Shadow compare formal (suspensão)
**Escopo**
- Expandir/validar SHADOW para logar deltas de:
  - deformação
  - raio efetivo
  - relaxação
  - deformação lateral

**Critérios de aceite**
- Log de delta por tick com threshold configurável.
- Alerta apenas quando exceder tolerância.
- Relatório agregado de divergência por sessão.

**Risco**: Médio.
**Dependências**: S1-T1.

### S1-T3 — Snapshot + regressão mínima
**Escopo**
- Persistir snapshots I/O do core de suspensão.
- Criar validação de regressão numérica.

**Critérios de aceite**
- Suite reproduz pelo menos 3 cenários: carga baixa/média/alta.
- Comparação Rust vs GDScript com tolerância definida.
- Falha explícita quando ultrapassar tolerância.

**Risco**: Médio.
**Dependências**: S1-T1.

---

## Sprint 2 — Pneus (ownership Godot↔Godot + robustez operacional)

### S2-T1 — Política de wrappers `LEGACY_ALIAS`
**Escopo**
- Marcar wrappers legados em `tires/godot/` com política padrão e prazo de remoção.
- Definir caminho canônico por pasta (`runtime/`, `readers/`, `aggregation/`, `data/`, `surface/`).

**Critérios de aceite**
- Todos os wrappers atuais identificados e anotados.
- Documento de convenção canônica aprovado no repositório.
- Nenhum novo wrapper fora da política.

**Risco**: Baixo.
**Dependências**: nenhuma.

### S2-T2 — CI de governança para duplicação Godot↔Godot
**Escopo**
- Adicionar check simples para bloquear novos wrappers não documentados.

**Critérios de aceite**
- Pipeline falha quando detectar wrapper novo sem anotação/política.
- Pipeline passa para estado atual documentado.

**Risco**: Baixo.
**Dependências**: S2-T1.

### S2-T3 — Checklist de ownership por propriedade crítica
**Escopo**
- Definir owner único para escrita de propriedades críticas de contato/força/estado.

**Critérios de aceite**
- Matriz “propriedade → owner script” publicada.
- Zero conflito conhecido entre scripts Godot para mesma propriedade crítica.

**Risco**: Médio.
**Dependências**: S2-T1.

### S2-T4 — Shadow compare por estágio do pipeline de pneus
**Escopo**
- Telemetria por estágio: `read -> aggregate -> apply`.

**Critérios de aceite**
- Deltas de força/torque/confidence/CoP por estágio.
- Threshold por estágio configurável.
- Evidência de execução em pelo menos 2 cenários (contato estável/intermitente).

**Risco**: Médio.
**Dependências**: S2-T3.

---

## Sprint 3 — Rodas (integração robusta com pneus/suspensão)

### S3-T1 — Contrato único WheelCore I/O
**Escopo**
- Consolidar contrato `WheelDynamicsInput/State` no caminho Godot→Rust.

**Critérios de aceite**
- Contrato versionado e usado por todos os chamadores principais.
- Campos obrigatórios de tempo/tick e estados transitórios definidos.

**Risco**: Médio.
**Dependências**: estabilização S1/S2.

### S3-T2 — Backend mode + shadow compare explícito para roda
**Escopo**
- Padronizar modos `GDSCRIPT/RUST/SHADOW` no fluxo de roda.

**Critérios de aceite**
- Troca de backend por configuração sem alterar API externa.
- Shadow loga divergência de `omega`, `slip_ratio`, `slip_angle`.

**Risco**: Médio.
**Dependências**: S3-T1.

### S3-T3 — Regressão de edge cases
**Escopo**
- Casos de contato intermitente, frenagem brusca e baixa velocidade.

**Critérios de aceite**
- Sem NaN/Inf.
- Estados bounded.
- Sem flip-flop excessivo acima do limite definido.

**Risco**: Médio/Alto.
**Dependências**: S3-T2.

---

## Sprint 4 — Motor (padronização híbrida orientada a hotspot)

### S4-T1 — Definir `EngineCoreBackendMode`
**Escopo**
- Introduzir padrão `GDSCRIPT/RUST/SHADOW` para núcleo selecionado do motor.

**Critérios de aceite**
- Modo configurável em runtime.
- Rota SHADOW ativa sem alterar comportamento aplicado.

**Risco**: Médio.
**Dependências**: nenhuma dura (recomendado após S1-S3).

### S4-T2 — Piloto com 2–3 cálculos puros de alto impacto
**Escopo**
- Portar somente hotspots comprovados por profiling.

**Critérios de aceite**
- Ganho mensurável no hotspot alvo ou redução de variância.
- Paridade numérica dentro da tolerância definida.

**Risco**: Alto.
**Dependências**: S4-T1.

### S4-T3 — Golden vectors do motor
**Escopo**
- Vetores de referência por regime de rotação/carga.

**Critérios de aceite**
- Casos cobrindo baixa, média e alta rotação.
- Regressão automatizada com falha em drift acima da tolerância.

**Risco**: Médio.
**Dependências**: S4-T2.

---

## Regras de qualidade (gate global)

1. Sem NaN/Inf em outputs físicos.
2. Bounds explícitos para variáveis críticas (`Fz`, `omega`, slip, raio efetivo).
3. Shadow compare obrigatório antes de promover backend Rust.
4. Snapshot/golden para qualquer núcleo portado.
5. Godot permanece autoridade de integração e aplicação em cena.

---

## Definição de pronto (DoD) por tarefa

Uma tarefa só fecha quando tiver:

- implementação concluída
- critério de aceite validado
- evidência de teste/log anexável
- risco residual registrado (baixo/médio/alto)

