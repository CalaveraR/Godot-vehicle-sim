# Tire Core Backend Rules (GDScript ↔ Rust)

Este documento define **o que deve ser duplicado/portado** para Rust e o que deve permanecer em Godot, além da ordem de execução e critérios.

---

## 1) O que fica em Godot (sempre)

Fica em GDScript tudo que depende de:
- leitura de contato (RayCast / shader readback / `PhysicsDirectSpaceState3D`)
- orquestração (tick fixo, buffers, fallback)
- aplicação de forças no corpo (`RigidBody3D.add_force`, etc.)
- integração com suspensão e sistemas de efeito/telemetria

Exemplos:
- `tires/runtime/*` (maestro/pipeline)
- `tires/readers/*` (sensores)
- `tires/bridge/*` (integração com suspensão)
- `wheels/Wheel.gd` (integração por roda)

---

## 2) O que vai para Rust (primeiro / baixo risco)

Portar apenas cálculo puro, determinístico e testável:

1) normalização de pesos
2) agregação numérica do patch (médias ponderadas, slip/penetração)
3) raio efetivo / compressão (bounded)

Critérios:
- sem dependência de scene tree
- entrada/saída explícita (struct plana)
- sem estado global

---

## 3) O que pode ir para Rust (segundo / médio risco)

Portar quando virar hotspot e já houver paridade:

- solver de carga/pressão por sample (se existir e for caro)
- kernels de força (Fx/Fy/Mz sob limite `mu * Fz`)
- redução temporal (histórico) se pesado

---

## 4) O que deve ficar em Godot por enquanto (design/game logic)

Regras de desgaste, temperatura, aquaplaning, curvas e tuning de gameplay tendem a mudar muito.
Manter em GDScript até estabilizar o modelo.

Após estabilizar, portar **apenas** se profiling indicar hotspot.

---

## 5) Ordem determinística do pipeline (contrato)

Por tick fixo:

1) Ler samples (sensores)
2) Construir pacote raw (por roda)
3) Core backend (GDScript ou Rust) normaliza e calcula
4) Preencher contratos (`ContactPatchData`, `TireForces`) e aplicar no body
5) Atualizar wear/temp e efeitos (tuning)

É proibido “pular” etapas ou aplicar forças fora do runtime oficial.

---

## 6) Regras de determinismo prático

Para reduzir drift e edge-case explosions:

- ordem fixa de iteração de samples
- evitar decisões binárias em thresholds sem histerese
- clamps e slew limits por estágio
- fallback consistente (last_good + confidence baixo)
- nunca retornar NaN/Inf

---

## 7) Shadow compare (gate de migração)

Toda função portada deve ter:
- implementação de referência em GDScript (para prototipagem)
- implementação em Rust
- modo `SHADOW_COMPARE` para medir divergência por estágio

A troca para `RUST_ONLY` só acontece quando:
- invariantes passam
- divergência está dentro do budget
- edge cases não explodem (bounded)

---

## 8) Checklist de PR (para mudanças no core)

Antes de merge:
- contrato da ponte respeitado (buffers, tipos, layout)
- invariantes garantidas no core
- testes Rust (`cargo test`) passam
- se houver mudança em conventions: version bump + nota no changelog
- nenhuma aplicação de força fora do runtime oficial
