# Core Buffer Layout v0 (Godot ↔ Rust)

Este documento define um **layout v0** (simples e estável) para empacotar dados do veículo/rodas em buffers contíguos.
O objetivo é minimizar overhead de ponte (FFI), manter consistência temporal (tick_id) e permitir batch de 4 rodas.

> Filosofia: Godot envia **raw mínimo** (sem dicionários/Variants). Rust faz normalização e cálculos pesados.
> Rust devolve **apenas saída compacta** (forças/torques/CoP/confidence).

---

## 0) Convenções gerais

- **Endianness:** Little-endian.
- **Floating point:** `f32` em toda a ponte.
- **Espaço de referência:** sempre que possível, dados em **local da roda** (wheel-local).
  - Godot é responsável por transformar para world e aplicar no `RigidBody3D`.
- **Batch:** 1 chamada por veículo por tick contendo **4 rodas** (mesmo que algumas não existam → `present=0`).

---

## 1) Estrutura do pacote (bytes)

O pacote é um `PackedByteArray` (ou bytes) com:

1. Header fixo (tamanho fixo)
2. Wheel headers (4x, tamanho fixo)
3. Blocos de samples (tamanho variável, conforme contagem informada no wheel header)

### 1.1 Header (fixo)

| Campo | Tipo | Descrição |
|------|------|-----------|
| `magic` | u32 | `0x54495245` ("TIRE") |
| `version` | u16 | `0` (v0) |
| `flags` | u16 | reservado |
| `tick_id` | u32 | id do tick fixo |
| `dt_fixed` | f32 | dt do tick |
| `wheel_count` | u32 | sempre 4 no v0 |
| `reserved0` | u32 | 0 |

Tamanho: **24 bytes**

---

## 2) WheelHeader (fixo, repetido 4x)

Cada roda i=0..3 possui um header fixo:

| Campo | Tipo | Descrição |
|------|------|-----------|
| `present` | u32 | 1 se a roda existe/ativa, senão 0 |
| `wheel_id` | u32 | índice/ID estável (ex.: 0..3) |
| `omega` | f32 | velocidade angular (rad/s) |
| `steer_angle` | f32 | ângulo de esterço (rad) *(0 se não aplica)* |
| `wheel_vel_x` | f32 | velocidade local x (m/s) *(lateral)* |
| `wheel_vel_z` | f32 | velocidade local z (m/s) *(longitudinal)* |
| `tire_radius` | f32 | raio nominal (m) |
| `rim_radius` | f32 | raio do aro (m) |
| `n_shader` | u32 | nº de samples do shader |
| `n_raycast` | u32 | nº de samples de raycast |
| `last_good_age` | f32 | opcional: idade do last_good (s), senão 0 |
| `reserved1` | u32 | 0 |

Tamanho: **48 bytes** por roda → **192 bytes** para 4 rodas.

> Observação: `wheel_vel_*` pode ser aproximado (ex.: derivado do chassis + angular) contanto que seja coerente entre ticks.

---

## 3) SampleRaw v0 (fixo, repetido n_shader + n_raycast)

Samples vêm em sequência logo após os 4 wheel headers.
Ordem dos samples:
- primeiro todos os shader samples da roda 0, depois raycast samples da roda 0
- roda 1, roda 2, roda 3 (sempre nessa ordem)

### 3.1 SampleRaw fields (wheel-local)

| Campo | Tipo | Descrição |
|------|------|-----------|
| `pos_x` | f32 | posição local x (m) |
| `pos_y` | f32 | posição local y (m) |
| `pos_z` | f32 | posição local z (m) |
| `nrm_x` | f32 | normal local x |
| `nrm_y` | f32 | normal local y |
| `nrm_z` | f32 | normal local z |
| `penetration` | f32 | penetração (m) |
| `confidence` | f32 | [0..1] |
| `slip_x` | f32 | slip no plano tangente (m/s) ou adimensional (definir em conventions) |
| `slip_y` | f32 | idem |
| `source_type` | u32 | 0=shader, 1=raycast |
| `debug_id` | u32 | opcional (grid index / ray index), senão 0 |

Tamanho: **44 bytes** por sample.

> Se você quiser reduzir tamanho: pode remover normal e/ou debug (criando v0.1).
> Mas o v0 acima é “completo” para torque/CoP e sanity checks.

---

## 4) Saída do core (bytes)

O core retorna um buffer fixo por veículo por tick.
Formato: Header + 4 * WheelOutput

### 4.1 OutputHeader

| Campo | Tipo | Descrição |
|------|------|-----------|
| `magic` | u32 | `0x544F5554` ("TOUT") |
| `version` | u16 | 0 |
| `flags` | u16 | reservado |
| `tick_id` | u32 | eco do tick |
| `wheel_count` | u32 | 4 |
| `reserved0` | u32 | 0 |

Tamanho: **20 bytes**

### 4.2 WheelOutput (4x)

| Campo | Tipo | Descrição |
|------|------|-----------|
| `present` | u32 | 1/0 |
| `wheel_id` | u32 | eco do wheel_id |
| `Fx` | f32 | força local x |
| `Fy` | f32 | força local y |
| `Fz` | f32 | força local z |
| `Mx` | f32 | torque local x |
| `My` | f32 | torque local y |
| `Mz` | f32 | torque local z |
| `cop_x` | f32 | CoP local x |
| `cop_y` | f32 | CoP local y |
| `cop_z` | f32 | CoP local z |
| `confidence` | f32 | [0..1] |
| `contact_area` | f32 | opcional |
| `flags` | u32 | bits de debug (energy_clamped, fallback_last_good, etc.) |

Tamanho: **56 bytes** por roda → **224 bytes** para 4 rodas.

> Nota: se você só usar Mz, pode reduzir Mx/My e economizar 8 bytes por roda.

---

## 5) Flags recomendadas (WheelOutput.flags)

Bits sugeridos:
- bit 0: `FALLBACK_LAST_GOOD`
- bit 1: `ENERGY_CLAMPED`
- bit 2: `SLEW_CLAMPED`
- bit 3: `NO_CONTACT_EMERGENCY`
- bit 4: `NAN_SANITIZED`
- bits 16..31: reservados

---

## 6) Invariantes obrigatórias (core)

Antes de escrever o output, o core deve garantir:
- `confidence ∈ [0,1]`
- `Fx,Fy,Fz,Mx,My,Mz` finitos (sem NaN/Inf)
- `Fz >= 0` (ou, se permitir negativa por algum motivo, documentar explicitamente)
- CoP finito
- se invalidar output: retornar `confidence=0` e `flags` marcando fallback

---

## 7) Determinismo prático

- A ordem de consumo de samples é **fixa** (por roda, shader depois raycast).
- O core não deve depender de hashmaps/dicts; apenas arrays.
- Qualquer threshold deve usar conventions versionadas.

---

## 8) Evolução do layout (compatibilidade)

- `version` no header permite mudanças futuras.
- Mudanças que quebram compatibilidade devem:
  - incrementar `version`
  - manter parser v0 por um tempo (ou ter conversor)

---

## 9) Mapping com o projeto atual (Godot)

- `TireSample` atual já possui: pos_local/normal_local/penetration/confidence/slip_vector/source.
- Readers (`ShaderContactReader`, `RaycastSampleReader`) devem alimentar o empacotador.
- `TireRuntimeCoordinator` continua a ser o maestro e a aplicar forças.
