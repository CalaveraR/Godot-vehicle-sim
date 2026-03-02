# res://core/contracts/ContractRateLimiter.gd
class_name ContractRateLimiter
extends Node

# -----------------------------------------------------------------------------
#  RATE LIMITER E VALIDAÇÃO - VERSÃO UNIFICADA (SEM DUPLICAÇÃO DE CLASSE)
# -----------------------------------------------------------------------------
# Responsabilidades:
#   - Controla limites por segundo e cooldowns por modo/autoridade.
#   - Gerencia cache de contratos neutros para fallback quando rate‑limited.
#   - Oferece estatísticas detalhadas para diagnóstico e monitoramento.
#   - Suporta modo adaptativo, cooldown especial para fallback geométrico.
# -----------------------------------------------------------------------------
# Uso típico:
#   var limiter = ContractRateLimiter.new()
#   limiter.set_global_limits(50.0)   # opcional
#   var result = limiter.can_create_contract(mode, authority, Time.get_ticks_msec()/1000.0)
#   if result.can_create:
#       limiter.on_contract_created(mode, authority)
#   else:
#       var neutral = limiter.get_neutral_contract(mode, authority)
# -----------------------------------------------------------------------------

signal rate_limit_check(result: Dictionary)
signal contract_rate_limited(mode: int, authority: int, reason: String)
signal neutral_cache_used(mode: int, authority: int)

# -----------------------------------------------------------------------------
#  ENUMS
# -----------------------------------------------------------------------------
enum LimitationMode {
	LIMIT_NONE,          # Sem limitação
	LIMIT_PER_SECOND,    # Limite por segundo
	LIMIT_COOLDOWN,      # Cooldown fixo entre contratos
	LIMIT_ADAPTIVE       # Limite adaptativo baseado em carga
}

# -----------------------------------------------------------------------------
#  CLASSES INTERNAS (ESTRUTURAS DE DADOS)
# -----------------------------------------------------------------------------
class ModeRateLimit:
	var mode: int
	var max_per_second: float = 10.0
	var cooldown_seconds: float = 0.1
	var priority: int = 0

	func _init(p_mode: int, p_max_per_second: float = 10.0, p_cooldown: float = 0.1, p_priority: int = 0):
		mode = p_mode
		max_per_second = p_max_per_second
		cooldown_seconds = p_cooldown
		priority = p_priority

class AuthorityRateLimit:
	var authority: int
	var max_per_second: float = 5.0
	var cooldown_seconds: float = 0.2

	func _init(p_authority: int, p_max_per_second: float = 5.0, p_cooldown: float = 0.2):
		authority = p_authority
		max_per_second = p_max_per_second
		cooldown_seconds = p_cooldown

# -----------------------------------------------------------------------------
#  PROPRIEDADES DE CONFIGURAÇÃO
# -----------------------------------------------------------------------------
var limitation_mode: int = LimitationMode.LIMIT_PER_SECOND
var mode_limits: Dictionary = {}        # mode -> ModeRateLimit
var authority_limits: Dictionary = {}   # authority -> AuthorityRateLimit
var adaptive_threshold: float = 0.8

# Configurações de cache
var cache_ttl_seconds: float = 5.0
var cache_max_size: int = 10

# Cooldown especial para fallback geométrico
var geometry_fallback_min_interval: float = 0.5
var geometry_fallback_last_used: float = 0.0

# -----------------------------------------------------------------------------
#  ESTATÍSTICAS E ESTADO INTERNO
# -----------------------------------------------------------------------------
var contracts_this_second: Dictionary = {}      # chave -> contagem
var last_contract_time: Dictionary = {}         # chave -> timestamp
var contract_history: Array[Dictionary] = []
var max_history_size: int = 1000

# Cache de contratos neutros
var neutral_contract_cache: Dictionary = {}     # chave -> {contract_data, cache_timestamp, mode, authority}

# Contadores globais
var total_contracts_requested: int = 0
var total_contracts_allowed: int = 0
var total_contracts_limited: int = 0
var total_neutral_caches_used: int = 0

# -----------------------------------------------------------------------------
#  INICIALIZAÇÃO
# -----------------------------------------------------------------------------
func _init() -> void:
	_setup_default_limits()
	_reset_counters()

# -----------------------------------------------------------------------------
#  CONFIGURAÇÃO DE LIMITES PADRÃO
# -----------------------------------------------------------------------------
func _setup_default_limits() -> void:
	# Limites por modo (valores ilustrativos)
	mode_limits[0] = ModeRateLimit.new(0, 20.0, 0.05, 1)   # MODE_CLAMP
	mode_limits[1] = ModeRateLimit.new(1, 15.0, 0.1, 2)    # MODE_BIAS
	mode_limits[2] = ModeRateLimit.new(2, 5.0, 0.2, 3)     # MODE_GEOMETRY_REFERENCE

	# Limites por autoridade
	authority_limits[0] = AuthorityRateLimit.new(0, 100.0, 0.01)  # AUTHORITY_NONE
	authority_limits[1] = AuthorityRateLimit.new(1, 30.0, 0.05)   # AUTHORITY_LOW
	authority_limits[2] = AuthorityRateLimit.new(2, 20.0, 0.1)    # AUTHORITY_MEDIUM
	authority_limits[3] = AuthorityRateLimit.new(3, 10.0, 0.2)    # AUTHORITY_HIGH
	authority_limits[4] = AuthorityRateLimit.new(4, 5.0, 0.5)     # AUTHORITY_CRITICAL

# -----------------------------------------------------------------------------
#  API PÚBLICA PRINCIPAL
# -----------------------------------------------------------------------------
func can_create_contract(mode: int, authority: int, current_time: float = -1.0) -> Dictionary:
	"""
	Verifica se um contrato pode ser criado com base em modo, autoridade e timestamp.
	Retorna um dicionário com:
		- can_create: bool
		- reason: String (se negado)
		- details: Dictionary (informações adicionais)
		- suggested_wait: float (tempo de espera sugerido)
		- neutral_cache_available: bool (se há cache disponível)
	"""
	total_contracts_requested += 1

	if current_time < 0.0:
		current_time = Time.get_ticks_msec() / 1000.0

	_reset_counters()

	# Verificações em ordem de prioridade
	var mode_result = _check_mode_limit(mode, current_time)
	if not mode_result.can_create:
		total_contracts_limited += 1
		return _build_deny_result("mode_limit", mode_result, _get_neutral_cache_available(mode, authority))

	var auth_result = _check_authority_limit(authority, current_time)
	if not auth_result.can_create:
		total_contracts_limited += 1
		return _build_deny_result("authority_limit", auth_result, _get_neutral_cache_available(mode, authority))

	if mode == 2:  # MODE_GEOMETRY_REFERENCE
		var geom_result = _check_geometry_fallback_cooldown(current_time)
		if not geom_result.can_create:
			total_contracts_limited += 1
			return _build_deny_result("geometry_fallback_cooldown", geom_result, true)

	if limitation_mode == LimitationMode.LIMIT_ADAPTIVE:
		var adaptive_result = _check_adaptive_limit(current_time)
		if not adaptive_result.can_create:
			total_contracts_limited += 1
			return _build_deny_result("adaptive_limit", adaptive_result, true)

	# Se passou por todas as verificações
	var key = _get_contract_key(mode, authority)
	contracts_this_second[key] = contracts_this_second.get(key, 0) + 1
	last_contract_time[key] = current_time

	_add_to_history({
		"timestamp": current_time,
		"mode": mode,
		"authority": authority,
		"allowed": true
	})

	total_contracts_allowed += 1

	var result = {
		"can_create": true,
		"reason": "allowed",
		"details": {
			"mode_limit": mode_result,
			"authority_limit": auth_result
		},
		"suggested_wait": 0.0,
		"neutral_cache_available": false
	}
	rate_limit_check.emit(result)
	return result

func check_rate_limit(owner_id: String, mode: int, authority: int, current_time: float = -1.0) -> Dictionary:
	"""Wrapper de compatibilidade com orquestradores legados."""
	var result = can_create_contract(mode, authority, current_time)
	if not result.get("can_create", false):
		contract_rate_limited.emit(mode, authority, result.get("reason", "rate_limited"))
	result["owner_id"] = owner_id
	return result

func on_contract_created(mode: int, authority: int, current_time: float = -1.0) -> void:
	"""
	Registra que um contrato foi efetivamente criado.
	Deve ser chamado imediatamente após a criação bem-sucedida.
	"""
	if current_time < 0.0:
		current_time = Time.get_ticks_msec() / 1000.0

	var key = _get_contract_key(mode, authority)
	contracts_this_second[key] = contracts_this_second.get(key, 0) + 1
	last_contract_time[key] = current_time

	_add_to_history({
		"timestamp": current_time,
		"mode": mode,
		"authority": authority,
		"allowed": true
	})
	total_contracts_allowed += 1

func get_neutral_contract(mode: int, authority: int) -> Dictionary:
	"""
	Retorna um contrato neutro do cache. Se não existir cache válido, cria um fallback.
	Emite o sinal neutral_cache_used quando retorna um cache.
	"""
	var cache_key = _get_cache_key(mode, authority)
	var cached = neutral_contract_cache.get(cache_key, {})

	if not cached.is_empty():
		var current_time = Time.get_ticks_msec() / 1000.0
		var cache_time = cached.get("cache_timestamp", 0.0)

		if current_time - cache_time <= cache_ttl_seconds:
			total_neutral_caches_used += 1
			neutral_cache_used.emit(mode, authority)
			var contract = cached.get("contract_data", {}).duplicate()
			contract["from_cache"] = true
			contract["cache_age"] = current_time - cache_time
			return contract

	return _create_default_neutral_contract(mode, authority)

func cache_neutral_contract(mode: int, authority: int, contract_data: Dictionary) -> void:
	"""
	Armazena um contrato no cache para uso futuro quando rate-limited.
	"""
	var cache_key = _get_cache_key(mode, authority)
	var current_time = Time.get_ticks_msec() / 1000.0

	neutral_contract_cache[cache_key] = {
		"contract_data": contract_data.duplicate(),
		"cache_timestamp": current_time,
		"mode": mode,
		"authority": authority
	}

	if neutral_contract_cache.size() > cache_max_size:
		_prune_oldest_cache_entry()

func set_geometry_fallback_cooldown(cooldown: float) -> void:
	"""Define o intervalo mínimo entre usos do fallback geométrico."""
	geometry_fallback_min_interval = cooldown

func register_geometry_fallback_usage() -> void:
	"""Registra que um fallback geométrico foi utilizado (inicia cooldown)."""
	geometry_fallback_last_used = Time.get_ticks_msec() / 1000.0

func get_diagnostics() -> Dictionary:
	"""Retorna estatísticas completas de uso do rate limiter."""
	var current_time = Time.get_ticks_msec() / 1000.0
	return {
		"total_contracts_requested": total_contracts_requested,
		"total_contracts_allowed": total_contracts_allowed,
		"total_contracts_limited": total_contracts_limited,
		"total_neutral_caches_used": total_neutral_caches_used,
		"current_contracts_per_second": _calculate_current_rate(),
		"cache_size": neutral_contract_cache.size(),
		"cache_hit_rate": _calculate_cache_hit_rate(),
		"time_since_last_contract": _get_time_since_last_contract(current_time),
		"geometry_fallback_cooldown_remaining": max(0.0, geometry_fallback_last_used + geometry_fallback_min_interval - current_time)
	}

func clear_history() -> void:
	"""Limpa todo o histórico e zera os contadores da janela atual."""
	contract_history.clear()
	_reset_counters()

# -----------------------------------------------------------------------------
#  CONFIGURAÇÃO ADICIONAL (SUBSTITUI OS @export)
# -----------------------------------------------------------------------------
func set_global_limits(max_per_second: float) -> void:
	"""Aplica um teto global a todos os limites de modo e autoridade."""
	for mode in mode_limits.keys():
		mode_limits[mode].max_per_second = min(mode_limits[mode].max_per_second, max_per_second)
	for auth in authority_limits.keys():
		authority_limits[auth].max_per_second = min(authority_limits[auth].max_per_second, max_per_second)

func set_cache_config(ttl_seconds: float, max_size: int) -> void:
	"""Configura TTL e tamanho máximo do cache de contratos neutros."""
	cache_ttl_seconds = max(0.1, ttl_seconds)
	cache_max_size = max(1, max_size)

func set_limitation_mode(mode: int) -> void:
	"""Altera o modo de limitação (per_second, cooldown, adaptive, none)."""
	limitation_mode = mode

# -----------------------------------------------------------------------------
#  MÉTODOS INTERNOS DE VERIFICAÇÃO
# -----------------------------------------------------------------------------
func _check_mode_limit(mode: int, current_time: float) -> Dictionary:
	var limit = mode_limits.get(mode)
	if not limit:
		return {"can_create": true, "limit": 0.0, "current": 0, "wait_time": 0.0}

	var key = _get_mode_key(mode)
	var count = contracts_this_second.get(key, 0)

	match limitation_mode:
		LimitationMode.LIMIT_PER_SECOND:
			if count >= limit.max_per_second:
				var wait = 1.0 - (current_time - last_contract_time.get(key, current_time))
				return {"can_create": false, "limit": limit.max_per_second, "current": count, "wait_time": max(0.0, wait)}
		LimitationMode.LIMIT_COOLDOWN:
			var last = last_contract_time.get(key, 0.0)
			var elapsed = current_time - last
			if elapsed < limit.cooldown_seconds:
				return {"can_create": false, "limit": limit.cooldown_seconds, "current": elapsed, "wait_time": limit.cooldown_seconds - elapsed}
	return {"can_create": true, "limit": limit.max_per_second, "current": count, "wait_time": 0.0}

func _check_authority_limit(authority: int, current_time: float) -> Dictionary:
	var limit = authority_limits.get(authority)
	if not limit:
		return {"can_create": true, "limit": 0.0, "current": 0, "wait_time": 0.0}

	var key = _get_authority_key(authority)
	var count = contracts_this_second.get(key, 0)

	match limitation_mode:
		LimitationMode.LIMIT_PER_SECOND:
			if count >= limit.max_per_second:
				var wait = 1.0 - (current_time - last_contract_time.get(key, current_time))
				return {"can_create": false, "limit": limit.max_per_second, "current": count, "wait_time": max(0.0, wait)}
		LimitationMode.LIMIT_COOLDOWN:
			var last = last_contract_time.get(key, 0.0)
			var elapsed = current_time - last
			if elapsed < limit.cooldown_seconds:
				return {"can_create": false, "limit": limit.cooldown_seconds, "current": elapsed, "wait_time": limit.cooldown_seconds - elapsed}
	return {"can_create": true, "limit": limit.max_per_second, "current": count, "wait_time": 0.0}

func _check_geometry_fallback_cooldown(current_time: float) -> Dictionary:
	var elapsed = current_time - geometry_fallback_last_used
	if elapsed < geometry_fallback_min_interval:
		return {"can_create": false, "limit": geometry_fallback_min_interval, "current": elapsed, "wait_time": geometry_fallback_min_interval - elapsed}
	return {"can_create": true, "limit": geometry_fallback_min_interval, "current": elapsed, "wait_time": 0.0}

func _check_adaptive_limit(current_time: float) -> Dictionary:
	var recent = _get_recent_contracts(1.0, current_time)
	var rate = recent.size() as float
	var max_rate = _get_max_theoretical_rate()
	if rate > adaptive_threshold * max_rate:
		var avg_interval = 1.0 / rate if rate > 0 else 0.0
		return {"can_create": false, "limit": adaptive_threshold * max_rate, "current": rate, "wait_time": avg_interval * 2.0}
	return {"can_create": true, "limit": adaptive_threshold * max_rate, "current": rate, "wait_time": 0.0}

# -----------------------------------------------------------------------------
#  MÉTODOS INTERNOS DE UTILIDADE
# -----------------------------------------------------------------------------
func _reset_counters() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var to_remove = []
	for key in contracts_this_second.keys():
		var timestamp = last_contract_time.get(key, 0.0)
		if current_time - timestamp >= 1.0:
			to_remove.append(key)
	for key in to_remove:
		contracts_this_second.erase(key)

func _get_neutral_cache_available(mode: int, authority: int) -> bool:
	var cache_key = _get_cache_key(mode, authority)
	var cached = neutral_contract_cache.get(cache_key, {})
	if cached.is_empty():
		return false
	var current_time = Time.get_ticks_msec() / 1000.0
	var cache_time = cached.get("cache_timestamp", 0.0)
	return (current_time - cache_time) <= cache_ttl_seconds

func _create_default_neutral_contract(mode: int, authority: int) -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	return {
		"mode": mode,
		"authority": authority,
		"influence_weight": 0.1,
		"confidence": 0.1,
		"timestamp": current_time,
		"is_neutral_fallback": true,
		"safety_flags": ["neutral_fallback", "rate_limited"],
		"data": {
			"compression": 0.0,
			"normal": Vector3.UP,
			"contact_width": 0.0,
			"stability_score": 0.0
		}
	}

func _get_contract_key(mode: int, authority: int) -> String:
	return "m%da%d" % [mode, authority]

func _get_mode_key(mode: int) -> String:
	return "mode_%d" % mode

func _get_authority_key(authority: int) -> String:
	return "auth_%d" % authority

func _get_cache_key(mode: int, authority: int) -> String:
	return "cache_m%da%d" % [mode, authority]

func _add_to_history(entry: Dictionary) -> void:
	contract_history.append(entry)
	if contract_history.size() > max_history_size:
		contract_history.remove_at(0)

func _get_recent_contracts(time_window: float, current_time: float) -> Array:
	var recent = []
	for entry in contract_history:
		if current_time - entry.get("timestamp", 0.0) <= time_window:
			recent.append(entry)
	return recent

func _calculate_current_rate() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	return _get_recent_contracts(1.0, current_time).size() as float

func _calculate_cache_hit_rate() -> float:
	if total_contracts_limited == 0:
		return 0.0
	return float(total_neutral_caches_used) / float(total_contracts_limited)

func _get_time_since_last_contract(current_time: float) -> float:
	if last_contract_time.is_empty():
		return 999.0
	var most_recent = 0.0
	for ts in last_contract_time.values():
		if ts > most_recent:
			most_recent = ts
	return current_time - most_recent

func _get_max_theoretical_rate() -> float:
	var min_rate = INF
	for limit in mode_limits.values():
		if limit.max_per_second > 0:
			min_rate = min(min_rate, limit.max_per_second)
	for limit in authority_limits.values():
		if limit.max_per_second > 0:
			min_rate = min(min_rate, limit.max_per_second)
	return min_rate if min_rate != INF else 100.0

func _prune_oldest_cache_entry() -> void:
	if neutral_contract_cache.is_empty():
		return
	var oldest_key = ""
	var oldest_time = INF
	for key in neutral_contract_cache.keys():
		var entry = neutral_contract_cache[key]
		var cache_time = entry.get("cache_timestamp", 0.0)
		if cache_time < oldest_time:
			oldest_time = cache_time
			oldest_key = key
	if oldest_key != "":
		neutral_contract_cache.erase(oldest_key)

func _build_deny_result(reason: String, details: Dictionary, cache_available: bool) -> Dictionary:
	var result = {
		"can_create": false,
		"reason": reason,
		"details": details,
		"suggested_wait": details.get("wait_time", 0.0),
		"neutral_cache_available": cache_available
	}
	contract_rate_limited.emit(details.get("mode", -1), details.get("authority", -1), reason)
	rate_limit_check.emit(result)
	return result
