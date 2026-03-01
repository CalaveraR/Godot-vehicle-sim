class_name AirSystem
extends Node

# Referências
var engine: Engine
var cylinder_head: CylinderHead
var induction_manager: InductionSystemManager

# Estado
var air_flow: float = 0.0  # kg/s
var manifold_pressure: float = 1.0  # bar
var throttle_position: float = 0.0
var air_mass_per_cycle: float = 0.0

func update(delta: float):
    if not engine or not cylinder_head:
        return
    
    # Calcular fluxo de ar baseado na posição do acelerador e RPM
    var max_flow = EngineConfig.max_air_flow * cylinder_head.volumetric_efficiency
    air_flow = max_flow * throttle_position * (engine.rpm / EngineConfig.redline_rpm)
    
    # Aplicar efeito do sistema de indução
    if induction_manager:
        air_flow *= induction_manager.get_air_flow_factor()
        manifold_pressure = induction_manager.get_manifold_pressure()
    
    # Calcular massa de ar por ciclo
    air_mass_per_cycle = (air_flow * 60) / (engine.rpm * engine.cylinder_count / 2)

func set_throttle(position: float):
    throttle_position = clamp(position, 0.0, 1.0)

# Novo método para aplicar modificadores
func apply_intake_modifiers(data: Dictionary):
    cylinder_head.volumetric_efficiency *= data.get("ve_modifier", 1.0)
    # Ajustar fluxo de ar baseado nos modificadores
    manifold_pressure = data.get("boost", 1.0) * EngineConfig.atmospheric_pressure
    air_flow = (engine.rpm * engine.get_cylinder_count() * 0.5 * 
               cylinder_head.volumetric_efficiency * manifold_pressure)
