# suspension/rust

Escopo de duplicação para suspensão com foco em **core numérico por tick**.

## Duplicar/portar (pure core)
- `suspension/rust/core/SuspensionCoreKernel.rs`
  - `compute_deformation_clamped`
  - `compute_effective_radius`
  - `compute_relaxation_factor`
  - `compute_lateral_deformation`
- `suspension/rust/core/McPhersonGeometryKernel.rs`
  - `compute_geometry_deltas_mcperson`
  - (opcional) `roll_center` / `instant_center` se usados em solver
- `suspension/rust/core/SuspensionCoreContracts.rs`
  - contratos flat para bridge Godot ↔ Rust

## Não duplicar
- escrita em `RayCast`/`Node`/`Transform`
- criação/configuração default de `Curve`
- orquestração completa de `update_suspension_geometry(...)`

Godot continua como autoridade de integração com engine.
