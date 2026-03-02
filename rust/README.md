# Rust modules for tire physics (incremental)

Este diretório guarda módulos Rust pequenos e focados em cálculo puro.

## Estado atual

- `tire_core`: funções determinísticas para
  - normalização de pesos
  - agregação de patch
  - raio efetivo

## Próximo passo para binding Godot 4

1. transformar `tire_core` em crate usada por um crate `gdextension`
2. expor API mínima para GDScript (`aggregate_patch`, `compute_effective_radius`)
3. comparar resultados Rust x GDScript em testes de regressão

> Importante: orquestração de cena, sinais e integração de nós continuam em GDScript.

## Paridade com protótipo GDScript

O arquivo `tires/TireCoreReference.gd` funciona como espelho de lógica para prototipagem
em Godot. Sempre que uma regra de fallback mudar no GDScript, atualize o crate Rust
para manter equivalência numérica durante a transição.
