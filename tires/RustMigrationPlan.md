# Plano de migração incremental Godot → Rust (pneus)

Este plano cria **ordem explícita** para substituir apenas blocos de cálculo pesado, mantendo a filosofia atual:

- contato distribuído e emergente
- separação entre percepção (amostras/patch) e dinâmica (aplicação de forças)
- scripts explícitos por responsabilidade

## Ordem de migração (por risco/retorno)

1. **Agregação matemática do patch** (`TireContactAggregation`)  
   - mover somas vetoriais, torque, área e `weighted_grip` para Rust.
   - baixo acoplamento com SceneTree e alto custo por frame.

2. **Step de desgaste/temperatura** (`TireSurfaceResponseModel`)  
   - mover integração numérica de wear/heat/cooling.
   - manter curvas/resources no Godot e enviar somente escalares para Rust.

3. **Brush micro-solver / força tangencial local** (`BrushModelSolver`)  
   - mover apenas núcleo matemático (força limitada por `μ*Fz`, slip combinado).
   - manter orquestração e estados no GDScript.

4. **Redução em lote orientada a GPU/CPU**  
   - quando as etapas acima estiverem estáveis, avaliar compute path dedicado.

## O que NÃO migrar agora

- nós de cena, raycasts, ligação com `Wheel`, `Area3D`, sinais e lifecycle do Godot.
- orquestradores (`TireRuntimeCoordinator`, bridges) que dependem fortemente de árvore de cena.

## Critério de “pronto para migrar”

Cada bloco deve ter:

- I/O puro (sem acesso a Node)
- tipos simples (float, vetores, arrays)
- teste determinístico repetível
- equivalência com baseline GDScript

## Prova de conceito adicionada neste PR

Foi criado um crate Rust em `rust/tire_core/` com duas funções FFI (`extern "C"`):

- `tire_aggregate_contacts(...)`
- `tire_step_wear_and_temperature(...)`

Objetivo: validar pipeline incremental sem quebrar arquitetura atual.

## Próximo passo sugerido

Criar um adapter GDScript/GDExtension fino (`TireRustAdapter`) para alternar por feature flag:

- `use_rust_tire_core = false/true`
- fallback automático para GDScript em caso de indisponibilidade do binário.
