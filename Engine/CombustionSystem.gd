class_name CombustionSystem
extends RefCounted

# Referências
var engine: Engine
var crankshaft: Crankshaft
var cylinder_head: CylinderHead

# Estado
var output_rpm: float = 0.0
var combustion_efficiency: float = 0.85
var residual_gas_fraction: float = 0.15
var average_combustion_temp: float = 800.0
var peak_combustion_temp: float = 1200.0
var combustion_efficiency_curve: Curve2D
var afr_efficiency_curve: Curve2D

func _init():
    create_combustion_curves()

func create_combustion_curves():
    # Curva de eficiência por temperatura
    combustion_efficiency_curve = Curve2D.new()
    combustion_efficiency_curve.add_point(Vector2(700, 0.75))  # Low temp
    combustion_efficiency_curve.add_point(Vector2(900, 0.92))  # Optimal
    combustion_efficiency_curve.add_point(Vector2(1100, 0.85)) # Overheat
    
    # Curva de eficiência por AFR
    afr_efficiency_curve = Curve2D.new()
    afr_efficiency_curve.add_point(Vector2(12.0, 0.85))  # Rich
    afr_efficiency_curve.add_point(Vector2(14.7, 0.98)) # Stoich
    afr_efficiency_curve.add_point(Vector2(16.0, 0.90)) # Lean

func update(delta: float):
    if not engine or not crankshaft:
        return
    
    # Calcular eficiência da combustão
    calculate_combustion_efficiency()
    
    # Calcular torque gerado
    var torque = calculate_combustion_torque()
    
    # Aplicar torque ao virabrequim
    crankshaft.apply_torque(torque, delta)
    output_rpm = crankshaft.get_rpm()
    
    # Calcular temperatura de combustão
    calculate_combustion_temperature()

func calculate_combustion_efficiency():
    # Baseado na relação ar-combustível e qualidade da ignição
    var afr = engine.fuel_system.current_afr
    var ignition_quality = engine.ignition_system.ignition_quality
    
    # Eficiência ótima em AFR ~14.7
    var afr_deviation = abs(afr - 14.7) / 14.7
    combustion_efficiency = 0.95 - afr_deviation * 0.5
    
    # Aplicar efeito da ignição
    combustion_efficiency *= ignition_quality
    
    # Reduzir por gases residuais
    combustion_efficiency *= (1.0 - residual_gas_fraction)
    
    # Aplicar curvas de eficiência
    var temp_factor = combustion_efficiency_curve.sample(average_combustion_temp)
    var afr_factor = afr_efficiency_curve.sample(afr)
    combustion_efficiency = clamp(combustion_efficiency * temp_factor * afr_factor, 0.3, 0.95)

func calculate_combustion_torque() -> float:
    # Torque baseado no volume de mistura e eficiência
    var air_mass = engine.air_system.air_mass_per_cycle
    var fuel_mass = engine.fuel_system.fuel_mass_per_cycle
    
    # Energia teórica (gasolina ~42 MJ/kg)
    var energy = fuel_mass * 42e6 * combustion_efficiency
    
    # Converter para torque (fator mecânico)
    return energy * 0.0001 * engine.throttle_position

func calculate_combustion_temperature():
    # Baseado na carga e RPM
    var load_factor = engine.load
    peak_combustion_temp = 900.0 + (load_factor * 500.0)
    average_combustion_temp = 700.0 + (load_factor * 300.0)
    
    # Efeito da relação ar-combustível
    var afr = engine.fuel_system.current_afr
    if afr > 14.7:  # Mistura pobre
        average_combustion_temp += (afr - 14.7) * 50
    else:  # Mistura rica
        average_combustion_temp -= (14.7 - afr) * 30
    
    # Efeito do óleo na temperatura de combustão
    if engine.oil_system:
        var oil_temp_factor = clamp(engine.oil_system.oil_temperature / 120.0, 0.8, 1.2)
        peak_combustion_temp *= oil_temp_factor
        average_combustion_temp *= oil_temp_factor