# Varredura de scripts GDScript e espelhamento Rust

## Critério usado na varredura

Scripts considerados **majoritariamente lógicos**:
- `extends RefCounted` ou classes de dados/contrato.
- Sem dependência direta de árvore de cena (`get_node`, `$`, sinais de Node) para o cálculo principal.
- Transformações matemáticas e agregações determinísticas.

Scripts fortemente acoplados ao runtime Godot (não espelhados nesta etapa):
- Leitores de mundo/sensores (`raycast`, shader readers), aplicadores de força em `RigidBody3D`, orquestração de nós.

## Espelhamento funcional implementado nesta etapa

Base: `rust/tire_core/src/lib.rs`

Equivalências de abordagem adicionadas:
- `tires/godot/core/TireCore.gd` -> `step_wheel_mirror(...)` em Rust
- `tires/godot/core/ContactPatchData.gd` -> `ContactPatchDataMirror`
- `tires/godot/data/tiresample.gd` -> `TireSampleMirror`
- Estruturas auxiliares de vetor (`Vec2`, `Vec3`) para manter semântica de cálculo

## Observações

- O espelhamento foi feito preservando a mesma lógica de alto nível: merge de amostras, agregação ponderada, fallback de emergência por baixa confiança, cálculo simplificado de `Fz`, saturação tangencial por `mu*Fz` e energy clamp.
- O escopo foi focado no núcleo lógico determinístico e serializável, mantendo separação de responsabilidades com a camada Godot.
