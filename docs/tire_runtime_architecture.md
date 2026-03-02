# Tire Runtime Architecture Contract (3 camadas)

## 1) Arquitetura em blocos (macro)

### SCENE LAYER (GDScript)
- `wheels/Wheel.gd`
- `wheels/WheelAssemblySystem.gd`
- `tires/TireManager.gd` (node fino por veículo)

Responsabilidade:
- coletar estado de cena
- disparar o runtime oficial
- aplicar integração com body/telemetria

### RUNTIME ORCHESTRATION (GDScript)
- `tires/runtime/TireRuntimeCoordinator.gd` (**autoridade única**)
- serviços:
  - `tires/readers/*`
  - `tires/aggregation/*`
  - `tires/surface/*`
  - `tires/bridge/*`
  - `tires/pressurefieldsolver.gd`

Responsabilidade:
- scheduling (tick fixo + frame)
- fallback/guard rails
- ordem determinística do pipeline

### PURE CORE (Rust ou GDScript)
- Rust: `rust/tire_core/src/lib.rs`
- GDScript parity: `tires/TireCoreReference.gd`, `tires/core/TireCore.gd`

Responsabilidade:
- matemática pura
- convenções determinísticas
- zero dependência da scene tree

---

## 2) Pipeline por tick (ordem determinística)

`TICK(dt_fixed)`:

1. **WheelState gather** (sem força)
2. **Contact acquisition** (buffer pronto; fallback em `last_good`)
3. **ContactPatch aggregation** (`normalize_weights`, CoP, normal média, slip)
4. **Normal/Pressure solve** (`Fz`)
5. **Surface response** (`Fx/Fy/Mz` alvo)
6. **Transient/memory** (relaxation/histerese/clamp)
7. **Bridge + apply** (força no body)

No código atual, o entrypoint canônico é `step_runtime_pipeline(...)` no coordinator.

---

## 3) Contratos de dados + regras

### TireSample (sensor)
Arquivo: `tires/data/tiresample.gd`

Pode:
- posição/normal
- penetração/slip/confiança
- ids/timestamp/fonte

Não pode:
- carregar forças finais (`Fx/Fy/Fz/Mz`)

### ContactPatchData (agregado)
Arquivo: `tires/core/ContactPatchData.gd`

Pode:
- CoP local
- normal média local
- pesos normalizados
- slip agregado
- confiança

Não pode:
- acessar `PhysicsServer`/`SpaceState`
- ser responsável por aplicar força

### TireForces (saída)
Arquivo: `tires/core/TireForces.gd`

Pode:
- transportar `Fx/Fy/Fz/Mz`
- ponto de aplicação + confidence + debug

Não pode:
- conter lógica de solver

### WheelState (estado da roda)
Arquivo: `tires/data/WheelState.gd`

Pode:
- descrever estado instantâneo (pose/vel/omega/inputs)

Não pode:
- calcular força

---

## Guard rails mínimos (obrigatórios)

1. Non-blocking sensor + `last_good_patch`
2. Energy clamp por tick
3. Sanity raycast com confiança baixa
4. Slew limits para normal/CoP

---

## Single Authority Rule

**Regra oficial:** `TireRuntimeCoordinator` é o único lugar autorizado a executar pipeline de pneu e aplicar forças.

Se outro módulo decidir fallback/força fora do coordinator, é regressão arquitetural.
