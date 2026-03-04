# Plano de prioridade de melhorias (foco prático)

## Pergunta guia

Com base no nível atual dos módulos (pneus N4, suspensão N4-, rodas N3+, motor N3), **qual atacar primeiro** para maximizar estabilidade e ganho real sem fugir da filosofia atual?

## Ordem recomendada (primeiro → depois)

1. **Suspensão (primeiro)**
2. **Pneus (segundo)**
3. **Rodas (terceiro)**
4. **Motor (quarto)**

---

## 1) Suspensão primeiro (maior ROI imediato)

### Por que começar aqui

- Já existe separação clara Godot (orquestração) vs Rust (núcleo numérico).
- Já existe backend mode e shadow mode no `SuspensionSystem`.
- O gargalo principal está bem definido: o backend Rust ainda está em stub.

**Impacto esperado:** fechar a ponte Rust real aqui reduz risco sistêmico para pneus/rodas porque a suspensão alimenta estados críticos (raio efetivo, deformação, relaxação).

### Como otimizar respeitando a filosofia atual

- **Godot continua autoridade única** para Node/Scene/Raycast/aplicação final.
- **Rust fica com matemática pura** (kernels já existentes), sem estado global.
- Shadow compare como gate antes de liberar `RUST` em produção.

### Sprint curto (ações)

1. Implementar bridge Rust real para `compute_deformation_clamped` e `compute_effective_radius`.
2. Ligar `CoreBackendMode.RUST` com fallback automático para GDScript em erro de contrato.
3. Persistir snapshots de entrada/saída por tick e comparar tolerância.
4. Definir invariantes de suspensão (sem NaN/Inf, bounds de raio/deformação).

---

## 2) Pneus em seguida (governança + robustez)

### Por que é o segundo

- Já é o módulo mais avançado em arquitetura (pipeline, single authority, backend mode).
- O principal problema agora é **governança de ownership Godot↔Godot** (aliases/wrappers legados), não falta de modelo físico.

### Como otimizar sem quebrar compatibilidade

- Manter wrappers legados apenas como **alias transitório**.
- Definir canônico por pasta (`runtime`, `readers`, `aggregation`, `data`, `surface`).
- Reforçar contratos por estágio (read → aggregate → apply) e validações em runtime.

### Sprint curto (ações)

1. Marcar wrappers legados com política `LEGACY_ALIAS` e prazo de remoção.
2. Adicionar verificação CI para impedir novos wrappers não documentados.
3. Fechar checklist de ownership (quem escreve quais propriedades de contato/força/estado).
4. Expandir shadow compare para deltas por estágio (força, torque, confidence, CoP).

---

## 3) Rodas depois (hub de integração)

### Por que terceiro

- Já existe kernel Rust de dinâmica da roda.
- Precisa evoluir integração e contratos com pneus/suspensão para evitar drift temporal.

### Como otimizar

- Godot segue como integrador e aplicação final.
- Rust calcula `omega/slip/transientes` com clamps e invariantes.
- Tick_id e snapshot sincronizados com pipeline de pneus/suspensão.

### Sprint curto (ações)

1. Formalizar contrato `WheelDynamicsInput/State` para todo caminho Godot→Rust.
2. Adicionar backend mode + shadow compare explícito para roda (se não estiver completo).
3. Criar teste de regressão de edge cases (contato intermitente, frenagem brusca, low-speed).
4. Integrar telemetria mínima para detectar flip-flop de slip/ABS/TCS.

---

## 4) Motor por último (sem perder valor)

### Por que quarto

- Motor já é funcional e modular, mas sem pipeline híbrido padronizado no mesmo nível dos demais.
- Ganha mais valor após suspensão/pneus/rodas estarem mais estáveis e com contratos fechados.

### Como otimizar

- Preservar Godot para orquestração e integração com sistemas do veículo.
- Migrar apenas núcleos puros/hotspots para Rust por profiling.
- Evitar portar por volume; portar por impacto + determinismo + testabilidade.

### Sprint curto (ações)

1. Definir um `EngineCoreBackendMode` padronizado (GDSCRIPT/RUST/SHADOW).
2. Escolher 2–3 cálculos puros com maior custo para pilotar (ex.: combustão/indução/turbo acoplado).
3. Implementar shadow compare com tolerâncias e logs por regime (baixa/alta rotação).
4. Criar vetores de teste “golden” por mapa de torque/consumo/temperatura.

---

## Estratégia transversal (todos os módulos)

1. **Single authority em Godot** para I/O de cena e aplicação física.
2. **Rust para núcleo puro** (determinístico, sem scene tree).
3. **Shadow compare obrigatório** antes de promover backend Rust.
4. **Contracts explícitos e versionados** (JSON + structs flat).
5. **Invariantes e clamps primeiro**, complexidade física depois.
6. **Portar por profiler**, não por “quantidade de scripts”.

---

## Resultado prático esperado em 2 ciclos

- Ciclo 1: suspensão com bridge real + pneus com ownership limpo.
- Ciclo 2: rodas com integração robusta + motor com piloto de backend híbrido.

Essa ordem mantém a filosofia atual (Godot como autoridade e Rust como núcleo lógico), reduz risco de regressão e aproveita melhor cada tecnologia onde ela é mais forte.
