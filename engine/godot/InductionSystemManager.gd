class_name InductionSystemManager
extends Node

# Referências
var engine: Engine
var turbo_system: TurboSystem

var induction_type: int = TurboSystem.InductionType.NATURALLY_ASPIRATED

func _init():
    turbo_system = TurboSystem.new()
    turbo_system.set_engine_parameters(
        EngineConfig.redline_rpm,
        EngineConfig.idle_rpm,
        EngineConfig.max_naturally_aspirated_hp
    )

func update(delta: float):
    turbo_system.update_turbo_inputs(
        engine.rpm,
        engine.throttle_position,
        EngineConfig.displacement,
        engine.get_cylinder_count()
    )
    turbo_system.update_turbo(delta)

func get_boost() -> float:
    return turbo_system.get_current_boost()

func get_intake_temp() -> float:
    return turbo_system.get_intake_temp()

func set_throttle(position: float):
    turbo_system.engine_throttle = position

func switch_system(system_type: int):
    turbo_system.set_induction_type(system_type)
    induction_type = system_type
    
    # Configurações específicas
    match system_type:
        TurboSystem.InductionType.TURBOCHARGER:
            turbo_system.configure_turbo(50.0, 45.0, 1.5)
        TurboSystem.InductionType.SUPERCHARGED:
            turbo_system.set_supercharger_settings(1.8, 1.5)
        TurboSystem.InductionType.TWIN_CHARGED:
            turbo_system.configure_twin_charged(1.8, 50.0, 45.0, 2.0)

func get_induction_type() -> int:
    return induction_type

func get_efficiency() -> float:
    return turbo_system.get_efficiency()

func get_turbo_system():
    if induction_type == TurboSystem.InductionType.TURBOCHARGER || 
       induction_type == TurboSystem.InductionType.TWIN_TURBO ||
       induction_type == TurboSystem.InductionType.TWIN_CHARGED:
        return turbo_system
    return null

func get_air_flow_factor() -> float:
    return 1.0  # Implementação básica

func get_manifold_pressure() -> float:
    return turbo_system.get_current_boost() * EngineConfig.atmospheric_pressure
