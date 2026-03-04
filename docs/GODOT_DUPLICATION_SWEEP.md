# Varredura profunda: duplicação Godot↔Godot vs Godot↔Rust

## Objetivo

Registrar uma varredura técnica para separar:

- **Duplicação permitida:** Godot↔Rust (espelho/mirror durante migração).
- **Duplicação a reduzir:** Godot↔Godot entre scripts diferentes, quando há sobreposição de responsabilidade sobre a mesma propriedade/estado.

## Regra adotada nesta varredura

Cada script Godot deve ter propriedade clara sobre seu estado interno. Wrappers de compatibilidade podem existir, mas não devem competir com implementações paralelas que também mudam o mesmo estado em runtime.

## Resumo executivo

Foram encontrados **aliases/wrappers legados em `tires/godot/`** (arquivos de 1 linha com `extends ...`) apontando para implementações reais em subpastas (`runtime/`, `readers/`, `surface/`, `aggregation/`, `data/`).

Esses wrappers são úteis para compatibilidade de caminho (`res://...`), porém são um ponto clássico de ambiguidade Godot↔Godot se cenas/scripts misturam caminhos antigos e novos sem convenção única.

## Evidências principais (Godot↔Godot)

### 1) Agregação de contato

- Wrapper legado: `tires/godot/TireContactAggregation.gd` apenas redireciona com `extends`.  
- Implementação real: `tires/godot/aggregation/TireContactAggregation.gd` contém cálculo de pesos, patch e torque.

Risco: cenas podem referenciar wrapper e implementação direta ao mesmo tempo, dificultando rastreabilidade de ownership.

### 2) Runtime de contato

- Wrapper legado: `tires/godot/TireContactRuntime.gd` redireciona com `extends`.  
- Implementação real: `tires/godot/runtime/TireContactRuntime.gd` escreve/aplica forças e atualiza métricas (`wheel.contact_area`, `set_ground_grip`, etc.).

Risco: dois pontos de entrada aparentes para o mesmo domínio de atualização de força/contato.

### 3) Coordenador (autoridade única)

- Wrapper legado: `tires/godot/TireRuntimeCoordinator.gd` redireciona com `extends`.  
- Implementação real: `tires/godot/runtime/TireRuntimeCoordinator.gd` explicita Single Authority Rule e orquestra pipeline.

Risco: violar a intenção de autoridade única quando o projeto mistura import/caminho antigo e novo em diferentes cenas.

### 4) Leitores de amostra

- Wrappers legados:
  - `tires/godot/shadercontactreader.gd`
  - `tires/godot/raycastsamplereader.gd`
- Implementações reais:
  - `tires/godot/readers/shadercontactreader.gd`
  - `tires/godot/readers/raycastsamplereader.gd`

Risco: dupla referência de classe para o mesmo papel (sensor input), aumentando acoplamento e ambiguidade de manutenção.

### 5) Modelo de dados da amostra

- Wrapper legado: `tires/godot/tiresample.gd`.
- Implementação real: `tires/godot/data/tiresample.gd` (estrutura completa de dados, campos e factories).

Risco: quando scripts antigos e novos coexistem, a localização canônica do contrato de dados não fica explícita para contribuidores.

## O que **não** foi marcado como problema

- Espelhos Godot↔Rust (`*/rust/mirror/*`) permanecem intencionais nesta fase de migração.
- Repetição de nomes locais (`result`, `data`, `current_time`) em funções distintas não configura, por si só, duplicação de ownership de propriedade.

## Recomendação prática (sem quebrar compatibilidade agora)

1. **Definir canônico por pasta** (ex.: `tires/godot/runtime/*`, `tires/godot/readers/*`, `tires/godot/data/*`).
2. **Manter wrappers apenas como alias transitório**, com comentário padrão `LEGACY_ALIAS` + prazo de remoção.
3. **Proibir novos scripts no nível raiz de `tires/godot/`** para classes já realocadas.
4. **Adicionar verificação CI simples** para detectar novos wrappers não documentados.
5. **Atualizar cenas para caminho canônico** gradualmente e depois remover alias de 1 linha.

## Resultado desta etapa

Varredura concluída com foco no critério solicitado: evitar duplicação Godot↔Godot de responsabilidade, mantendo duplicação Godot↔Rust quando necessária para mirror/migração.
