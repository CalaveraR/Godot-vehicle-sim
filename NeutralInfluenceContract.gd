# NeutralInfluenceContract.gd
# Versão unificada e definitiva – única fonte da verdade.
# Purista: não chama Time.get_ticks_msec() nem acessa estado global.
# Todos os timestamps são fornecidos pelo caller.

class_name NeutralInfluenceContract
extends RefCounted

# -------------------------------------------------------------------------- #
# METADATA
# -------------------------------------------------------------------------- #
var contract_id: String = "anonymous_contract"
var version: String = "1.0"

# Identidade temporal (sempre fornecida externamente)
var created_at_ms: int = 0
var expires_at_ms: int = 0

# -------------------------------------------------------------------------- #
# AUTORIDADE E MODO DE OPERAÇÃO
# -------------------------------------------------------------------------- #
var authority_level: String = "shader_primary"   # "shader_primary" | "shader_limited" | "geometry_fallback"
var operation_mode: String = "none"              # "none" | "clamp" | "bias" | "geometry_reference"

# -------------------------------------------------------------------------- #
# PERMISSÕES OPERACIONAIS (booleans)
# -------------------------------------------------------------------------- #
var allowed_operations: Dictionary = {
    "modify_penetration": false,
    "modify_confidence": false,
    "modify_contact_width": false,
    "modify_normal": false,      # SEMPRE false por filosofia
    "modify_regions": false,
    "suggest_timing": false
}

# -------------------------------------------------------------------------- #
# VALORES OPERACIONAIS (limites, planos de referência)
# -------------------------------------------------------------------------- #
var operational_values: Dictionary = {
    "max_penetration": 0.0,
    "min_confidence": 0.0,
    "max_contact_width": 0.0,
    "reference_plane": {
        "normal": Vector3.UP,
        "height": 0.0
    }
}

# -------------------------------------------------------------------------- #
# PESOS FORMALIZADOS (normalizados para [0,1])
# -------------------------------------------------------------------------- #
var operation_weights: Dictionary = {
    "penetration_weight": 0.0,
    "confidence_weight": 0.0,
    "width_weight": 0.0,
    "temporal_weight": 0.0
}

# -------------------------------------------------------------------------- #
# REGRAS DETERMINÍSTICAS (fórmulas explícitas)
# -------------------------------------------------------------------------- #
var formal_rules: Dictionary = {
    "penetration_rule": "lerp(shader_pen, operational_values.max_penetration, penetration_weight)",
    "confidence_rule": "max(shader_conf, operational_values.min_confidence)",
    "width_rule": "min(shader_width, operational_values.max_contact_width)",
    "validity_rule": "created_at_ms < expires_at_ms"
}

# -------------------------------------------------------------------------- #
# DIAGNÓSTICO (telemetria opcional)
# -------------------------------------------------------------------------- #
var diagnostic: Dictionary = {
    "shader_confidence": 0.0,
    "plausibility_score": 1.0,
    "requires_attention": false,
    "suggested_action": "none"
}

# -------------------------------------------------------------------------- #
# FLAGS DE SEGURANÇA (garantem neutralidade)
# -------------------------------------------------------------------------- #
var safety_flags: Dictionary = {
    "never_modifies_normals": true,
    "never_generates_forces": true,
    "never_replaces_shader": true,
    "origin_agnostic": true
}

# ========================================================================== #
# CONSTRUTOR
# ========================================================================== #

func _init(created_at_ms: int) -> void:
    """Inicializa o contrato com o timestamp de criação fornecido.
    Nunca consulta o relógio global."""
    if created_at_ms <= 0:
        push_error("NeutralInfluenceContract: created_at_ms deve ser > 0, recebido %d" % created_at_ms)
        created_at_ms = 1
    self.created_at_ms = created_at_ms
    self.expires_at_ms = created_at_ms + 100   # validade padrão: 100ms

# ========================================================================== #
# VALIDAÇÃO TEMPORAL
# ========================================================================== #

func is_expired(now_ms: int) -> bool:
    """Retorna true se o contrato expirou no momento `now_ms`."""
    return now_ms > self.expires_at_ms

func is_valid_at(now_ms: int) -> bool:
    """Valida estrutura e expiração."""
    return (not self.is_expired(now_ms)) and self.validate_structure()

func get_remaining_validity_ms(now_ms: int) -> int:
    """Tempo restante de validade em milissegundos."""
    return max(0, self.expires_at_ms - now_ms)

# ========================================================================== #
# VALIDAÇÃO ESTRUTURAL (sem dependência temporal)
# ========================================================================== #

func validate_structure() -> bool:
    """Valida toda a estrutura do contrato, exceto tempo.
    Retorna false se qualquer violação for encontrada."""
    # 1. Filosofia fundamental: NUNCA modificar normais
    if self.allowed_operations.get("modify_normal", false):
        return false

    # 2. Chaves obrigatórias em allowed_operations
    var required_allowed_ops = ["modify_penetration", "modify_confidence", "modify_contact_width",
                                "modify_normal", "modify_regions", "suggest_timing"]
    if not _has_required_keys(self.allowed_operations, required_allowed_ops):
        return false

    # 3. Chaves obrigatórias em operational_values
    var required_operational_keys = ["max_penetration", "min_confidence", "max_contact_width", "reference_plane"]
    if not _has_required_keys(self.operational_values, required_operational_keys):
        return false

    # 4. Validação do reference_plane
    var plane = self.operational_values.get("reference_plane", {})
    if not (plane is Dictionary):
        return false
    if not _has_required_keys(plane, ["normal", "height"]):
        return false
    if not (plane.get("normal") is Vector3):
        return false
    var height = plane.get("height")
    if typeof(height) != TYPE_FLOAT and typeof(height) != TYPE_INT:
        return false

    # 5. Chaves obrigatórias em operation_weights
    var required_weight_keys = ["penetration_weight", "confidence_weight", "width_weight", "temporal_weight"]
    if not _has_required_keys(self.operation_weights, required_weight_keys):
        return false

    # 6. Pesos devem estar em [0,1] (int ou float)
    for key in required_weight_keys:
        var w = self.operation_weights.get(key, 0.0)
        if typeof(w) != TYPE_FLOAT and typeof(w) != TYPE_INT:
            return false
        var wf := float(w)
        if wf < 0.0 or wf > 1.0:
            return false

    # 7. Chaves obrigatórias em formal_rules
    var required_rule_keys = ["penetration_rule", "confidence_rule", "width_rule", "validity_rule"]
    if not _has_required_keys(self.formal_rules, required_rule_keys):
        return false

    # 8. Chaves obrigatórias em safety_flags
    var required_safety_keys = ["never_modifies_normals", "never_generates_forces", "never_replaces_shader", "origin_agnostic"]
    if not _has_required_keys(self.safety_flags, required_safety_keys):
        return false

    # 9. Flags de segurança obrigatórias (devem ser true)
    if self.safety_flags.get("never_modifies_normals", false) != true:
        return false
    if self.safety_flags.get("origin_agnostic", false) != true:
        return false

    # 10. authority_level deve ser um valor válido
    var valid_authorities = ["shader_primary", "shader_limited", "geometry_fallback"]
    if not valid_authorities.has(self.authority_level):
        return false

    # 11. operation_mode deve ser um valor válido
    var valid_modes = ["none", "clamp", "bias", "geometry_reference"]
    if not valid_modes.has(self.operation_mode):
        return false

    # 12. Verificação de integridade temporal (expiração posterior à criação)
    if self.expires_at_ms <= self.created_at_ms:
        return false

    # 13. Tipos do dicionário diagnostic (se presentes, aceita null)
    var diagnostic_type_map = {
        "shader_confidence": TYPE_FLOAT,
        "plausibility_score": TYPE_FLOAT,
        "requires_attention": TYPE_BOOL,
        "suggested_action": TYPE_STRING
    }
    if not _validate_dictionary_types(self.diagnostic, diagnostic_type_map):
        return false

    return true

# ========================================================================== #
# HELPERS DE VALIDAÇÃO (privados)
# ========================================================================== #

func _has_required_keys(d: Dictionary, required_keys: Array[String]) -> bool:
    for key in required_keys:
        if not d.has(key):
            return false
    return true

func _validate_dictionary_types(d: Dictionary, type_map: Dictionary) -> bool:
    for key in type_map.keys():
        if d.has(key):
            var val = d[key]
            if val == null:
                continue   # null é aceito (telemetria opcional)
            if typeof(val) != type_map[key]:
                return false
    return true

# ========================================================================== #
# CLONAGEM
# ========================================================================== #

func clone() -> NeutralInfluenceContract:
    """Cria cópia exata (mesmo created_at_ms e expires_at_ms)."""
    var new_contract = NeutralInfluenceContract.new(self.created_at_ms)
    new_contract.contract_id = self.contract_id
    new_contract.version = self.version
    new_contract.expires_at_ms = self.expires_at_ms
    new_contract.authority_level = self.authority_level
    new_contract.operation_mode = self.operation_mode
    new_contract.allowed_operations = self.allowed_operations.duplicate(true)
    new_contract.operational_values = self.operational_values.duplicate(true)
    new_contract.operation_weights = self.operation_weights.duplicate(true)
    new_contract.formal_rules = self.formal_rules.duplicate(true)
    new_contract.diagnostic = self.diagnostic.duplicate(true)
    new_contract.safety_flags = self.safety_flags.duplicate(true)
    return new_contract

func clone_as_new(new_created_at_ms: int) -> NeutralInfluenceContract:
    """Cria cópia como um novo contrato (novo timestamp e novo ID)."""
    var new_contract = NeutralInfluenceContract.new(new_created_at_ms)
    new_contract.contract_id = "cloned_" + str(new_created_at_ms)
    new_contract.version = self.version
    new_contract.authority_level = self.authority_level
    new_contract.operation_mode = self.operation_mode
    new_contract.allowed_operations = self.allowed_operations.duplicate(true)
    new_contract.operational_values = self.operational_values.duplicate(true)
    new_contract.operation_weights = self.operation_weights.duplicate(true)
    new_contract.formal_rules = self.formal_rules.duplicate(true)
    new_contract.diagnostic = self.diagnostic.duplicate(true)
    new_contract.safety_flags = self.safety_flags.duplicate(true)
    return new_contract

# ========================================================================== #
# SERIALIZAÇÃO
# ========================================================================== #

func to_dict() -> Dictionary:
    """Retorna representação em dicionário, sem referências à origem."""
    return {
        "contract_type": "neutral_influence_contract",
        "contract_id": self.contract_id,
        "version": self.version,
        "created_at_ms": self.created_at_ms,
        "expires_at_ms": self.expires_at_ms,
        "authority_level": self.authority_level,
        "operation_mode": self.operation_mode,
        "allowed_operations": self.allowed_operations.duplicate(true),
        "operational_values": self.operational_values.duplicate(true),
        "operation_weights": self.operation_weights.duplicate(true),
        "formal_rules": self.formal_rules.duplicate(true),
        "diagnostic": self.diagnostic.duplicate(true),
        "safety_flags": self.safety_flags.duplicate(true)
    }

# ========================================================================== #
# DIAGNÓSTICO E FILOSOFIA
# ========================================================================== #

func get_philosophy_validation(now_ms: int) -> Dictionary:
    """Retorna status de aderência à filosofia do contrato."""
    return {
        "sovereignty_respected": not self.allowed_operations.get("modify_normal", false),
        "origin_neutral": self.safety_flags.get("origin_agnostic", false) == true,
        "deterministic": self.formal_rules.size() > 0,
        "expires_soon": self.get_remaining_validity_ms(now_ms) < 50,
        "structural_integrity": self.validate_structure(),
        "temporal_validity": not self.is_expired(now_ms)
    }

func get_expiration_info(now_ms: int) -> Dictionary:
    """Informações detalhadas sobre expiração (protegido contra divisão por zero)."""
    var remaining = self.get_remaining_validity_ms(now_ms)
    var total_lifetime = max(1, self.expires_at_ms - self.created_at_ms)
    var lifetime_used = total_lifetime - remaining
    return {
        "remaining_ms": remaining,
        "lifetime_used_ms": lifetime_used,
        "total_lifetime_ms": total_lifetime,
        "is_expired": self.is_expired(now_ms),
        "percent_used": float(lifetime_used) / float(total_lifetime) * 100.0,
        "created_at_ms": self.created_at_ms,
        "expires_at_ms": self.expires_at_ms,
        "now_ms": now_ms
    }

func get_optional_diagnostic() -> Dictionary:
    """Retorna apenas chaves de diagnostic que não são null."""
    var result = {}
    for key in ["shader_confidence", "plausibility_score", "requires_attention", "suggested_action"]:
        if self.diagnostic.has(key) and self.diagnostic[key] != null:
            result[key] = self.diagnostic[key]
    return result

# ========================================================================== #
# MÉTODOS ESTÁTICOS – CRIAÇÃO E NORMALIZAÇÃO
# ========================================================================== #

static func create_minimal(created_at_ms: int) -> NeutralInfluenceContract:
    """Cria um contrato mínimo, porém estruturalmente válido."""
    var ts := created_at_ms
    if ts <= 0:
        ts = 1
        push_warning("NeutralInfluenceContract.create_minimal: timestamp inválido (%d), usando 1" % created_at_ms)
    var contract = NeutralInfluenceContract.new(ts)
    contract.contract_id = "minimal_contract_" + str(ts)
    contract.authority_level = "shader_primary"
    contract.operation_mode = "none"
    contract.diagnostic["suggested_action"] = "minimal_contract"
    return contract

static func create_from_dict(data: Dictionary) -> NeutralInfluenceContract:
    """Reconstitui um contrato a partir de dicionário (serialização).
    Suporta chave 'created_at_ms' ou 'timestamp' (fallback)."""
    # 1. Extrair timestamp de criação
    var ts: int
    if data.has("created_at_ms"):
        ts = _safe_int(data["created_at_ms"], 1)
    elif data.has("timestamp"):
        ts = _safe_int(data["timestamp"], 1)
        push_warning("NeutralInfluenceContract.create_from_dict: usando 'timestamp' obsoleto, prefira 'created_at_ms'")
    else:
        push_error("NeutralInfluenceContract.create_from_dict: campo 'created_at_ms' ou 'timestamp' obrigatório")
        return create_minimal(1)

    if ts <= 0:
        ts = 1

    var contract = NeutralInfluenceContract.new(ts)

    # 2. Propriedades escalares
    if data.has("contract_id"):
        contract.contract_id = str(data["contract_id"])
    if data.has("version"):
        contract.version = str(data["version"])

    # expires_at_ms: se não existir, calcula padrão
    if data.has("expires_at_ms"):
        contract.expires_at_ms = _safe_int(data["expires_at_ms"], contract.created_at_ms + 100)
    elif data.has("expires_at"):   # compatibilidade
        contract.expires_at_ms = _safe_int(data["expires_at"], contract.created_at_ms + 100)
        push_warning("NeutralInfluenceContract.create_from_dict: usando 'expires_at' obsoleto, prefira 'expires_at_ms'")
    else:
        contract.expires_at_ms = contract.created_at_ms + 100

    # authority_level e operation_mode
    if data.has("authority_level"):
        contract.authority_level = str(data["authority_level"])
    elif data.has("authority"):    # compatibilidade com schema antigo
        contract.authority_level = str(data["authority"])
        push_warning("NeutralInfluenceContract.create_from_dict: usando 'authority' obsoleto, prefira 'authority_level'")

    if data.has("operation_mode"):
        contract.operation_mode = str(data["operation_mode"])

    # 3. Dicionários aninhados (deep copy)
    if data.has("allowed_operations") and data["allowed_operations"] is Dictionary:
        contract.allowed_operations = data["allowed_operations"].duplicate(true)

    if data.has("operational_values") and data["operational_values"] is Dictionary:
        contract.operational_values = data["operational_values"].duplicate(true)
        # Normalizar reference_plane.normal para Vector3
        if contract.operational_values.has("reference_plane"):
            var plane = contract.operational_values["reference_plane"]
            if plane is Dictionary and plane.has("normal"):
                plane["normal"] = _safe_vector3(plane["normal"])

    if data.has("operation_weights") and data["operation_weights"] is Dictionary:
        contract.operation_weights = data["operation_weights"].duplicate(true)
        # Normalizar pesos para [0,1]
        for k in ["penetration_weight", "confidence_weight", "width_weight", "temporal_weight"]:
            if contract.operation_weights.has(k):
                contract.operation_weights[k] = normalize_weight(contract.operation_weights[k])

    if data.has("formal_rules") and data["formal_rules"] is Dictionary:
        contract.formal_rules = data["formal_rules"].duplicate(true)

    if data.has("diagnostic") and data["diagnostic"] is Dictionary:
        contract.diagnostic = data["diagnostic"].duplicate(true)

    if data.has("safety_flags") and data["safety_flags"] is Dictionary:
        contract.safety_flags = data["safety_flags"].duplicate(true)

    # 4. Correção de segurança: expires_at_ms > created_at_ms
    if contract.expires_at_ms <= contract.created_at_ms:
        push_warning("NeutralInfluenceContract.create_from_dict: expires_at_ms <= created_at_ms, ajustando para +100ms")
        contract.expires_at_ms = contract.created_at_ms + 100

    return contract

static func create_validation_report(contract: NeutralInfluenceContract, now_ms: int) -> Dictionary:
    """Relatório completo de validação para depuração."""
    return {
        "contract_id": contract.contract_id,
        "created_at_ms": contract.created_at_ms,
        "expires_at_ms": contract.expires_at_ms,
        "now_ms": now_ms,
        "is_expired": contract.is_expired(now_ms),
        "structure_valid": contract.validate_structure(),
        "philosophy_validation": contract.get_philosophy_validation(now_ms),
        "expiration_info": contract.get_expiration_info(now_ms),
        "diagnostic_summary": contract.get_optional_diagnostic()
    }

# -------------------------------------------------------------------------- #
# UTILITÁRIOS ESTÁTICOS (normalização/conversão)
# -------------------------------------------------------------------------- #

static func normalize_weight(value) -> float:
    """Converte qualquer valor numérico (int, float, string) para float em [0,1]."""
    var t := typeof(value)
    var f := 0.0

    if t == TYPE_FLOAT or t == TYPE_INT:
        f = float(value)
    elif t == TYPE_STRING:
        var s := String(value).strip_edges()
        if s.is_valid_float():
            f = float(s)
        elif s.is_valid_int():
            f = float(int(s))
        else:
            return 0.0
    else:
        return 0.0

    return clamp(f, 0.0, 1.0)

static func _safe_int(value, fallback: int = 1) -> int:
    """Converte com segurança qualquer valor para int."""
    var t := typeof(value)
    match t:
        TYPE_INT:
            return int(value)
        TYPE_FLOAT:
            return int(value)   # trunc
        TYPE_STRING:
            var s := String(value).strip_edges()
            if s.is_valid_int():
                return int(s)
            if s.is_valid_float():
                return int(float(s))
            return fallback
        _:
            return fallback

static func _safe_vector3(value) -> Vector3:
    """Converte Array, Dictionary ou Vector3 para Vector3. Fallback: Vector3.UP."""
    if value is Vector3:
        return value
    if value is Array and value.size() == 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    if value is Dictionary:
        if value.has("x") and value.has("y") and value.has("z"):
            return Vector3(float(value["x"]), float(value["y"]), float(value["z"]))
    return Vector3.UP

# ========================================================================== #
# REPRESENTAÇÃO STRING
# ========================================================================== #

func _to_string() -> String:
    return "[NeutralInfluenceContract id=%s mode=%s auth=%s created=%d expires=%d]" % [
        contract_id, operation_mode, authority_level, created_at_ms, expires_at_ms
    ]