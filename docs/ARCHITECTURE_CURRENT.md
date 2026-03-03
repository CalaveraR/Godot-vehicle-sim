# Physics Contract v1

## Escopo

Este contrato define entradas, saídas e regras do pipeline de pneu/suspensão e o limite entre:

- **Godot Layer (GDScript):** leitura de mundo, orquestração, aplicação de forças.
- **Core Layer (Rust ou GDScript-espelho):** matemática pura e determinística.

## Objetivos

- Uma única “autoridade” de execução por roda (Single Authority Rule).
- Mesmas entradas → mesmas saídas (dentro de tolerância numérica).
- Robustez em edge cases: contato parcial, transições de contato, confidence baixa.
- Compatível com multi-rate (sensor em frame rate, física em tick fixo).

## 1) Pipeline oficial (ordem determinística)

Por tick fixo `dt`:

1. Read Samples (Godot)
2. Aggregate Patch (Core)
3. Solve Normal Load (Fz) (Core)
4. Solve Tangential Forces (Fx/Fy/Mz) (Core)
5. Apply Forces (Godot)
6. Update Tire State (wear/temp) (Core ou Godot, mas com `dt` do tick)

**Regra:** nenhum outro módulo pode aplicar forças no corpo fora do estágio 5.

## 2) Single Authority Rule

Para cada roda:

- `TireRuntimeCoordinator` é a única autoridade que executa o pipeline e decide fallback.
- `Wheel` não recalcula física de pneu nem escreve direto na suspensão (exceto dados cinemáticos básicos).
- `TireContactSolver` (se existir) é **LEGACY** e não roda se `Coordinator` estiver presente.

## 3) Tipos canônicos (contratos de dados)

### 3.1 WheelState (input)

Estado da roda no tick (não depende do engine).

Campos mínimos:

- `omega_rad_s: float`
- `steer_rad: float`
- `camber_rad: float`
- `toe_rad: float`
- `radius_nominal_m: float`
- `width_m: float`
- `vel_contact_local_mps: Vector3` (velocidade do ponto de contato no espaço local da roda)
- `up_local: Vector3` (normal “do pneu” no local)
- `forward_local: Vector3`
- `right_local: Vector3`

Observação: transforms e conversões World↔Local são feitas no Godot.

### 3.2 TireSample (input)

Amostra sensorial por célula/raycast.

Campos mínimos:

- `pos_local: Vector3` (posição da célula em espaço local do pneu)
- `normal_local: Vector3` (normal estimada do contato em espaço local do pneu)
- `penetration_m: float` (>= 0)
- `slip_local_mps: Vector2` (slip tangencial no plano do contato)
- `confidence: float` (0..1)
- `material_id: int` (opcional, 0 se desconhecido)
- `timestamp_s: float` (opcional)

**Proibido:** `TireSample` conter forças.

### 3.3 ContactPatch (intermediário)

Resultado agregado do contato (puro).

Campos mínimos:

- `cop_local: Vector3` (center of pressure)
- `avg_normal_local: Vector3` (normal média)
- `contact_area_m2: float` (estimada)
- `max_pressure_pa: float`
- `mean_penetration_m: float`
- `confidence: float`
- `slip_local_mps: Vector2` (agregado)
- `effective_radius_m: float` (opcional: pode ser saída do core)

Pode existir `weights[]` ou debug fields apenas em builds de debug.

### 3.4 TireParams (input – estático/config)

Parâmetros do pneu e curvas.

Campos mínimos:

- `stiffness_n_per_m: float`
- `damping_n_s_per_m: float` (se usado)
- `mu_base: float`
- `load_sensitivity: float` (opcional)
- `relax_len_long_m: float`
- `relax_len_lat_m: float`
- `rolling_resistance: float`
- `curvas` (opcional: temperatura→mu, wear→mu etc.)

Curvas do Godot não entram no core Rust diretamente. Em Rust, você converte curvas em LUT (arrays).

### 3.5 TireState (state – persistente)

Estado interno com memória/histerese.

Campos mínimos:

- `surface_temp_c: float`
- `core_temp_c: float`
- `wear: float` (0..1)
- `relax_slip_long: float` (estado do filtro)
- `relax_slip_lat: float`
- `last_patch: ContactPatch` (para fallback)

### 3.6 TireForces (output)

Saída física aplicada no corpo, em espaço local do pneu.

Campos mínimos:

- `force_local_n: Vector3` (Fx,Fy,Fz)
- `torque_local_nm: Vector3` (inclui Mz, opcional)
- `application_point_local: Vector3`
- `confidence: float`

Godot converte local→world e aplica no `RigidBody3D`.

## 4) Interfaces (funções do core)

### 4.1 Agregação

`aggregate_patch(samples[], wheel_state, params) -> ContactPatch`

Regras:

- normalizar pesos de forma determinística;
- lidar com soma de pesos = 0 (sem contato): `patch confidence = 0`.

### 4.2 Normal load

`solve_normal_load(patch, wheel_state, params, state, dt) -> (Fz, updated_patch/state)`

Regras:

- nunca gerar Fz negativo;
- clamp em valores máximos razoáveis (anti-catapult).

### 4.3 Forças tangenciais

`solve_tangential(patch, wheel_state, params, state, dt) -> TireForces + updated_state`

Regras:

- combined slip (long+lat);
- saturação por `μ * Fz`;
- filtros de relaxação (memória viscoelástica simplificada).

### 4.4 Atualização térmica e desgaste

`update_thermal_wear(state, patch, forces, wheel_state, params, dt) -> updated_state`

Regra:

- usar `dt` do tick fixo, nunca `dt` do frame.

## 5) Fallback e robustez

### 5.1 Sem contato / confidence baixa

Se `patch.confidence < threshold`:

- usar `state.last_patch` com decaimento (leak);
- reduzir `μ` efetivo (evitar grip fantasma);
- opcional: sanity raycast no Godot.

### 5.2 Clamps obrigatórios

- clamp de NaN/Inf (substituir por 0);
- clamp de variação de normal e CoP por tick (slew rate);
- clamp de potência por tick (energy clamp).

## 6) Paridade Rust ↔ GDScript

### Regra de ouro

- Rust é a referência (“golden”).
- GDScript replica para prototipagem e validação.

### Golden vectors

- Rust exporta casos de teste (JSON).
- Godot roda validador e compara outputs com tolerância.

## 7) Integração no Godot (responsabilidades)

Godot faz:

- `samples = reader.read_samples(...)`
- `forces = core.step(...)`
- aplicar `forces` no `RigidBody3D`
- atualizar debug/telemetria

Godot **NÃO** faz:

- recalcular slip/patch em múltiplos lugares;
- aplicar forças fora do coordinator;
- atualizar raio efetivo por fora do bridge.

## 8) Convenções numéricas

- unidades SI (`m`, `s`, `N`, `Pa`, `rad`)
- `eps` padrão: `1e-6`
- normalizações sempre com `eps`
- floats: 32-bit ou 64-bit, mas consistentes (ideal: `f32` no Rust + cuidado)

## Definition of Done do Contract v1

Você considera o Contract v1 implementado quando:

- dá para rodar backend GD ou Rust com o mesmo `WheelState + samples`;
- e obter outputs próximos (tolerância definida);
- sem NaN/Inf em testes de stress;
- sem pipelines paralelos.
