class_name Engine
extends Node

# Componentes principais
var crankshaft: Crankshaft
var cylinder_head: CylinderHead

# Subsistemas
var air_system: AirSystem
var fuel_system: FuelSystem
var ignition_system: IgnitionSystem
var induction_manager: InductionSystemManager
var combustion_system: CombustionSystem
var emission_system: EmissionSystem
var intake_system: IntakeSystem
var backpressure_system: BackpressureSystem
var oil_system: OilSystem

# Estado
var rpm: float = 0.0
var throttle_position: float = 0.0
var load: float = 0.0
var coolant_temp: float = 90.0
var cylinder_count: int = 4
var current_torque: float = 0.0
var current_horsepower: float = 0.0

# Configurações
var torque_base_curve: Curve

func _ready():
    initialize_components()
    connect_subsystems()
    torque_base_curve = EngineConfig.torque_curve

func initialize_components():
    crankshaft = Crankshaft.new()
    cylinder_head = CylinderHead.new()
    
    # Configurar cylinder_head
    cylinder_head.configure(
        EngineConfig.chambers,
        EngineConfig.max_vvt_advance,
        EngineConfig.min_vvt_advance,
        EngineConfig.vvt_curve,
        EngineConfig.ve_curve
    )
    
    # Inicializar sistemas
    air_system = AirSystem.new()
    fuel_system = FuelSystem.new()
    ignition_system = IgnitionSystem.new()
    induction_manager = InductionSystemManager.new()
    combustion_system = CombustionSystem.new()
    emission_system = EmissionSystem.new()
    intake_system = IntakeSystem.new()
    backpressure_system = BackpressureSystem.new()
    oil_system = OilSystem.new()
    
    # Adicionar como filhos
    add_child(crankshaft)
    add_child(cylinder_head)
    add_child(air_system)
    add_child(fuel_system)
    add_child(ignition_system)
    add_child(induction_manager)
    add_child(combustion_system)
    add_child(emission_system)
    add_child(intake_system)
    add_child(backpressure_system)
    add_child(oil_system)
    
    # Configurar backpressure system
    backpressure_system.configure_exhaust(
        EngineConfig.exhaust_diameter,
        EngineConfig.exhaust_length,
        EngineConfig.exhaust_roughness,
        EngineConfig.has_catalytic_converter,
        EngineConfig.muffler_type
    )
    
    # Configurar headers se especificado
    if EngineConfig.header_type >= 0:
        backpressure_system.configure_headers(
            EngineConfig.header_type,
            EngineConfig.header_primary_length,
            EngineConfig.header_primary_diameter,
            EngineConfig.header_secondary_length,
            EngineConfig.header_collector_diameter
        )

func connect_subsystems():
    # Conexões essenciais
    cylinder_head.engine = self
    air_system.engine = self
    air_system.cylinder_head = cylinder_head
    combustion_system.engine = self
    combustion_system.crankshaft = crankshaft
    combustion_system.cylinder_head = cylinder_head
    ignition_system.engine = self
    fuel_system.engine = self
    induction_manager.engine = self
    emission_system.engine = self
    intake_system.engine = self
    oil_system.engine = self
    
    # Conexões específicas
    air_system.induction_manager = induction_manager
    backpressure_system.connect_to_engine(self, induction_manager.get_turbo_system())
    emission_system.backpressure_system = backpressure_system

func _physics_process(delta):
    # Ordem de atualização
    crankshaft.update(delta)
    cylinder_head.update(delta, rpm, throttle_position)
    induction_manager.update(delta)
    intake_system.update(delta, throttle_position)
    air_system.update(delta)
    fuel_system.update(delta)
    ignition_system.update(delta)
    combustion_system.update(delta)
    
    # Atualizar backpressure com dados de combustão
    backpressure_system.update(
        delta, 
        rpm, 
        air_system.air_flow,
        combustion_system.average_combustion_temp
    )
    
    # Atualizar sistema de óleo
    oil_system.update(delta, rpm, coolant_temp, crankshaft.get_vibration_level())
    
    # Aplicar perdas de eficiência por calor do óleo
    apply_oil_system_losses()
    
    # Atualizar emissões com backpressure
    emission_system.update(rpm, load, EngineConfig.engine_type)
    
    rpm = combustion_system.output_rpm
    load = calculate_engine_load()
    
    # Calcular performance do motor
    calculate_engine_performance()

func apply_oil_system_losses():
    var efficiency_loss = oil_system.get_efficiency_loss()
    
    # Reduzir eficiência volumétrica
    cylinder_head.volumetric_efficiency *= (1.0 - efficiency_loss * 0.5)
    
    # Reduzir eficiência de combustão
    combustion_system.combustion_efficiency *= (1.0 - efficiency_loss * 0.3)
    
    # Aumentar perdas por fricção
    crankshaft.friction_curve = adjust_friction_curve(
        crankshaft.friction_curve, 
        efficiency_loss
    )

func adjust_friction_curve(curve: Curve2D, loss_factor: float) -> Curve2D:
    var new_curve = Curve2D.new()
    for i in curve.get_point_count():
        var point = curve.get_point_position(i)
        new_curve.add_point(Vector2(point.x, point.y * (1.0 + loss_factor * 0.5)))
    return new_curve

func calculate_engine_performance():
    var turbo_data = {
        "boost": induction_manager.get_boost(),
        "efficiency": induction_manager.get_efficiency()
    }
    
    var cyl_head_data = {
        "volumetric_efficiency": cylinder_head.volumetric_efficiency,
        "vvt_advance": cylinder_head.current_vvt_advance
    }
    
    var vibration_level = crankshaft.get_vibration_level()
    
    var output = EnginePhysics.calculate_engine_output(
        torque_base_curve,
        throttle_position,
        turbo_data,
        cyl_head_data,
        rpm,
        induction_manager.induction_type,
        vibration_level,
        cylinder_count,
        EngineConfig.max_hp,
        EngineConfig.redline_rpm,
        EngineConfig.max_vvt_advance
    )
    
    current_torque = output["torque"]
    current_horsepower = output["horsepower"]
    
    # Aplicar efeitos de contra-pressão
    EnginePhysics.apply_backpressure_effects(
        backpressure_system.get_backpressure(),
        air_system.air_flow,
        cylinder_head,
        induction_manager.get_turbo_system(),
        throttle_position,
        backpressure_system.scavenging_factor
    )

func calculate_engine_load() -> float:
    return air_system.manifold_pressure * throttle_position

func set_throttle(position: float):
    throttle_position = clamp(position, 0.0, 1.0)
    air_system.set_throttle(position)
    induction_manager.set_throttle(position)

func get_cylinder_count() -> int:
    return cylinder_count

func install_induction_system(system_type: int):
    induction_manager.switch_system(system_type)

func get_performance() -> Dictionary:
    return {
        "torque": current_torque,
        "horsepower": current_horsepower,
        "rpm": rpm,
        "backpressure": backpressure_system.get_backpressure(),
        "scavenging": backpressure_system.scavenging_factor
    }

func get_oil_system_data() -> Dictionary:
    return oil_system.get_oil_data() if oil_system else {}