# Varredura parte a parte — nível atual do projeto

## Contexto da avaliação

Critério aplicado conforme direção atual do projeto:

- Duplicação **Godot↔Rust** é aceitável quando houver objetivo de mirror/migração.
- Duplicação **Godot↔Godot** de responsabilidade deve ser reduzida (um owner por propriedade/camada).

Escala de nível usada nesta varredura:

- **N1**: protótipo inicial
- **N2**: funcional básico
- **N3**: funcional estruturado
- **N4**: avançado com estratégia de migração/testes
- **N5**: consolidado (paridade + integração Rust operacional)

Inventário observado na varredura (arquivos):

- `engine`: 29 scripts Godot, 17 mirrors Rust.
- `suspension`: 17 scripts Godot, 8 mirrors Rust, 6 kernels core Rust.
- `wheels`: 6 scripts Godot, 2 kernels core Rust.
- `tires`: 46 scripts Godot, 26 mirrors Rust, 5 kernels core Rust, 7 wrappers legacy no topo de pasta.

---

## 1) Pneus (tires) — **N4 (avançado)**

### Evidências

- Existe coordenador explícito de autoridade única (`TireRuntimeCoordinator`) com pipeline por estágio e modos `GDSCRIPT/RUST/SHADOW`.
- O runtime já explicita ordem determinística (`read -> aggregate -> apply`) e shadow compare.
- Há cobertura ampla de mirror documentada para diversos scripts de pneus em Rust.

### Pontos de atenção

- Ainda existem aliases/wrappers legados no topo de `tires/godot/` redirecionando para implementações em subpastas. Isso ajuda compatibilidade, mas pode criar ambiguidade Godot↔Godot se não houver convenção canônica.

### Leitura de maturidade

Pneus é hoje o domínio mais avançado do repositório em termos de arquitetura e preparação para transição incremental para Rust.

---

## 2) Suspensão (suspension) — **N4- (quase N4 cheio)**

### Evidências

- `SuspensionSystem` já define backend mode (`GDSCRIPT/RUST/SHADOW`) e mantém orquestração em Godot.
- A camada Rust de suspensão está bem dividida em núcleos (`SuspensionCore`, `TypeKernels`, `AxleCore`, `ResponseCore`) com regra de contrato explícita.

### Pontos de atenção

- O caminho `RUST` no `SuspensionSystem` ainda está em modo stub (ponte real futura), então a troca de backend ainda não está operacional ponta a ponta.

### Leitura de maturidade

Suspensão está bem desenhada para migração, com boa separação de responsabilidade; falta maturidade de integração efetiva do backend Rust em runtime.

---

## 3) Rodas (wheels) — **N3+ (funcional estruturado)**

### Evidências

- `Wheel.gd` permanece como autoridade de integração/orquestração em Godot.
- Há kernel numérico em Rust para dinâmica da roda (`step_wheel_dynamics`) com integração de estado, slip e transientes.
- Documentação de migração de rodas está clara sobre escopo e fases.

### Pontos de atenção

- Domínio ainda depende mais do ciclo de integração em Godot do que de backend Rust operacional completo.
- Cobertura mirror em `wheels/rust/mirror` não está no mesmo nível de pneus/suspensão.

### Leitura de maturidade

Rodas já saiu do estágio inicial e tem núcleo matemático pronto, mas ainda está um passo atrás de pneus/suspensão em profundidade de migração.

---

## 4) Motor (engine) — **N3 (funcional, com base para evoluir)**

### Evidências

- O domínio tem variedade funcional alta em GDScript (combustão, indução, turbo, ignição, óleo, etc.).
- Há espelhamento em `engine/rust/mirror/*` documentado para vários scripts lógicos.
- Ao mesmo tempo, o diretório `engine/rust` ainda é descrito como espaço reservado para mirror de lógica pura, sem pipeline de integração operacional equivalente ao de pneus.

### Pontos de atenção

- Falta um plano de execução por tick/backend mode tão explícito quanto pneus/suspensão para orientar migração incremental sem drift.

### Leitura de maturidade

Motor está funcional e modular no lado Godot, com espelhos Rust relevantes, mas ainda sem o mesmo nível de institucionalização de runtime híbrido dos módulos mais avançados.

---

## Diagnóstico geral do projeto

- **Arquitetura e direção técnica:** forte (especialmente na separação Godot-orquestração vs Rust-core).
- **Módulo mais maduro:** pneus.
- **Módulo mais próximo de subir de nível:** suspensão (quando fechar ponte Rust real).
- **Maior oportunidade de padronização:** motor e rodas seguirem o mesmo padrão operacional de backend mode + shadow compare + critérios de corte para Rust-only.

## Prioridade sugerida (curto prazo)

1. Fechar ponte Rust real da suspensão mantendo `SuspensionSystem` como autoridade.
2. Formalizar pipeline/mode para engine no mesmo padrão de pneus.
3. Padronizar depreciação de aliases legados em pneus para reduzir duplicação Godot↔Godot sem quebrar compatibilidade.
4. Aumentar cobertura de contracts e snapshots para rodas.
