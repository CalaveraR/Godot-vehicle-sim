# logic_mirror

Camada de redundância em Rust para scripts GDScript classificados como lógicos/determinísticos.

- Fonte de verdade do mapeamento: `src/lib.rs` (`REGISTRY`).
- Espelhos por script ficam nas subpastas correspondentes:
  - `engine/rust/mirror/*`
  - `suspension/rust/mirror/*`
  - `tires/rust/mirror/*`

Esta camada preserva filosofia de determinismo e contratos tipados, permitindo evolução incremental para equivalência total por módulo.
