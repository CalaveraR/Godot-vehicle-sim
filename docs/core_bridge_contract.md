# Core Bridge Contract (Godot ↔ Rust)

Este documento define o **contrato oficial** de troca de dados entre:
- **Godot (GDScript)**: coleta dados brutos da engine, orquestra ticks e aplica forças.
- **Rust (core)**: normaliza/filtra, executa o kernel pesado e retorna saída compacta.

Objetivo: **performance + determinismo prático + robustez em edge cases**.

---

## 1) Princípios

### 1.1 Single Authority
A aplicação de forças no corpo e a ordem do pipeline continuam sob **autoridade única** do runtime em Godot (ex.: `TireRuntimeCoordinator`).

Rust **nunca** acessa scene tree, `PhysicsServer`, `SpaceState`, nem aplica forças diretamente.

### 1.2 Dados brutos entram, dados normalizados existem só no core
- Godot envia **dados brutos** (contato, inputs, estados).
- Rust converte/normaliza internamente (pesos, confiança, thresholds, clamps).
- Rust retorna **apenas o necessário para a engine**: forças/torques/ponto de aplicação/confiança.

### 1.3 “1 chamada grande” > “muitas chamadas pequenas”
A ponte deve minimizar overhead de FFI.
- Preferir **batch por veículo** (ex.: 4 rodas) por tick.
- Evitar `Dictionary`/`Variant` no hot path.
- Preferir buffers contíguos: `PackedFloat32Array` / `PackedByteArray`.

---

## 2) Unidade de tempo e consistência (tick_id)

### 2.1 Tick fixo
O runtime trabalha em tick fixo (ex.: 120Hz). O `dt` do core é o `dt_fixed`.

### 2.2 Pacote consistente por tick
Cada pacote de entrada deve representar um estado coerente:

- `WheelState[tick_id]`
- `ContactSamples[tick_id]`

É proibido misturar `WheelState` de um tick com samples de outro tick.

### 2.3 Fallback quando dados não chegam
Se o pacote não estiver completo:
- usar `last_good` com `confidence` reduzida **ou**
- usar reader de fallback (raycast) com confiança baixa

Nunca produzir “snap” (troca brusca para zero) sem transiente/clamp.

---

## 3) Entrada do core (raw)

### 3.1 WheelState (mínimo)
Por roda, enviar apenas o que o kernel usa. Exemplo (f32):

- `omega` (rad/s)
- `steer_angle` (rad) ou orientação relevante em local
- `wheel_velocity_local_xz` (m/s) ou equivalente
- `tire_radius` / `rim_radius` (m) se necessário

> Observação: se o core não usa algum campo, ele não deve existir na ponte.

### 3.2 ContactSampleRaw (por amostra)
Formato mínimo recomendado (tudo `f32`):

- `penetration`
- `confidence`
- `slip_x`, `slip_y`
- `pos_local: (x,y,z)` (se o solver precisar de CoP/torque local)
- `normal_local: (x,y,z)` (se o solver usar normal)

Campos opcionais (debug):
- `source_type` (shader/raycast)
- `grid_index` ou `(gx,gy)`

---

## 4) Saída do core (packed)

Por roda, retornar (f32):

- `force_local: Vector3`  (Fx,Fy,Fz)
- `torque_local: Vector3` (Mx,My,Mz) *(ou apenas Mz se simplificar)*
- `center_of_pressure_local: Vector3`
- `confidence: f32`
- `contact_area: f32` (opcional)
- `flags: u32` (opcional; pode ser buffer separado)

A aplicação final e transformações para world ficam em Godot.

---

## 5) Normalização e invariantes (dentro do core)

Rust é responsável por garantir invariantes antes de retornar saída:

- `confidence ∈ [0,1]`
- pesos normalizados somam `≈ 1` (quando há contato)
- `Fz ≥ 0` (sem tração “puxando o chão”)
- clamps por tick (energia, slew limits) quando aplicável
- valores finitos (sem NaN/Inf)

Se alguma invariant falhar, o core deve:
- degradar para fallback conhecido (last_good)
- marcar flags de debug

---

## 6) Modos de backend (para validação)

O runtime deve suportar modos:

- `GDSCRIPT_ONLY`
- `RUST_ONLY`
- `SHADOW_COMPARE` (Godot aplica; Rust calcula e compara/loga)

`SHADOW_COMPARE` é o modo oficial para validar paridade sem alterar comportamento.

---

## 7) Error budget (macro vs micro)

- Erro macro aceitável (outputs agregados, “feeling”): ~5%
- Intermediários críticos (contato, CoP, Fz, thresholds): devem ser estáveis e evitar flip de regime.

---

## 8) Versionamento de conventions
Parâmetros numéricos e thresholds devem ser centralizados e versionados (“calibração de simulação”).

Mudanças de conventions devem:
- atualizar versão
- manter compatibilidade de leitura
- permitir reproduzir replays/testes

---

## 9) Testes (golden snapshots)
O core Rust deve ter testes que rodam fora do Godot:

- snapshots de entrada (raw) gravados em arquivo
- saída esperada (ou tolerâncias)
- validação de invariantes e de regressão
