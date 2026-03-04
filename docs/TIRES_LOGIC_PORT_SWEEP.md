# Tires/Godot varredura para extração de lógica (port para Rust)

## Objetivo

Mapear `tires/godot` em grupos para migração incremental, mantendo:
- Godot como autoridade de runtime/scene I/O
- Rust para cálculo puro e determinístico

## Método

Foi adicionado o script:

```bash
python3 tires/tools/sweep_tires_logic_candidates.py
```

Saída gerada em:
- `tires/shared/logic_port_candidates_v1.json`

## Resumo da varredura atual

- total: **46** arquivos
- pure logic candidate: **21**
- mixed extractable: **6**
- runtime bound: **12**
- alias wrapper: **7**

## O que portar primeiro (Wave 1)

Candidatos diretos (puro cálculo/contrato):

- `tires/godot/TireCoreReference.gd`
- `tires/godot/core/TireCore.gd`
- `tires/godot/core/ContactPatchData.gd`
- `tires/godot/core/TireForces.gd`
- `tires/godot/aggregation/TireContactAggregation.gd`
- `tires/godot/BrushModelSolver.gd`
- `tires/godot/ContactConfidenceModel.gd`
- `tires/godot/TemporalHistory.gd`
- `tires/godot/pressurefieldsolver.gd`
- `tires/godot/influencecontractbuilder.gd`
- `tires/godot/forceregimeevaluator.gd`
- `tires/godot/contactpatchbuilder.gd`
- `tires/godot/contactpatchstate.gd`
- `tires/godot/data/WheelState.gd`
- `tires/godot/ContactPatch.gd`

## O que extrair parcialmente (Wave 2)

Arquivos mistos: manter integração Godot e extrair somente fórmulas:

- `tires/godot/data/tiresample.gd`
- `tires/godot/surface/TireSurfaceResponseModel.gd`
- `tires/godot/runtime/TireContactRuntime.gd`
- `tires/godot/TireRigidBodyApplicator.gd`
- `tires/godot/apply_raycast_influence.gd`
- `tires/godot/bridge/TireSuspensionBridge.gd`

## Fica em Godot (por enquanto)

Runtime bound/orquestração/leitura de cena:

- `runtime/TireRuntimeCoordinator.gd`
- `readers/*`
- `tirephysicsorchestrator.gd`
- demais scripts classificados como `runtime_bound`

## Observação de organização

Os 7 arquivos `alias_wrapper` devem permanecer apenas como compatibilidade de caminho, sem nova lógica.
A implementação canônica deve ficar nas subpastas (`runtime/`, `readers/`, `surface/`, etc.).
