class_name EmissionSystem
extends Node

# Emissões atuais
var co: float = 0.0
var hc: float = 0.0
var nox: float = 0.0
var particulates: float = 0.0

# Curvas de emissão
var co_curve: Curve2D
var hc_curve: Curve2D
var nox_curve: Curve2D
var particulate_curve: Curve2D

# Referência
var engine: Engine

func _ready():
    # Configurar curvas padrão
    co_curve = Curve2D.new()
    co_curve.add_point(Vector2(0.0, 0.05))
    co_curve.add_point(Vector2(0.5, 0.1))
    co_curve.add_point(Vector2(1.0, 0.15))
    
    hc_curve = Curve2D.new()
    hc_curve.add_point(Vector2(0.0, 0.02))
    hc_curve.add_point(Vector2(0.5, 0.05))
    hc_curve.add_point(Vector2(1.0, 0.08))
    
    nox_curve = Curve2D.new()
    nox_curve.add_point(Vector2(0.0, 0.01))
    nox_curve.add_point(Vector2(0.5, 0.03))
    nox_curve.add_point(Vector2(1.0, 0.06))
    
    particulate_curve = Curve2D.new()
    particulate_curve.add_point(Vector2(0.0, 0.0))
    particulate_curve.add_point(Vector2(0.5, 0.05))
    particulate_curve.add_point(Vector2(1.0, 0.15))

func update(rpm: float, load: float, engine_type: int):
    var rpm_norm = EngineConfig.get_rpm_normalized(rpm)
    
    # Calcular emissões base
    co = co_curve.sample(rpm_norm) * load
    hc = hc_curve.sample(rpm_norm) * load
    nox = nox_curve.sample(rpm_norm) * load
    particulates = particulate_curve.sample(rpm_norm) * load
    
    # Considerar efeito do turbo nas emissões
    if engine and engine.induction_manager and engine.induction_manager.get_turbo_system():
        var boost = engine.induction_manager.get_turbo_system().get_current_boost()
        co *= 1.0 + (boost - 1.0) * 0.5
        nox *= 1.0 + (boost - 1.0) * 0.8
        particulates *= 1.0 + (boost - 1.0) * 1.2
    
    # Ajustes por tipo de motor
    match engine_type:
        EngineConfig.EngineType.PISTON_2T:
            hc *= 2.0
            co *= 1.5
        EngineConfig.EngineType.DIESEL:
            nox *= 1.8
            particulates *= 2.5
        EngineConfig.EngineType.WANKEL:
            hc *= 1.8
            co *= 1.2

func get_current_emissions() -> Dictionary:
    return {
        "co": co,
        "hc": hc,
        "nox": nox,
        "particulates": particulates
    }
