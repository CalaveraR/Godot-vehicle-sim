class_name Crankshaft
extends Node

# Configuração
var engine_type: int
var max_rpm: float
var idle_rpm: float
var displacement: float
var chambers: int
var stroke_ratio: float
var rotor_eccentricity: float

# Estado
var rpm: float = 0.0
var angle: float = 0.0
var angular_velocity: float = 0.0
var torque: float = 0.0

# Curvas de performance
var friction_curve: Curve2D
var inertia_curve: Curve2D

# Novas propriedades para vibração
var vibration_orders: Array = []
var firing_order: Array = []
var vibration_amplitudes: Dictionary = {}
var vibration_phases: Dictionary = {}
var balance_shaft_effect: float = 1.0

func configure(config: Dictionary):
    engine_type = config.get("type", EngineConfig.EngineType.PISTON_4T)
    max_rpm = config.get("max_rpm", 7000.0)
    idle_rpm = config.get("idle_rpm", 800.0)
    displacement = config.get("displacement", 2.0)
    chambers = config.get("chambers", 4)
    stroke_ratio = config.get("stroke_ratio", 1.0)
    rotor_eccentricity = config.get("rotor_eccentricity", 15.0)
    
    # Configurar curvas
    friction_curve = Curve2D.new()
    friction_curve.add_point(Vector2(0.0, 0.1))
    friction_curve.add_point(Vector2(0.5, 0.3))
    friction_curve.add_point(Vector2(1.0, 0.8))
    
    inertia_curve = Curve2D.new()
    inertia_curve.add_point(Vector2(0.0, 1.0))
    inertia_curve.add_point(Vector2(1.0, 0.8))
    
    # Configurar ordem de ignição e harmônicos
    firing_order = config.get("firing_order", [1, 3, 4, 2])
    vibration_orders = config.get("vibration_orders", [0.5, 1.0, 1.5, 2.0])
    
    # Inicializar amplitudes e fases
    for order in vibration_orders:
        vibration_amplitudes[order] = calculate_base_amplitude(order)
        vibration_phases[order] = randf() * 2 * PI

func calculate_base_amplitude(order: float) -> float:
    var base_amp = 0.0
    
    # Motores em linha
    if engine_type == EngineConfig.EngineType.PISTON_4T:
        if chambers == 4:
            # Harmônicos primários para 4 cilindros em linha
            if order == 2.0:
                base_amp = 0.8
            elif order == 4.0:
                base_amp = 0.4
        
        # Motores V6 e V8 têm diferentes características
        elif chambers == 6:
            if order == 1.5:
                base_amp = 0.7
        elif chambers == 8:
            if order == 2.0:
                base_amp = 0.6
    
    # Motores boxer são naturalmente balanceados
    elif engine_type == EngineConfig.EngineType.BOXER:
        base_amp *= 0.3
    
    # Motores Wankel têm vibração mínima
    elif engine_type == EngineConfig.EngineType.WANKEL:
        base_amp *= 0.2
    
    return base_amp * (1.0 - balance_shaft_effect)

func apply_torque(input_torque: float, delta: float):
    var net_torque = input_torque - get_friction_torque()
    
    # Aplicar perdas por vibração
    var vibration_loss = get_vibration_loss()
    net_torque -= vibration_loss * displacement * 0.1
    
    var inertia = get_effective_inertia()
    angular_velocity += (net_torque / inertia) * delta
    rpm = clamp(angular_velocity * 9.5493, 0.0, max_rpm * 1.2)
    angle = fmod(angle + angular_velocity * delta * 57.2958, 720.0)
    
    # Atualizar fases de vibração
    for order in vibration_orders:
        vibration_phases[order] += angular_velocity * order * delta

func get_friction_torque() -> float:
    var rpm_factor = rpm / max_rpm
    return friction_curve.sample(rpm_factor) * displacement

func get_effective_inertia() -> float:
    var base_inertia = displacement * 0.1
    
    match engine_type:
        EngineConfig.EngineType.WANKEL:
            return base_inertia + chambers * rotor_eccentricity * 0.01
        _:
            return base_inertia + chambers * 0.02

func get_angle() -> float:
    return angle

func get_rpm() -> float:
    return rpm

func update(delta: float):
    # Mantido para compatibilidade
    pass

func get_vibration_loss() -> float:
    var total_loss = 0.0
    var rpm_factor = clamp(rpm / max_rpm, 0.2, 1.0)
    
    for order in vibration_orders:
        var amplitude = vibration_amplitudes[order]
        var phase = vibration_phases[order]
        
        # Perda proporcional ao quadrado da amplitude (energia cinética)
        total_loss += amplitude * amplitude * (0.5 + 0.5 * sin(phase)) * rpm_factor
    
    return total_loss

func get_vibration_level() -> float:
    # Cálculo de vibração baseado em RPM e configuração do motor
    var base_vibration = clamp(rpm / max_rpm * 0.8, 0.1, 0.9)
    
    # Fatores adicionais
    match engine_type:
        EngineConfig.EngineType.PISTON_4T:
            if chambers % 2 != 0:  # Motores ímpares vibram mais
                base_vibration *= 1.2
        EngineConfig.EngineType.WANKEL:
            base_vibration *= 0.7  # Motores rotativos são mais suaves
    
    # Adicionar efeito das harmônicas
    var harmonic_factor = 0.0
    for order in vibration_orders:
        harmonic_factor += vibration_amplitudes[order] * (0.5 + 0.5 * sin(vibration_phases[order]))
    
    base_vibration *= (1.0 + harmonic_factor * 0.5)
    
    return clamp(base_vibration, 0.0, 1.0)

func get_vibration_spectrum() -> Dictionary:
    var spectrum = {}
    for order in vibration_orders:
        spectrum[order] = {
            "amplitude": vibration_amplitudes[order],
            "phase": fmod(vibration_phases[order], 2 * PI)
        }
    return spectrum

func install_balance_shaft(effectiveness: float):
    balance_shaft_effect = clamp(effectiveness, 0.0, 1.0)
    # Recalcular amplitudes
    for order in vibration_orders:
        vibration_amplitudes[order] = calculate_base_amplitude(order)
