class_name InductionSystem
extends RefCounted

# Propriedades comuns
var current_boost: float = 1.0
var current_efficiency: float = 1.0
var turbo_spooled: bool = false
var current_backpressure: float = 1.0
var turbo_surge: bool = false
var supercharger_drag: float = 0.0
var intake_temperature: float = 25.0
var turbo_load_factor: float = 0.0

# Referência ao sistema principal
var turbo_system: TurboSystem

func _init(system: TurboSystem):
    turbo_system = system

func update(delta: float, rpm: float, throttle: float):
    # Implementação básica
    current_boost = 1.0 + (rpm / turbo_system.redline_rpm) * 0.5
    current_efficiency = 0.8 + (throttle * 0.2)

func get_boost() -> float:
    return current_boost

func get_intake_temp() -> float:
    return intake_temperature

func apply_intercooler():
    if turbo_system:
        # Implementação básica
        intake_temperature = EngineConfig.ambient_temp + (intake_temperature - EngineConfig.ambient_temp) * 0.7

func get_data() -> Dictionary:
    return {
        "boost": current_boost,
        "efficiency": current_efficiency,
        "spooled": turbo_spooled,
        "backpressure": current_backpressure,
        "intake_temp": intake_temperature
    }