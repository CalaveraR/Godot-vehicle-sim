# suspension/rust

Arquitetura de duplicação para suspensão dividida por núcleos.

## Núcleo A — Engine-side orchestration (Godot)
Permanece em GDScript:
- `SuspensionSystem` como orquestrador
- `_ready`, `configure_curves`, `reset_raycast`, `update_raycast_direction`
- qualquer acesso a `Node`, `RayCast`, scene tree

## Núcleo B — Wheel Suspension Core (Rust + espelho)
Arquivos:
- `core/SuspensionCoreContracts.rs`
- `core/SuspensionCoreKernel.rs`

Funções puras portadas:
- `compute_deformation_clamped` (parte pura de `apply_elastic_deformation`)
- `compute_effective_radius`
- `compute_relaxation_factor`
- `compute_lateral_deformation`

## Núcleo C — Suspension Type Core (Rust + espelho)
Arquivo:
- `core/SuspensionTypeKernels.rs`

Cobertura:
- McPherson (`calculate_specific_geometry` via valores já avaliados)
- Double Wishbone
- MultiLink
- PushRod
- PullRod
- Air

## Núcleo D — Axle Core (Rust + espelho)
Arquivo:
- `core/AxleCoreKernel.rs`

Cobertura:
- matemática de `SolidAxle` sem `get_node`

## Núcleo E — Response Core (Rust + espelho)
Arquivo:
- `core/SuspensionResponseCoreKernel.rs`

Cobertura:
- parte pura de `SuspensionResponseSystem.calculate_dynamic_response`

## Regra de contrato
Godot avalia curvas (`Curve.interpolate*`) e envia valores flat para o kernel Rust.


## Pipeline por tick (recomendado)
1. Inputs Godot (load, deformation, curves já avaliadas/LUT).
2. `compute_deformation_clamped`.
3. type core (`SuspensionTypeKernels`) para deltas por tipo.
4. `compute_effective_radius`.
5. `compute_relaxation_factor` + `compute_lateral_deformation`.
6. response core (`SuspensionResponseCoreKernel`).
7. axle core (`compute_solid_axle`) quando tipo for `SOLID_AXLE`.
8. Apply em Godot + `update_raycast_direction()`.

## Duplicata obrigatória (estado atual)
- `apply_elastic_deformation` (parte pura)
- `update_effective_radius`
- `update_relaxation_length`
- `update_lateral_deformation`
- `calculate_specific_geometry` dos tipos (McPherson, Double Wishbone, MultiLink, Pull/Push Rod, Air)
- `SuspensionResponseSystem.calculate_dynamic_response` (parte pura)
- `SolidAxle` sem scene lookup

## Paridade de cálculo (Godot ↔ Rust)

Enquanto a ponte runtime completa evolui, valide a equivalência numérica das fórmulas-base com:

```bash
python3 suspension/tools/check_suspension_core_parity.py
```

Fonte dos vetores de referência:
- `suspension/shared/suspension_core_golden_v1.json`

