# res://core/contracts/InfluenceContractBuilder.gd
class_name InfluenceContractBuilder
extends RefCounted

# ------------------------------------------------------------
# Builder centralizado para criação de NeutralInfluenceContract
# Unifica lógica extraída de InfluenceContractOrchestrator e
# RaycastAnchorSystem, garantindo contratos neutros consistentes.
# ------------------------------------------------------------

const NeutralInfluenceContract = preload("res://core/contracts/neutral_influence_contract.gd")

# Autoridades reconhecidas (strings usadas no sistema)
const AUTHORITY_SHADER_PRIMARY   = "shader_primary"
const AUTHORITY_SHADER_LIMITED   = "shader_limited"
const AUTHORITY_GEOMETRY_FALLBACK = "geometry_fallback"

# ------------------------------------------------------------
# Método principal – constrói contrato a partir de um dicionário de decisão
# ------------------------------------------------------------
func build_from_decision(
	authority_decision: Dictionary,
	geometry_data: Dictionary,
	timestamp_ms: int
) -> NeutralInfluenceContract:
	"""
	Constrói contrato usando decisão de autoridade já processada.
	Espera authority_decision com pelo menos a chave 'level'.
	"""
	var level = authority_decision.get("level", AUTHORITY_SHADER_LIMITED)
	var shader_state = authority_decision.get("shader_state", {})
	return build(shader_state, geometry_data, level, timestamp_ms)

# ------------------------------------------------------------
# Método principal – constrói contrato com parâmetros explícitos
# ------------------------------------------------------------
func build(
	shader_state: Dictionary,
	geometry_data: Dictionary,
	authority_level: String,
	timestamp_ms: int
) -> NeutralInfluenceContract:
	"""
	Cria e configura completamente um NeutralInfluenceContract.
	"""
	var contract = NeutralInfluenceContract.new(timestamp_ms)
	contract.contract_id = _create_contract_id(timestamp_ms)
	contract.authority_level = authority_level

	# Garantir que os dicionários existam
	contract.allowed_operations = {}
	contract.operational_values = {}
	contract.diagnostic = {}

	# Configurar modo, operações permitidas e valores físicos
	_configure_contract_mode(contract, authority_level, geometry_data)
	_set_allowed_operations(contract, authority_level)
	_set_operational_values(contract, geometry_data)

	# Preencher diagnóstico
	_set_diagnostic(contract, shader_state, geometry_data, authority_level)

	return contract

# ------------------------------------------------------------
# Cria um identificador único para o contrato
# ------------------------------------------------------------
func _create_contract_id(timestamp: int) -> String:
	return "geometry_contract_%d" % timestamp

# ------------------------------------------------------------
# Define o modo de operação e ação sugerida com base na autoridade
# ------------------------------------------------------------
func _configure_contract_mode(
	contract: NeutralInfluenceContract,
	authority: String,
	geometry: Dictionary
) -> void:
	match authority:
		AUTHORITY_SHADER_PRIMARY:
			contract.operation_mode = "none"
			contract.diagnostic["suggested_action"] = "none"

		AUTHORITY_SHADER_LIMITED:
			contract.operation_mode = "clamp"
			contract.diagnostic["suggested_action"] = "apply_physical_limits"

		AUTHORITY_GEOMETRY_FALLBACK:
			contract.operation_mode = "geometry_reference"
			contract.diagnostic["suggested_action"] = "use_reference_only"

		_:
			# Fallback seguro
			contract.operation_mode = "clamp"
			contract.diagnostic["suggested_action"] = "fallback"

# ------------------------------------------------------------
# Define quais operações são permitidas (baseado na autoridade)
# ------------------------------------------------------------
func _set_allowed_operations(
	contract: NeutralInfluenceContract,
	authority: String
) -> void:
	var base_ops = {
		"modify_penetration": false,
		"modify_confidence": false,
		"modify_contact_width": false,
		"modify_normal": false,
		"modify_regions": false,
		"suggest_timing": false
	}

	match authority:
		AUTHORITY_SHADER_PRIMARY:
			contract.allowed_operations = base_ops.duplicate()

		AUTHORITY_SHADER_LIMITED:
			contract.allowed_operations = base_ops.duplicate()
			contract.allowed_operations["modify_penetration"] = true
			contract.allowed_operations["modify_confidence"] = true
			contract.allowed_operations["modify_contact_width"] = true
			contract.allowed_operations["suggest_timing"] = true

		AUTHORITY_GEOMETRY_FALLBACK:
			contract.allowed_operations = base_ops.duplicate()
			contract.allowed_operations["suggest_timing"] = true

		_:
			contract.allowed_operations = base_ops.duplicate()

# ------------------------------------------------------------
# Preenche os valores operacionais (limites físicos, plano de referência)
# ------------------------------------------------------------
func _set_operational_values(
	contract: NeutralInfluenceContract,
	geometry: Dictionary
) -> void:
	var constraints = geometry.get("physical_constraints", {})

	contract.operational_values = {
		"max_penetration": constraints.get("max_penetration", 0.2),
		"min_confidence": 0.3,
		"max_contact_width": constraints.get("max_contact_width", 0.3),
		"reference_plane": {
			"normal": constraints.get("reference_plane_normal", Vector3.UP),
			"height": constraints.get("reference_plane_height", 0.0)
		}
	}

# ------------------------------------------------------------
# Preenche o bloco de diagnóstico do contrato
# ------------------------------------------------------------
func _set_diagnostic(
	contract: NeutralInfluenceContract,
	shader: Dictionary,
	geometry: Dictionary,
	authority: String
) -> void:
	contract.diagnostic = {
		"shader_confidence": shader.get("confidence", 0.0),
		"plausibility_score": _calculate_plausibility_score(shader, geometry),
		"requires_attention": authority != AUTHORITY_SHADER_PRIMARY,
		"suggested_action": contract.diagnostic.get("suggested_action", "")
	}

# ------------------------------------------------------------
# Calcula pontuação de plausibilidade (0-1) – mesmo algoritmo do orchestrator
# ------------------------------------------------------------
func _calculate_plausibility_score(shader: Dictionary, geometry: Dictionary) -> float:
	var score = 1.0

	# Discordância na existência de contato
	var has_geom_contact = geometry.get("has_contact", false)
	var has_shader_contact = shader.get("has_contact", false)
	if has_geom_contact != has_shader_contact:
		score *= 0.7

	# Penetração fisicamente implausível
	if geometry.has("physical_constraints"):
		var shader_pen = shader.get("avg_penetration", 0.0)
		var max_pen = geometry["physical_constraints"].get("max_penetration", INF)
		if shader_pen > max_pen * 1.5:
			score *= 0.6

	return clamp(score, 0.0, 1.0)