# wheels/rust

Escopo de duplicação Rust para `wheels/` seguindo a regra de arquitetura atual:

## Não duplicar (permanece em GDScript)
- `wheels/godot/Wheel.gd` (orquestração, scene graph, sinais, integrações)
- `wheels/godot/WheelAssemblySystem.gd` (wiring/configuração)
- `wheels/godot/Brake*` (lógica de gameplay/frenagem básica)

## Duplicar/portar (núcleo puro)
- `wheels/godot/WheelDynamics.gd` → `wheels/rust/core/WheelDynamicsKernel.rs`
- Contrato de dados flat para integração numérica → `wheels/rust/core/WheelDynamicsContracts.rs`

## Candidatos futuros (por profiling)
- `FlatSpotSystem`
- `SuspensionResponseSystem`

A integração com física do Godot continua sendo autoridade única em `Wheel.gd`.
