class_name IntakeSystem
extends Node

enum IntakeType {
    CARBURETOR_SINGLE,
    TBI_SIMPLE,
    TBI_2STAGE,
    CARBURETOR_2STAGE,
    CARBURETOR_4BARREL,
    WEBER_UPRIGHT,
    WEBER_SIDEDRAFT,
    TBI_SPORT,
    WEBER_UPRIGHT_SPLIT,
    WEBER_SIDEDRAFT_SPLIT,
    ITB,
    ITB_VARIABLE_LENGTH
}

# Implementação atual
var current_intake: BaseIntake
var engine: Engine

func _init():
    set_intake_type(IntakeType.TBI_SIMPLE)

func set_intake_type(type: IntakeType):
    if current_intake:
        current_intake.free()
    
    match type:
        IntakeType.CARBURETOR_SINGLE:
            current_intake = CarburetorSingle.new()
        IntakeType.TBI_SIMPLE:
            current_intake = TBISimple.new()
        IntakeType.TBI_2STAGE:
            current_intake = TBI2Stage.new()
        IntakeType.CARBURETOR_2STAGE:
            current_intake = Carburetor2Stage.new()
        IntakeType.CARBURETOR_4BARREL:
            current_intake = Carburetor4Barrel.new()
        IntakeType.WEBER_UPRIGHT:
            current_intake = WeberUpright.new()
        IntakeType.WEBER_SIDEDRAFT:
            current_intake = WeberSideDraft.new()
        IntakeType.TBI_SPORT:
            current_intake = TBISport.new()
        IntakeType.WEBER_UPRIGHT_SPLIT:
            current_intake = WeberUprightSplit.new()
        IntakeType.WEBER_SIDEDRAFT_SPLIT:
            current_intake = WeberSideDraftSplit.new()
        IntakeType.ITB:
            current_intake = ITB.new()
        IntakeType.ITB_VARIABLE_LENGTH:
            current_intake = ITBVariableLength.new()
    
    if current_intake && engine:
        current_intake.engine = engine

func update(delta: float, throttle_input: float):
    if !current_intake || !engine:
        return
    
    # Obter boost bruto do sistema de indução
    var base_boost = engine.induction_manager.get_boost()
    var rpm = engine.rpm
    
    # Processar com o sistema específico
    var processed_data = current_intake.process_airflow(
        base_boost,
        throttle_input,
        rpm
    )
    
    # Aplicar aos sistemas dependentes
    engine.air_system.apply_intake_modifiers(processed_data)
    engine.fuel_system.apply_intake_modifiers(processed_data)

func get_intake_data() -> Dictionary:
    return current_intake.get_data() if current_intake else {}
