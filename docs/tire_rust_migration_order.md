# Tire System → Rust Migration Order (Godot 4.x)

Este plano define uma **ordem incremental** para mover partes pesadas de cálculo para Rust sem perder a filosofia atual do projeto:

- contato distribuído
- física emergente
- separação entre percepção de contato e dinâmica
- scripts explícitos e modulares

## 1) O que fica em GDScript (por enquanto)

Mantemos em GDScript os módulos de **orquestração e integração de cena**:

- `tires/TireRuntimeCoordinator.gd`
- `tires/TireContactRuntime.gd`
- `suspension/TireSuspensionBridge.gd`
- `wheels/Wheel.gd`

Motivo: estes pontos dependem de `Node`, sinais, árvore de cena e de APIs de alto nível do Godot.

## 2) Primeiros candidatos para Rust (baixo risco)

Mover primeiro funções puras e determinísticas:

1. normalização de pesos (conservação de carga)
2. agregação numérica de patch (`slip`, `penetração`, normal média)
3. cálculo de raio efetivo (limites de deformação)

Esses cálculos não precisam acessar cena e têm I/O pequeno, então são bons para FFI.

## 3) Segunda etapa (médio risco)

Depois de validar etapa 1, portar:

1. núcleo do `BrushModelSolver`
2. estimativa de força longitudinal/lateral sob limite `mu * Fz`
3. utilitários de redução temporal (`TemporalHistory`) quando forem hotspot

## 4) Etapa avançada (alto risco)

Somente após estabilidade:

1. pipeline de batch para múltiplas rodas por frame
2. preparação de dados para compute/GPU
3. possíveis kernels dedicados (se profiling comprovar ganho)

## 5) Regra de integração

Cada função em Rust deve seguir contrato estrito:

- entrada explícita (arrays escalares/vetores)
- saída explícita (struct plana)
- sem estado global
- sem dependência da árvore de cena

Assim garantimos determinismo, multiplayer e replay.

## 6) Critério para decidir o que portar

Portar para Rust apenas quando:

- for hotspot medido no profiler
- for cálculo puro
- houver teste de regressão comparando Rust x GDScript

Se não cumprir os três critérios, permanece em GDScript.

## 7) Regra de paridade GDScript ↔ Rust

Foi criado um módulo de referência em GDScript (`tires/TireCoreReference.gd`)
com as mesmas operações-base do crate Rust (`normalize_weights`, `aggregate_patch`,
`compute_effective_radius`).

Objetivo:

- prototipar rápido em GDScript
- validar runtime com ajustes de fallback por convenção
- manter assinatura lógica equivalente para troca futura sem quebra

Todos os fallbacks numéricos devem ser centralizados em `conventions` para que
ajustes em runtime sejam fáceis e reproduzíveis entre as duas linguagens.


## 8) Acceptance Criteria (review/merge gate)

- TireSample único: shader e raycast retornam `Array[TireSample]` do mesmo `class_name`.
- ContactPatchData único como agregado do patch atual.
- TireRuntimeCoordinator único entrypoint operacional (`step_runtime_pipeline`).
- Projeto abre sem erro de script e roda ao menos 1 veículo no runtime novo.
- `cargo test` em `rust/tire_core` passa.


## 9) Referência operacional

A referência de arquitetura em 3 camadas, pipeline por tick e contratos está em `docs/tire_runtime_architecture.md`.
