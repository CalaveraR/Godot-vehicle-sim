class_name TwinChargedSystem
extends InductionSystem

var supercharger: SuperchargerSystem
var turbo: SingleTurboSystem
var supercharger_active: bool = true
var transition_rpm: float = 3500.0
var transition_smoothness: float = 0.0

func _init(system: Node) -> void:
    super._init(system)
    supercharger = SuperchargerSystem.new(turbo_system)
    turbo = SingleTurboSystem.new(turbo_system)
    supercharger.max_boost_pressure = turbo_system.max_boost_pressure * 0.6

func update(delta: float):
    var rpm = turbo_system.engine_rpm
    update_active_system(rpm)
    supercharger.update(delta)
    turbo.update(delta)  # O turbo interno cuida do wastegate
    combine_systems(rpm)
    apply_intercooler()

func update_active_system(rpm: float):
    var target_smoothness: float
    if rpm < transition_rpm - 500:
        supercharger_active = true
        target_smoothness = 0.0
    elif rpm > transition_rpm + 500:
        supercharger_active = false
        target_smoothness = 1.0
    else:
        target_smoothness = (rpm - (transition_rpm - 500)) / 1000.0
    transition_smoothness = lerp(transition_smoothness, target_smoothness, delta * 2.0)

func combine_systems(rpm: float):
    if supercharger_active:
        current_boost = supercharger.current_boost
        supercharger_drag = supercharger.supercharger_drag
        if turbo_system.engine_throttle > 0.7 && rpm > transition_rpm - 1000:
            turbo.boost_target = turbo_system.max_boost_pressure * 0.8
    else:
        current_boost = turbo.current_boost
        supercharger_drag = 0.0
        supercharger.engine_rpm = rpm * 0.2
    
    if transition_smoothness > 0.0 && transition_smoothness < 1.0:
        current_boost = lerp(supercharger.current_boost, turbo.current_boost, transition_smoothness)

func get_data() -> Dictionary:
    var data = super.get_data()
    data["type"] = "Twin-Charged"
    data["active_system"] = "Supercharger" if supercharger_active else "Turbo"
    data["transition_smoothness"] = transition_smoothness
    data["supercharger_boost"] = supercharger.current_boost
    data["turbo_boost"] = turbo.current_boost
    return data