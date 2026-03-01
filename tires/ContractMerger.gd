# res://core/contracts/ContractMerger.gd
class_name ContractMerger
extends Node

# ------------------------------------------------------------------------------
# Enums
# ------------------------------------------------------------------------------
enum MergeStrategy {
	WEIGHTED_AVERAGE,   # Média ponderada por plausibilidade (padrão)
	PRIORITY_MAX,       # Usa o contrato de maior prioridade
	SAFETY_FIRST,       # Prioriza contratos com flags de segurança
	CONSENSUS,          # Requer consenso mínimo entre contratos
}

enum ConflictResolution {
	AVERAGE,            # Usa média aritmética dos valores conflitantes
	SAFETY,             # Resolve a favor da segurança (valores mais restritivos)
	HIGHEST_CONFIDENCE, # Usa o valor do contrato com maior confiança
}

# ------------------------------------------------------------------------------
# Configurações padrão (compartilhadas entre instâncias)
# ------------------------------------------------------------------------------
static var DEFAULT_MODE_WEIGHTS: PackedFloat32Array = [
	0.3,  # MODE_CLAMP
	0.6,  # MODE_BIAS
	0.9,  # MODE_GEOMETRY_REFERENCE
]
static var DEFAULT_AUTHORITY_WEIGHTS: PackedFloat32Array = [
	0.1,  # AUTHORITY_NONE
	0.3,  # AUTHORITY_LOW
	0.6,  # AUTHORITY_MEDIUM
	0.8,  # AUTHORITY_HIGH
	1.0,  # AUTHORITY_CRITICAL
]
static var DEFAULT_MIN_CONSENSUS: int = 2
static var DEFAULT_CONSENSUS_THRESHOLD: float = 0.7
static var DEFAULT_SAFETY_PRIORITY_MULTIPLIER: float = 2.0

# ------------------------------------------------------------------------------
# Propriedades da instância
# ------------------------------------------------------------------------------
var merge_strategy: MergeStrategy = MergeStrategy.WEIGHTED_AVERAGE
var conflict_resolution: ConflictResolution = ConflictResolution.SAFETY
var min_contracts_for_consensus: int = DEFAULT_MIN_CONSENSUS
var consensus_threshold: float = DEFAULT_CONSENSUS_THRESHOLD
var safety_priority_multiplier: float = DEFAULT_SAFETY_PRIORITY_MULTIPLIER

# Pesos customizáveis por instância (cópia dos estáticos)
var mode_weights: PackedFloat32Array = DEFAULT_MODE_WEIGHTS.duplicate()
var authority_weights: PackedFloat32Array = DEFAULT_AUTHORITY_WEIGHTS.duplicate()

# ------------------------------------------------------------------------------
# Buffers reutilizáveis (evitam alocações durante o merge)
# ------------------------------------------------------------------------------
var _mode_accum: PackedFloat32Array      # acumulador de pesos por modo
var _authority_accum: PackedFloat32Array # acumulador de pesos por autoridade
var _data_accum: Dictionary              # chave -> {sum: float, weight: float}
var _safety_flags_pool: Array[String]    # buffer para coleta de flags

signal contracts_merged(result: Dictionary)

func _init() -> void:
	# Pré‑aloca os buffers de acumulação de modo/autoridade
	_mode_accum.resize(8)        # índice até 7 (folga)
	_authority_accum.resize(8)
	_clear_accumulators()

# ------------------------------------------------------------------------------
# API Pública Principal
# ------------------------------------------------------------------------------

## Funde uma lista de contratos em um único contrato.
## Retorna um novo `NeutralInfluenceContract` contendo a fusão.
## Se a lista estiver vazia ou todos os contratos forem inválidos,
## retorna um contrato neutro de recuperação (`force_recovery`).
func merge(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	# Caso trivial: sem contratos
	if contracts.is_empty():
		return force_recovery(now_ms)
	
	# Caso trivial: apenas um contrato
	if contracts.size() == 1:
		return _copy_contract(contracts[0], now_ms)
	
	# Filtra contratos inválidos (se tiverem método `is_valid`)
	var valid: Array[NeutralInfluenceContract] = []
	for c in contracts:
		if c.has_method(&"is_valid"):
			if c.is_valid():
				valid.append(c)
		else:
			valid.append(c)
	
	if valid.is_empty():
		return force_recovery(now_ms)
	
	# Prepara buffers para esta iteração
	_clear_accumulators()
	_safety_flags_pool.clear()
	
	# Executa a estratégia escolhida
	match merge_strategy:
		MergeStrategy.WEIGHTED_AVERAGE:
			return _merge_weighted_average(valid, now_ms)
		MergeStrategy.PRIORITY_MAX:
			return _merge_priority_max(valid, now_ms)
		MergeStrategy.SAFETY_FIRST:
			return _merge_safety_first(valid, now_ms)
		MergeStrategy.CONSENSUS:
			return _merge_consensus(valid, now_ms)
		_:
			return _merge_weighted_average(valid, now_ms)

## Gera um contrato neutro de fallback (força recuperação).
## Útil quando nenhum contrato válido é fornecido ou ocorre erro.
func force_recovery(now_ms: int) -> NeutralInfluenceContract:
	var out := NeutralInfluenceContract.new()
	out.mode = 0
	out.authority = 0
	out.confidence = 0.1
	out.influence_weight = 0.1
	out.safety_flags = ["merge_fallback"]
	out.data = {
		"compression": 0.0,
		"normal": Vector3.UP,
		"contact_width": 0.0
	}
	out.timestamp = now_ms
	return out

# ------------------------------------------------------------------------------
# Configuração dinâmica
# ------------------------------------------------------------------------------
func merge_contracts_for_owner(owner_id: String, contracts: Array, now_ms: int = -1) -> Dictionary:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()

	var typed_contracts: Array[NeutralInfluenceContract] = []
	for contract in contracts:
		if contract is NeutralInfluenceContract:
			typed_contracts.append(contract)

	var merged_contract: NeutralInfluenceContract = merge(typed_contracts, now_ms)
	var result := {
		"owner_id": owner_id,
		"contract_count": typed_contracts.size(),
		"merged_contract": merged_contract.get_contract_summary() if merged_contract else {},
		"merge_strategy": merge_strategy,
		"timestamp": now_ms
	}
	contracts_merged.emit(result)
	return result

func set_strategy(strategy: MergeStrategy) -> void:
	merge_strategy = strategy

func set_conflict_resolution(resolution: ConflictResolution) -> void:
	conflict_resolution = resolution

func set_consensus_params(min_contracts: int, threshold: float) -> void:
	min_contracts_for_consensus = max(min_contracts, 2)
	consensus_threshold = clamp(threshold, 0.5, 1.0)

# ------------------------------------------------------------------------------
# Métodos de Fusão (Estratégias)
# ------------------------------------------------------------------------------
func _merge_weighted_average(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	# Acumula pesos e valores
	var total_weight: float = 0.0
	var confidence_sum: float = 0.0
	var influence_sum: float = 0.0
	
	for c in contracts:
		var w: float = _calculate_contract_weight(c)
		total_weight += w
		
		# Modo e autoridade (acumulação por peso)
		var m: int = c.mode
		if m < _mode_accum.size():
			_mode_accum[m] += w
		var a: int = c.authority
		if a < _authority_accum.size():
			_authority_accum[a] += w
		
		# Confiança e peso de influência
		confidence_sum += c.confidence * w
		influence_sum += c.influence_weight * w
		
		# Dados do contrato
		for key: String in c.data:
			var val = c.data[key]
			if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_VECTOR3:
				if not _data_accum.has(key):
					_data_accum[key] = { &"sum": 0.0, &"weight": 0.0 }
				var acc = _data_accum[key]
				acc.sum += (val if typeof(val) == TYPE_FLOAT else _vector3_sum(val)) * w
				acc.weight += w
		
		# Flags de segurança (coleta única)
		for flag in c.safety_flags:
			if not _safety_flags_pool.has(flag):
				_safety_flags_pool.append(flag)
	
	# Cria contrato fundido
	var out := NeutralInfluenceContract.new()
	
	# Modo: o com maior peso acumulado
	out.mode = _index_of_max_weight(_mode_accum)
	# Autoridade: a com maior peso acumulado
	out.authority = _index_of_max_weight(_authority_accum)
	# Confiança e influência (média ponderada)
	out.confidence = confidence_sum / total_weight if total_weight > 0 else 0.1
	out.influence_weight = influence_sum / total_weight if total_weight > 0 else 0.1
	# Timestamp
	out.timestamp = now_ms
	# Flags de segurança (todas as únicas)
	out.safety_flags = _safety_flags_pool.duplicate()
	
	# Dados: médias ponderadas + resolução de conflitos
	out.data = _build_merged_data(contracts, total_weight)
	
	return out

func _merge_priority_max(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	var best: NeutralInfluenceContract = contracts[0]
	var best_score: float = _calculate_priority_score(best)
	for i in range(1, contracts.size()):
		var score = _calculate_priority_score(contracts[i])
		if score > best_score:
			best = contracts[i]
			best_score = score
	var out := _copy_contract(best, now_ms)
	out.safety_flags = _merge_safety_flags(contracts)  # preserva flags de todos
	return out

func _merge_safety_first(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	var safety_contracts: Array[NeutralInfluenceContract] = []
	for c in contracts:
		if not c.safety_flags.is_empty():
			safety_contracts.append(c)
	
	if not safety_contracts.is_empty():
		# Usa média ponderada apenas dos contratos seguros
		var old_strategy = merge_strategy
		merge_strategy = MergeStrategy.WEIGHTED_AVERAGE
		var result = _merge_weighted_average(safety_contracts, now_ms)
		merge_strategy = old_strategy
		result.safety_flags.append(&"safety_first_applied")
		return result
	else:
		# Sem flags de segurança → usa o contrato mais conservador
		return _merge_most_conservative(contracts, now_ms)

func _merge_consensus(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	if contracts.size() < min_contracts_for_consensus:
		return _merge_weighted_average(contracts, now_ms)
	
	var clusters = _cluster_contracts(contracts)
	var largest = clusters[0]
	for i in range(1, clusters.size()):
		if clusters[i].size() > largest.size():
			largest = clusters[i]
	
	var consensus_ratio = float(largest.size()) / float(contracts.size())
	if consensus_ratio >= consensus_threshold:
		var result = _merge_weighted_average(largest, now_ms)
		result.data[&"consensus_ratio"] = consensus_ratio
		result.data[&"consensus_achieved"] = true
		return result
	else:
		# Sem consenso → recai para safety_first
		return _merge_safety_first(contracts, now_ms)

func _merge_most_conservative(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	var out := NeutralInfluenceContract.new()
	out.timestamp = now_ms
	out.safety_flags = _merge_safety_flags(contracts)
	out.confidence = 0.3  # baixa confiança
	
	# Copia valores conservadores dos dados
	var conservative_data := {}
	for c in contracts:
		for key in c.data:
			var val = c.data[key]
			if typeof(val) != TYPE_FLOAT:
				continue
			if not conservative_data.has(key):
				conservative_data[key] = val
			else:
				if key.contains(&"max") or key.contains(&"limit"):
					conservative_data[key] = min(conservative_data[key], val)
				elif key.contains(&"min"):
					conservative_data[key] = max(conservative_data[key], val)
				elif key.contains(&"compression") or key.contains(&"penetration"):
					conservative_data[key] = min(conservative_data[key], val)
				else:
					conservative_data[key] = (conservative_data[key] + val) * 0.5
	out.data = conservative_data
	
	# Autoridade: a maior
	var max_auth = 0
	for c in contracts:
		max_auth = max(max_auth, c.authority)
	out.authority = max_auth
	out.mode = contracts[0].mode  # mantém o modo do primeiro (ou poderia ser o mais frequente)
	return out

# ------------------------------------------------------------------------------
# Métodos Auxiliares (Cálculo de Pesos, Similaridade, Buffers)
# ------------------------------------------------------------------------------
func _calculate_contract_weight(c: NeutralInfluenceContract) -> float:
	var mode_w = c.mode < mode_weights.size() ? mode_weights[c.mode] : 0.5
	var auth_w = c.authority < authority_weights.size() ? authority_weights[c.authority] : 0.5
	var conf_w = c.confidence
	var safety_mult = 1.0 + (safety_priority_multiplier - 1.0) if not c.safety_flags.is_empty() else 1.0
	return (mode_w * 0.4 + auth_w * 0.3 + conf_w * 0.3) * safety_mult

func _calculate_priority_score(c: NeutralInfluenceContract) -> float:
	var mode_w = c.mode < mode_weights.size() ? mode_weights[c.mode] : 0.5
	var auth_w = c.authority < authority_weights.size() ? authority_weights[c.authority] : 0.5
	var safety = 1.0 if not c.safety_flags.is_empty() else 0.5
	return mode_w * auth_w * safety * c.confidence

func _merge_safety_flags(contracts: Array[NeutralInfluenceContract]) -> Array[String]:
	var flags: Array[String] = []
	for c in contracts:
		for f in c.safety_flags:
			if not flags.has(f):
				flags.append(f)
	return flags

func _copy_contract(source: NeutralInfluenceContract, now_ms: int) -> NeutralInfluenceContract:
	var out := NeutralInfluenceContract.new()
	out.mode = source.mode
	out.authority = source.authority
	out.confidence = source.confidence
	out.influence_weight = source.influence_weight
	out.safety_flags = source.safety_flags.duplicate()
	out.data = source.data.duplicate(true)
	out.timestamp = now_ms
	return out

func _build_merged_data(contracts: Array[NeutralInfluenceContract], total_weight: float) -> Dictionary:
	var merged := {}
	for key in _data_accum:
		var acc = _data_accum[key]
		if acc.weight > 0.0:
			var avg = acc.sum / acc.weight
			# Verifica se é um vetor (reconstrução)
			if key.ends_with(&"_x") or key.ends_with(&"_y") or key.ends_with(&"_z"):
				continue  # será tratado no componente principal
			# Tenta reconstruir vetores
			var maybe_vec = _try_reconstruct_vector3(key)
			if maybe_vec != null:
				merged[key] = maybe_vec
			else:
				merged[key] = avg
	
	# Aplica resolução de conflitos onde necessário
	if conflict_resolution != ConflictResolution.AVERAGE:
		_resolve_data_conflicts(merged, contracts)
	return merged

func _try_reconstruct_vector3(base_key: String) -> Variant:
	var x_key = base_key + "_x"
	var y_key = base_key + "_y"
	var z_key = base_key + "_z"
	if _data_accum.has(x_key) and _data_accum.has(y_key) and _data_accum.has(z_key):
		var ax = _data_accum[x_key]
		var ay = _data_accum[y_key]
		var az = _data_accum[z_key]
		if ax.weight > 0 and ay.weight > 0 and az.weight > 0:
			return Vector3(ax.sum / ax.weight, ay.sum / ay.weight, az.sum / az.weight)
	return null

func _resolve_data_conflicts(merged_data: Dictionary, contracts: Array[NeutralInfluenceContract]) -> void:
	for key in merged_data.keys():
		var values := PackedFloat32Array()
		for c in contracts:
			if c.data.has(key) and typeof(c.data[key]) == TYPE_FLOAT:
				values.append(c.data[key])
		if values.size() < 2:
			continue
		# Se houver dispersão significativa
		var avg = values.reduce(func(a,b): return a+b) / values.size()
		var max_dev = 0.0
		for v in values:
			max_dev = max(max_dev, abs(v - avg))
		if max_dev > 0.15:
			match conflict_resolution:
				ConflictResolution.SAFETY:
					merged_data[key] = _resolve_safety(key, values)
				ConflictResolution.HIGHEST_CONFIDENCE:
					merged_data[key] = _resolve_highest_confidence(key, values, contracts)
				# AVERAGE não faz nada

func _resolve_safety(key: String, values: PackedFloat32Array) -> float:
	if key.contains(&"max") or key.contains(&"limit") or key.contains(&"compression") or key.contains(&"penetration"):
		return values.min()
	elif key.contains(&"min"):
		return values.max()
	else:
		return values.reduce(func(a,b): return a+b) / values.size()

func _resolve_highest_confidence(key: String, values: PackedFloat32Array, contracts: Array[NeutralInfluenceContract]) -> float:
	var best_conf = -1.0
	var best_val = values[0]
	for i in contracts.size():
		if contracts[i].confidence > best_conf and contracts[i].data.has(key):
			best_conf = contracts[i].confidence
			best_val = contracts[i].data[key]
	return best_val

func _cluster_contracts(contracts: Array[NeutralInfluenceContract]) -> Array[Array]:
	var clusters: Array[Array] = []
	var assigned := PackedByteArray()
	assigned.resize(contracts.size())
	for i in contracts.size():
		if assigned[i] != 0:
			continue
		var cluster: Array[NeutralInfluenceContract] = [contracts[i]]
		assigned[i] = 1
		for j in range(i+1, contracts.size()):
			if assigned[j] != 0:
				continue
			if _similarity(contracts[i], contracts[j]) >= 0.8:
				cluster.append(contracts[j])
				assigned[j] = 1
		clusters.append(cluster)
	return clusters

func _similarity(a: NeutralInfluenceContract, b: NeutralInfluenceContract) -> float:
	var mode_sim = 1.0 if a.mode == b.mode else 0.0
	var auth_sim = 1.0 - abs(a.authority - b.authority) / 4.0
	return mode_sim * 0.5 + auth_sim * 0.5

func _clear_accumulators() -> void:
	_mode_accum.fill(0.0)
	_authority_accum.fill(0.0)
	_data_accum.clear()
	_safety_flags_pool.clear()

static func _index_of_max_weight(arr: PackedFloat32Array) -> int:
	var idx = 0
	var maxv = arr[0]
	for i in 1..arr.size():
		if arr[i] > maxv:
			maxv = arr[i]
			idx = i
	return idx

static func _vector3_sum(v: Vector3) -> float:
	return v.x + v.y + v.z  # usado apenas para acumulação ponderada