# Wheel Rust Migration Plan

## Goal
Migrar o núcleo numérico de dinâmica da roda (WheelDynamics) para Rust, mantendo Godot como autoridade única para:
- Scene I/O (Nodes, transforms, leitura de inputs)
- Aplicação final de forças/torques no veículo
- Orquestração do tick fixo e integração com tire/suspension/engine
- Debug visual e efeitos

Rust passa a calcular, de forma determinística e testável:
- integração de ω (velocidade angular) e estados derivados
- slip ratio / slip angle / slip vector (e relaxation/transientes)
- “gating” e clamps (boundedness) do kernel da roda

---

## 1) Escopo do Núcleo Wheel

### 1.1 Fica em Godot (NÃO duplicar)
- `wheels/Wheel.gd` (orquestração por roda e integração com outros sistemas)
- Aplicação no body (ex.: `apply_to_wheel`)
- Leitura de contato/samples (vem do tire runtime / readers)
- Qualquer acesso a Node/SceneTree/PhysicsServer
- Efeitos: vibração visual, áudio local, skidmarks, partículas

### 1.2 Vai para Rust (duplicar recomendado/forte)
- `WheelDynamics.gd` (ou o equivalente que faz o kernel)
- Qualquer cálculo por tick que:
  - dependa de ω e integre ω
  - compute slip / slip vector
  - aplique relaxation/histerese/clamps
  - derive scalars que alimentam o tire core e/ou o chassis

> Wheel é o “hub” entre motor/freio e pneu/contato. Ter o kernel em Rust reduz drift temporal e facilita golden tests.

---

## 2) Wheel Contract (Bridge v0)

### 2.1 Inputs mínimos por roda (por tick)
- `tick_id: u32`
- `dt: f32`

#### Estado atual
- `omega: f32` (rad/s)
- `wheel_radius_effective: f32` (m) (preferir vir da suspensão/tire já resolvido)
- `inertia: f32` (kg·m²) (ou `inv_inertia`)

#### Torques aplicados
- `drive_torque: f32` (Nm) (motor pós drivetrain, já no eixo da roda)
- `brake_torque: f32` (Nm)
- `rolling_resistance_torque: f32` (Nm) (opcional)

#### Velocidade relativa no contato (wheel-local)
- `v_contact_x: f32` (m/s) lateral (no plano)
- `v_contact_z: f32` (m/s) longitudinal (no plano)

#### Resumo do contato (do tire runtime)
- `has_contact: u32` (0/1)
- `contact_confidence: f32` [0..1]
- `normal_load_fz: f32` (N) (se já disponível como agregado)
- `mu_estimate: f32` (opcional) (se existir um “limite de tração” vindo do tire)

#### Parâmetros de transientes (calibration)
- `relaxation_length: f32` (m) ou `relaxation_factor: f32`
- `slip_clamp: f32` (limites)
- `omega_slew_limit: f32` (opcional)

### 2.2 Outputs mínimos por roda (por tick)
- `omega_next: f32`
- `slip_ratio: f32`
- `slip_angle: f32` (rad)
- `slip_vx: f32`, `slip_vz: f32` (m/s) (ou adimensional — documentar convention)
- `net_wheel_torque: f32` (Nm) (pós clamps; útil para debug)
- `flags: u32` (clamped, fallback, no_contact, nan_sanitized, abs_active, etc.)

> Importante: WheelCore não aplica força no chassis. Ele devolve estados e scalars que o pipeline usa para calcular/aplicar forças (via tire core + Godot apply).

---

## 3) Execution Order (Per Tick)

Ordem recomendada dentro do runtime (por roda):

1) Godot coleta:
   - torques (engine/drivetrain + brake + flat-spot factor)
   - resumo de contato (do TireRuntimeCoordinator)
   - raio efetivo (suspensão/tire)
   - v_contact (velocidade no frame da roda)

2) WheelCore backend:
   - `wheel_core.solve(inputs)`:
     - (a) computa slip ratio/angle (com clamps)
     - (b) aplica relaxation/transiente (memória)
     - (c) integra ω (com slew limits)
     - (d) devolve outputs + flags

3) Godot:
   - atualiza `WheelDynamics` state (ou shadow compare)
   - passa slip/omega para:
     - tire system (para forças)
     - efeitos (som)
     - telemetria

Backend modes:
- `GDSCRIPT`
- `RUST`
- `SHADOW_COMPARE` (Godot aplica referência; Rust calcula e loga deltas)

---

## 4) Paridade e “Drift” (o que observar)

Wheel tende a sofrer mais com:
- drift temporal (dados de contato de tick diferente)
- thresholds (ABS/TCS) gerando flip-flop
- integração de ω acumulando erro

Mitigações obrigatórias:
- tick_id consistente (WheelState[t] + ContactSummary[t])
- clamps/histerese em thresholds
- invariantes (sem NaN/Inf, ω bounded)

---

## 5) Calibration / Versioning

Reusar o padrão já adotado em tire_core:
- arquivo JSON versionado (opção: seção `wheel_v1` no `sim_calibration_v1.json`)
- Godot carrega e **cacheia** (sem I/O no hot path)
- Rust carrega o mesmo arquivo em testes

---

## 6) Testing

### 6.1 Golden snapshots
- Godot grava entradas/saídas por tick em um “CoreSnapshot” de wheel
- Rust `cargo test` valida solve() dentro de tolerância

### 6.2 Invariants
- ω finito e bounded
- slip finito e bounded
- flags coerentes em no_contact
- sem regressão em edge cases (ex.: contato intermitente)

### 6.3 Shadow compare (gate de migração)
Trocar para `RUST_ONLY` somente quando:
- SHADOW_COMPARE está dentro de tolerância
- invariantes estão verdes
- comportamento em edge cases permanece bounded

---

## 7) Migration Phases

### Phase 1 (core mínimo)
- ω integrator + slip ratio/angle
- backend modes + snapshot + golden test

### Phase 2 (transientes)
- relaxation length / filtros temporais
- slew limits e clamps

### Phase 3 (controle e edge cases)
- hooks para ABS/TCS (se existirem)
- fallback determinístico em missing contact tick
