# res://core/contracts/ContractMerger.gd
class_name ContractMerger
extends Node

# ------------------------------------------------------------------------------
# Enums
# ------------------------------------------------------------------------------
enum MergeStrategy {
	WEIGHTED_AVERAGE,
	PRIORITY_MAX,
	SAFETY_FIRST,
	CONSENSUS,
}

enum ConflictResolution {
	AVERAGE,
	SAFETY,
	HIGHEST_CONFIDENCE,
}

# ------------------------------------------------------------------------------
# Configurações
# ------------------------------------------------------------------------------
var merge_strategy: MergeStrategy = MergeStrategy.WEIGHTED_AVERAGE
var conflict_resolution: ConflictResolution = ConflictResolution.SAFETY
var min_contracts_for_consensus: int = 2
var consensus_threshold: float = 0.7

signal contracts_merged(result: Dictionary)

const _MODE_ORDER := ["none", "clamp", "bias", "geometry_reference"]
const _AUTHORITY_ORDER := ["shader_primary", "shader_limited", "geometry_fallback"]

# ------------------------------------------------------------------------------
# API pública
# ------------------------------------------------------------------------------
func merge(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	if contracts.is_empty():
		return force_recovery(now_ms)

	var valid: Array[NeutralInfluenceContract] = []
	for c in contracts:
		if c and c.validate_structure() and not c.is_expired(now_ms):
			valid.append(c)

	if valid.is_empty():
		return force_recovery(now_ms)
	if valid.size() == 1:
		return valid[0].clone_as_new(now_ms)

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
		"merged_contract": merged_contract.to_dict(),
		"merge_strategy": merge_strategy,
		"timestamp": now_ms
	}
	contracts_merged.emit(result)
	return result

func force_recovery(now_ms: int) -> NeutralInfluenceContract:
	var out := NeutralInfluenceContract.create_minimal(now_ms)
	out.contract_id = "merge_fallback_%d" % now_ms
	out.authority_level = "shader_limited"
	out.operation_mode = "clamp"
	out.allowed_operations = {
		"modify_penetration": true,
		"modify_confidence": true,
		"modify_contact_width": true,
		"modify_normal": false,
		"modify_regions": false,
		"suggest_timing": true
	}
	out.operational_values = {
		"max_penetration": 0.0,
		"min_confidence": 0.0,
		"max_contact_width": 0.0,
		"reference_plane": {
			"normal": Vector3.UP,
			"height": 0.0
		}
	}
	out.operation_weights = {
		"penetration_weight": 0.0,
		"confidence_weight": 0.0,
		"width_weight": 0.0,
		"temporal_weight": 0.0
	}
	out.diagnostic = {
		"shader_confidence": 0.0,
		"plausibility_score": 0.0,
		"requires_attention": true,
		"suggested_action": "merge_fallback"
	}
	out.safety_flags = {
		"never_modifies_normals": true,
		"never_generates_forces": true,
		"never_replaces_shader": true,
		"origin_agnostic": true
	}
	out.expires_at_ms = now_ms + 100
	return out

# ------------------------------------------------------------------------------
# Estratégias
# ------------------------------------------------------------------------------
func _merge_weighted_average(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	var out := NeutralInfluenceContract.create_minimal(now_ms)
	out.contract_id = "merged_weighted_%d" % now_ms

	var total_weight: float = 0.0
	var mode_scores: Dictionary = {}
	var authority_scores: Dictionary = {}
	var op_weights_acc := {
		"penetration_weight": 0.0,
		"confidence_weight": 0.0,
		"width_weight": 0.0,
		"temporal_weight": 0.0
	}
	var shader_conf_acc: float = 0.0
	var plausibility_acc: float = 0.0
	var requires_attention_any: bool = false

	for c in contracts:
		var w := _contract_weight(c)
		total_weight += w

		var mode := c.operation_mode
		mode_scores[mode] = mode_scores.get(mode, 0.0) + w

		var auth := c.authority_level
		authority_scores[auth] = authority_scores.get(auth, 0.0) + w

		for key in op_weights_acc.keys():
			op_weights_acc[key] += float(c.operation_weights.get(key, 0.0)) * w

		shader_conf_acc += float(c.diagnostic.get("shader_confidence", 0.0)) * w
		plausibility_acc += float(c.diagnostic.get("plausibility_score", 0.0)) * w
		requires_attention_any = requires_attention_any or bool(c.diagnostic.get("requires_attention", false))

	if total_weight <= 0.0:
		return force_recovery(now_ms)

	out.operation_mode = _pick_max_key(mode_scores, "clamp")
	out.authority_level = _pick_max_key(authority_scores, "shader_limited")

	var merged_allowed = _merge_allowed_operations(contracts)
	if conflict_resolution == ConflictResolution.SAFETY:
		merged_allowed["modify_penetration"] = false
		merged_allowed["modify_contact_width"] = false
	out.allowed_operations = merged_allowed

	out.operational_values = _merge_operational_values(contracts)
	for key in op_weights_acc.keys():
		out.operation_weights[key] = clamp(op_weights_acc[key] / total_weight, 0.0, 1.0)

	out.diagnostic = {
		"shader_confidence": shader_conf_acc / total_weight,
		"plausibility_score": plausibility_acc / total_weight,
		"requires_attention": requires_attention_any,
		"suggested_action": "merged_%s" % out.operation_mode
	}
	out.safety_flags = _merge_safety_flags(contracts)
	out.expires_at_ms = now_ms + _min_remaining_ttl(contracts, now_ms)
	return out

func _merge_priority_max(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	var best := contracts[0]
	var best_score := _priority_score(best)
	for i in range(1, contracts.size()):
		var score := _priority_score(contracts[i])
		if score > best_score:
			best = contracts[i]
			best_score = score
	var out := best.clone_as_new(now_ms)
	out.contract_id = "merged_priority_%d" % now_ms
	out.safety_flags = _merge_safety_flags(contracts)
	out.expires_at_ms = now_ms + _min_remaining_ttl(contracts, now_ms)
	return out

func _merge_safety_first(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	var safe: Array[NeutralInfluenceContract] = []
	for c in contracts:
		if c.safety_flags.get("never_modifies_normals", false) and c.safety_flags.get("origin_agnostic", false):
			safe.append(c)
	if safe.is_empty():
		return _merge_priority_max(contracts, now_ms)
	return _merge_weighted_average(safe, now_ms)

func _merge_consensus(contracts: Array[NeutralInfluenceContract], now_ms: int) -> NeutralInfluenceContract:
	if contracts.size() < min_contracts_for_consensus:
		return _merge_weighted_average(contracts, now_ms)

	var by_mode: Dictionary = {}
	for c in contracts:
		var key := c.operation_mode
		if not by_mode.has(key):
			by_mode[key] = []
		by_mode[key].append(c)

	var largest_key := ""
	var largest_size := 0
	for key in by_mode.keys():
		var size := (by_mode[key] as Array).size()
		if size > largest_size:
			largest_size = size
			largest_key = key

	var ratio := float(largest_size) / float(contracts.size())
	if ratio >= consensus_threshold:
		return _merge_weighted_average(by_mode[largest_key], now_ms)
	return _merge_safety_first(contracts, now_ms)

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
func _contract_weight(c: NeutralInfluenceContract) -> float:
	var mode_weight := float(_MODE_ORDER.find(c.operation_mode) + 1) / float(_MODE_ORDER.size())
	var authority_weight := float(_AUTHORITY_ORDER.find(c.authority_level) + 1) / float(_AUTHORITY_ORDER.size())
	var plausibility := clamp(float(c.diagnostic.get("plausibility_score", 0.5)), 0.0, 1.0)
	return (mode_weight * 0.35 + authority_weight * 0.35 + plausibility * 0.30)

func _priority_score(c: NeutralInfluenceContract) -> float:
	var score := _contract_weight(c)
	if c.safety_flags.get("never_modifies_normals", false):
		score += 0.1
	if c.safety_flags.get("origin_agnostic", false):
		score += 0.1
	return score

func _merge_allowed_operations(contracts: Array[NeutralInfluenceContract]) -> Dictionary:
	var merged := {
		"modify_penetration": false,
		"modify_confidence": false,
		"modify_contact_width": false,
		"modify_normal": false,
		"modify_regions": false,
		"suggest_timing": false
	}
	for c in contracts:
		for key in merged.keys():
			merged[key] = bool(merged[key]) or bool(c.allowed_operations.get(key, false))
	merged["modify_normal"] = false
	return merged

func _merge_operational_values(contracts: Array[NeutralInfluenceContract]) -> Dictionary:
	var max_pen := INF
	var min_conf := 0.0
	var max_width := INF
	var plane_height := 0.0
	var plane_normal := Vector3.UP
	var count := 0.0

	for c in contracts:
		max_pen = min(max_pen, float(c.operational_values.get("max_penetration", 0.0)))
		min_conf = max(min_conf, float(c.operational_values.get("min_confidence", 0.0)))
		max_width = min(max_width, float(c.operational_values.get("max_contact_width", 0.0)))
		var plane = c.operational_values.get("reference_plane", {})
		if plane is Dictionary:
			plane_height += float(plane.get("height", 0.0))
			var n = plane.get("normal", Vector3.UP)
			if n is Vector3:
				plane_normal += n
		count += 1.0

	if max_pen == INF:
		max_pen = 0.0
	if max_width == INF:
		max_width = 0.0
	if count <= 0.0:
		count = 1.0

	return {
		"max_penetration": max_pen,
		"min_confidence": min_conf,
		"max_contact_width": max_width,
		"reference_plane": {
			"normal": plane_normal.normalized(),
			"height": plane_height / count
		}
	}

func _merge_safety_flags(contracts: Array[NeutralInfluenceContract]) -> Dictionary:
	var merged := {
		"never_modifies_normals": true,
		"never_generates_forces": true,
		"never_replaces_shader": true,
		"origin_agnostic": true
	}
	for c in contracts:
		for key in merged.keys():
			merged[key] = bool(merged[key]) and bool(c.safety_flags.get(key, false))
	return merged

func _min_remaining_ttl(contracts: Array[NeutralInfluenceContract], now_ms: int) -> int:
	var ttl := 100
	for c in contracts:
		ttl = min(ttl, c.get_remaining_validity_ms(now_ms))
	return max(ttl, 10)

func _pick_max_key(scores: Dictionary, fallback: String) -> String:
	if scores.is_empty():
		return fallback
	var best_key: String = scores.keys()[0]
	var best_val: float = float(scores[best_key])
	for key in scores.keys():
		var v := float(scores[key])
		if v > best_val:
			best_key = key
			best_val = v
	return best_key
