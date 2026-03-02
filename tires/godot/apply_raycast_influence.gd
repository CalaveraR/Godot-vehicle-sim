# ================= FUNÇÃO NEUTRA DE APLICAÇÃO =================

func apply_raycast_influence(
    shader_state: Dictionary,
    influence_contract: Dictionary
) -> Dictionary:
    """
    Aplica influência dos raycasts de forma neutra e determinística.
    
    REGRAS DE APLICAÇÃO:
    1. NÃO decide se deve aplicar (já decidido por evaluate_raycast_influence)
    2. NÃO calcula forças ou física
    3. NÃO gera novos dados
    4. Apenas clampa, pondera ou limita valores existentes
    5. Preserva dados originais do shader quando possível
    """
    
    # Criar cópia segura do estado do shader
    var result_state = shader_state.duplicate(true)
    
    # Validar contrato básico
    if not influence_contract.get("allow_influence", false):
        return result_state
    
    var mode = influence_contract.get("mode", "none")
    if mode == "none":
        return result_state
    
    # Extrair componentes do contrato
    var targets = influence_contract.get("targets", {})
    var limits = influence_contract.get("limits", {})
    var weights = influence_contract.get("weights", {})
    
    #  MODO "CLAMP" - Apenas limites físicos
    if mode == "clamp":
        result_state = _apply_clamp_mode(result_state, targets, limits)
    
    #  MODO "BIAS" - Interpolação ponderada
    elif mode == "bias":
        result_state = _apply_bias_mode(result_state, targets, limits, weights)
    
    #  MODO "FALLBACK" - Dados mínimos de emergência
    elif mode == "fallback":
        result_state = _apply_fallback_mode(result_state, limits)
    
    # Adicionar metadata de influência aplicada
    result_state["raycast_influence_applied"] = {
        "mode": mode,
        "timestamp": Time.get_ticks_msec(),
        "contract": influence_contract.get("reason", "")
    }
    
    return result_state

func _apply_clamp_mode(
    shader_state: Dictionary,
    targets: Dictionary,
    limits: Dictionary
) -> Dictionary:
    """
    Aplica modo CLAMP - apenas limita valores fisicamente implausíveis
    """
    var result = shader_state.duplicate(true)
    
    # 1. CLAMP DE PENETRAÇÃO (se alvo ativo)
    if targets.get("penetration", false):
        var current_pen = shader_state.get("avg_penetration", 0.0)
        var max_pen = limits.get("max_penetration", INF)
        
        if current_pen > max_pen:
            result["avg_penetration"] = max_pen
            result["clamp_applied"] = result.get("clamp_applied", 0) + 1
    
    # 2. CLAMP DE LARGURA (se alvo ativo)
    if targets.get("contact_width", false):
        var current_width = shader_state.get("contact_width", 0.0)
        var max_width = limits.get("max_contact_width", INF)
        
        if current_width > max_width:
            result["contact_width"] = max_width
            result["clamp_applied"] = result.get("clamp_applied", 0) + 1
    
    # 3. CLAMP DE CONFIANÇA (se alvo ativo)
    if targets.get("confidence", false):
        var current_conf = shader_state.get("confidence", 1.0)
        var min_conf = limits.get("min_confidence", 0.0)
        
        if current_conf < min_conf:
            result["confidence"] = min_conf
            result["clamp_applied"] = result.get("clamp_applied", 0) + 1
    
    # NOTA: Normal NUNCA é alterada em modo clamp
    # NOTA: Regiões de ativação NUNCA são alteradas em modo clamp
    
    return result

func _apply_bias_mode(
    shader_state: Dictionary,
    targets: Dictionary,
    limits: Dictionary,
    weights: Dictionary
) -> Dictionary:
    """
    Aplica modo BIAS - interpolação ponderada entre shader e limites do raycast
    """
    var result = shader_state.duplicate(true)
    
    # 1. BIAS DE PENETRAÇÃO (interpolação com limite máximo)
    if targets.get("penetration", false):
        var current_pen = shader_state.get("avg_penetration", 0.0)
        var max_pen = limits.get("max_penetration", current_pen)
        var weight = weights.get("penetration_weight", 0.0)
        
        # Interpolação linear em direção ao limite seguro
        var biased_pen = lerp(current_pen, max_pen, weight)
        result["avg_penetration"] = biased_pen
        result["bias_applied"] = result.get("bias_applied", 0) + 1
    
    # 2. BIAS DE CONFIANÇA (tendendo para confiança mínima)
    if targets.get("confidence", false):
        var current_conf = shader_state.get("confidence", 1.0)
        var min_conf = limits.get("min_confidence", current_conf)
        var weight = weights.get("confidence_weight", 0.0)
        
        # Interpolação linear para confiança mínima
        var biased_conf = lerp(current_conf, min_conf, weight)
        result["confidence"] = biased_conf
        result["bias_applied"] = result.get("bias_applied", 0) + 1
    
    # 3. BIAS DE LARGURA (interpolação com limite máximo)
    if targets.get("contact_width", false):
        var current_width = shader_state.get("contact_width", 0.0)
        var max_width = limits.get("max_contact_width", current_width)
        var weight = weights.get("width_weight", 0.0)
        
        var biased_width = lerp(current_width, max_width, weight)
        result["contact_width"] = biased_width
        result["bias_applied"] = result.get("bias_applied", 0) + 1
    
    # NOTA: Normal NUNCA é alterada em modo bias
    # NOTA: Regiões de ativação podem ser ajustadas, mas não removidas
    
    return result

func _apply_fallback_mode(
    shader_state: Dictionary,
    limits: Dictionary
) -> Dictionary:
    """
    Aplica modo FALLBACK - apenas fornece dados geométricos mínimos
    EMERGÊNCIA APENAS: shader falhou ou retornou dados inválidos
    """
    # Criar estado de fallback mínimo
    var result = {
        "mode": "raycast_fallback",
        "has_contact": false,
        "confidence": 0.1,  # Confiança mínima para indicar "dados de emergência"
        "avg_penetration": 0.0,
        "contact_width": 0.0,
        "fallback_source": "raycast_anchor",
        "timestamp": Time.get_ticks_msec(),
        "warning": "Usando dados de fallback do raycast - física limitada"
    }
    
    # Aplicar limites físicos do raycast como referência
    result["limits_applied"] = {
        "max_penetration": limits.get("max_penetration", 0.0),
        "reference_plane_normal": limits.get("reference_plane_normal", Vector3.UP),
        "reference_plane_height": limits.get("reference_plane_height", 0.0)
    }
    
    # NOTA: Nenhuma força é calculada aqui
    # NOTA: O sistema deve tratar este estado como "dados de referência apenas"
    
    return result