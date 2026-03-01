# Entendimento do sistema: como ele **deve** funcionar e como eu entendo a implementação atual

## 1) Objetivo funcional (minha leitura)
Meu entendimento é que este projeto tenta construir uma camada de física de pneu em cima do Godot, com foco em:
- reconstruir o contato pneu-solo a partir de múltiplas fontes (shader + raycast),
- transformar esse contato em forças físicas coerentes (`Fx`, `Fy`, `Fz`, `Mz`),
- manter continuidade temporal para evitar “pulos” numéricos,
- degradar com segurança quando os dados de contato perdem qualidade.

Em resumo: o sistema não quer só “detectar contato”, ele quer **estimar estado de contato confiável** e aplicar respostas físicas estáveis.

---

## 2) Como o sistema deveria funcionar (arquitetura alvo)

### 2.1 Pipeline lógico ideal
A cadeia ideal (de alto nível) é:
1. **Aquisição de amostras** (shader/raycast).
2. **Fusão e qualificação** das amostras em um `ContactPatch`.
3. **Estimativa de confiança** do patch.
4. **Escolha de regime físico** (completo/degradado/fallback).
5. **Cálculo de forças** pelos submodelos (normal, slip, torque).
6. **Pós-processamento temporal** (máquina de estados de contato).
7. **Aplicação final** no corpo rígido e/ou contrato de influência.
8. **Persistência histórica** para estabilidade e diagnóstico.

### 2.2 Princípio de robustez esperado
Quando a qualidade de entrada cai, o sistema ideal não “quebra”; ele:
- reduz autoridade da força,
- suaviza transições,
- usa memória curta (persistência/fallback),
- retorna gradualmente ao modo completo quando a confiança volta.

---

## 3) Como eu entendo a implementação atual

### 3.1 Solver central (`TireContactSolver`)
O `solve()` já está estruturado como um orquestrador por etapas:
- controla taxa de resolução (`solve_rate`),
- coleta amostras de shader e raycast,
- atualiza histórico temporal,
- reconstrói `ContactPatch`,
- atualiza regime (`STANDARD`, `DEGRADED`, `FALLBACK`),
- calcula forças com modificadores por regime,
- opcionalmente processa resultado via `ContactState`,
- guarda contexto para o próximo frame.

Esse desenho sugere que o solver é a “fronteira de decisão física” por frame.

### 3.2 Máquina de estado de contato (`ContactStateMachine`)
A FSM temporal, no meu entendimento, é a camada de continuidade:
- modos `GROUNDED_VALID`, `GROUNDED_PERSISTENT`, `IMPACT_TRANSITION`, `AIRBORNED`,
- filtro temporal opcional da confiança,
- decaimento controlado de confiança/forças de fallback,
- transição por impacto e persistência máxima.

Ou seja: ela atua como amortecedor de transições, evitando que ruído de patch cause instabilidade instantânea nas forças.

### 3.3 Orquestração ampliada (`TirePhysicsOrchestrator`)
Existe também uma linha arquitetural mais “sistêmica”, com:
- builder de patch,
- política de autoridade,
- builder/merge/rate-limit de contratos,
- aplicação de influência,
- integração com brush/pressure solver.

Minha leitura: isso aponta para uma evolução onde o contato deixa de ser apenas cálculo local e vira um **ecossistema de decisão física + governança de influência**.

---

## 4) Modelo mental consolidado (o “como” que acredito ser o correto)

### 4.1 Separação de responsabilidades
- **Aquisição**: leitores (shader/raycast) só medem.
- **Reconstrução**: patch builder converte medidas em geometria/estado de contato.
- **Interpretação física**: solver decide regime e calcula forças.
- **Continuidade temporal**: FSM garante transição suave.
- **Aplicação/integração**: orquestradores aplicam no corpo/contratos.

### 4.2 Contratos de dados necessários
Para esse desenho escalar, o ideal é formalizar 3 contratos:
1. `ContactPatch` (qualidade e geometria do contato),
2. `ForceResult` (forças + metadados + origem),
3. `ContactTemporalState` (modo atual, timers, confiança efetiva).

Hoje há bastante tráfego por `Dictionary`; funciona para protótipo, mas tende a fragilizar manutenção.

### 4.3 Regras de transição esperadas
Entendo que a regra desejada seja:
- **Alta confiança** → modelo completo + grounded valid.
- **Confiança intermediária** → persistência com blend.
- **Baixa confiança/ruptura** → fallback com decaimento.
- **Retorno de consistência** → reentrada progressiva no regime completo.

Se essa for a direção do projeto, ela está coerente com os componentes já presentes.

---

## 5) Onde vejo mais alinhamento (pontos fortes)
- Pipeline por etapas no solver está claro e extensível.
- Mecanismo explícito de degradação/fallback já existe.
- FSM temporal cobre exatamente o problema de continuidade.
- Há preocupação com histerese, persistência e debug.
- A arquitetura de orquestração mais ampla já prepara terreno para governança por contratos.

---

## 6) Onde pode haver desalinhamento com o objetivo final
1. **Dois eixos de estado sem política explícita de compatibilidade**
   - Regime físico (solver) e modo temporal (FSM) podem divergir sem uma camada unificadora.

2. **Clock de processamento parcialmente dependente de tempo absoluto**
   - Para previsibilidade/determinismo, um acumulador por `delta` tende a ser mais estável.

3. **Schema frouxo de dados de força/patch em parte do fluxo**
   - Dicionários dinâmicos tornam validação e evolução mais custosas.

4. **Arquiteturas paralelas coexistindo (solver central vs orquestrador expandido)**
   - Pode ser intencional (fase de transição), mas merece um mapa explícito de “qual caminho é canônico”.

---

## 7) Critérios de validação que eu usaria para conferir alinhamento com sua visão
Se o seu objetivo for realismo + estabilidade + escalabilidade, eu validaria estes comportamentos:
1. Perda abrupta de contato não gera “spike” de força.
2. Oscilação de confiança perto de limiar não gera troca caótica de estado.
3. Recontato após airborne retorna força de forma progressiva.
4. Fallback mantém dirigibilidade mínima sem mascarar perda real de contato.
5. Mesma entrada temporal gera saída próxima entre execuções (consistência).

---

## 8) Resumo direto (para você comparar com sua intenção)
Meu entendimento do que você está construindo é:
- um **pipeline híbrido de contato** (shader + raycast),
- com **tomada de decisão por qualidade de dado** (regimes),
- mais **continuidade temporal explícita** (FSM),
- evoluindo para uma **arquitetura de orquestração por contratos**,
- com foco em evitar tanto instabilidade numérica quanto simplificações que matem a sensação física.

Se sua intenção for essa, eu diria que a base atual está no caminho certo; o próximo salto é consolidar contrato de dados e política única de transição entre regimes e modos.
