# Regras de Duplicação GD ↔ Rust e Conexão Engine ↔ Core

## 0) Termos

- **Engine-facing:** scripts que tocam Godot (`Node3D`, `RigidBody3D`, `RayCast3D`, `Area3D`, `Resources`, `Signals`).
- **Core logic:** scripts/rotinas determinísticas e puras (`RefCounted` no GD e crate no Rust). Sem acesso a cena, sem chamadas ao engine.

## 1) Regra-mãe: Single Authority

Para cada “sistema físico” (pneu, motor, câmbio, freio):

✅ Existe um único orquestrador por instância que:

- coleta inputs do engine
- chama o core
- aplica outputs no engine

Ex.: pneus → `TireRuntimeCoordinator`  
motor → `EngineRuntimeCoordinator` (futuro)

**Proibido:**

- aplicar força/torque em dois lugares diferentes
- ter dois pipelines ativos (legacy + novo) sem um “gate” explícito

## 2) O que pode ter duplicata (GD + Rust)

Um script pode/deve ter duplicata quando ele atende **TODOS**:

### Critérios (tem que cumprir os 4)

1. Matemática pura: dado input X, output Y, sem acessar scene tree.
2. Determinístico: sem usar `Time.get_ticks_msec()` internamente, RNG, IO, prints.
3. Hot path: roda muitas vezes por frame/tick (buffers, loops grandes, solver).
4. Testável: dá pra escrever testes unitários com casos e asserts.

✅ **Exemplos típicos (tire):**

- `aggregate_patch`
- `normalize_weights`
- `solve_normal_load`
- `combined_slip_solver`
- `relaxation_length filters`
- `hysteresis/viscoelastic memory` (versão simplificada)
- `clamps/guard rails` determinísticos

✅ **Exemplos típicos (engine):**

- `torque curve evaluation` via LUT
- `turbo spool / wastegate controller` (puro)
- `fuel/ignition cut logic` (puro)
- `drivetrain torque split` (puro)
- `differential models` (puro)

## 3) O que NÃO pode ter duplicata

Um script não deve ter duplicata em Rust porque ele depende do engine ou seria frágil.

### Categorias proibidas

- Readers/Sensores Godot: `RayCast3D`, compute shader readback, `Area3D overlap`.
- Aplicação no corpo: `apply_force`, `apply_torque`, `move_and_slide`, etc.
- Transformações World/Local específicas do Godot (pode existir helper, mas não core).
- Editor/inspector: `Resources`, `Curves`, carregamento de `.tres`, gizmos.
- Sinais / eventos.

✅ **Exemplos:**

- `ShaderContactReader.gd` → Godot-only
- `RaycastSampleReader.gd` → Godot-only
- `TireProfileMeshBuilder.gd` → Godot-only
- `apply_to_suspension()` / `apply_to_wheel()` → Godot-only

## 4) Classificação oficial dos scripts (tags)

Todo script deve declarar “tag” no header (comentário), para evitar drift.

### Tags

- `[ENGINE]` = Godot-only
- `[CORE_GD]` = core em GDScript (`RefCounted`), duplicável em Rust
- `[CORE_RS]` = core em Rust
- `[BRIDGE]` = adapta inputs/outputs entre engine e core
- `[LEGACY]` = caminho antigo (nunca roda se o novo estiver presente)

Exemplo de header:

```gdscript
# [CORE_GD] TireContactAggregation
# Deterministic math. Must match Rust tire_core::aggregate_patch.
```

## 5) Padrão de conexão: Engine → Bridge → Core → Bridge → Engine

### 5.1 Bridge é obrigatório

Toda troca entre engine e core passa por um “Bridge”:

- `InputBridge`: empacota `WheelState`, `TireParams`, `samples[]`
- `OutputBridge`: desempacota `TireForces` e aplica no corpo

✅ Bridge pode ser GDScript (`RefCounted`) ou Node helper, mas:

- ele não decide física (só transforma dados)
- ele não aplica força fora do estágio correto

## 6) Contratos de dados: únicos e tipados

✅ Para qualquer sistema duplicado GD↔Rust, não use `Dictionary` no caminho crítico.

Use tipos:

- `WheelState`
- `TireSample`
- `ContactPatch`
- `TireForces`
- `TireParams`
- `TireState`

No GD: `RefCounted` com campos tipados.  
No Rust: `struct` com `#[repr(C)]` se for FFI, ou `serde` para testes.

## 7) Regra de paridade: Rust é “golden”

Rust define o comportamento de referência.

GDScript replica para prototipagem.

Divergência só é aceita se documentada com:

- “WHY”
- “diferença esperada”
- “plano para convergir”

## 8) Como manter paridade sem rodar Godot tests

### Golden vectors (obrigatório para módulos core)

- Rust gera vetores (JSON) de inputs/outputs
- Godot tem um script `tools/validate_core_parity.gd` que:
  - lê JSON
  - roda `CORE_GD`
  - compara outputs com tolerância

Isso cria “auto-teste” real sem precisar do runtime do jogo.

## 9) Regras para LEGACY

`[LEGACY]` só existe para compatibilidade de cenas antigas.

Deve ter um “gate”:

- se `RuntimeCoordinator` existe → legacy não processa.

## 10) Regras de performance e determinismo

- Tudo que roda no tick usa `dt_tick` fixo, não delta do frame.
- Sem `Time.get_ticks_msec()` dentro do core.
- Clamp anti-NaN obrigatório em boundary points.
- Ordem de iteração fixa (evitar hash-map nondeterminístico).

## 11) Lista inicial de scripts (tire/suspension) com regra de duplicação

### Godot-only (ENGINE)

- `ShaderContactReader.gd`
- `RaycastSampleReader.gd`
- `TireProfileMeshBuilder.gd`
- `TireRuntimeCoordinator.gd` (orquestração + engine calls)
- `TireSuspensionBridge.gd` (apply on engine)
- `Wheel.gd`, `WheelAssemblySystem.gd` (integração cena)

### Duplicável (CORE_GD ↔ CORE_RS)

- `TireContactAggregation.gd`
- `PressureFieldSolver.gd` (se for puro)
- `ContactPatchBuilder.gd` (se não tocar scene)
- `TireSurfaceResponseModel.gd` (na parte matemática)
- `ContactPatchState / hysteresis` (modelo puro)

## 12) Definition of Done para um módulo duplicado

Um módulo está “ok” quando:

- existe `tire_core` (Rust) + `core_gd` equivalente
- Rust tem unit tests
- existe golden vectors gerados
- Godot validator passa (dentro de tolerância)
- engine-facing usa bridge e não toca core diretamente

## Próximo passo (pra ficar prático)

Ações imediatas:

1. Adicionar tags nos headers dos scripts (`ENGINE`/`CORE_GD`/`BRIDGE`/`LEGACY`).
2. Criar 2 bridges explícitas (mesmo que simples):
   - `TireInputBridge.gd`
   - `TireOutputBridge.gd`

Isso “amarra” o contrato e reduz drift.
