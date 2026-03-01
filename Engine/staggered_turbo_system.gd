class_name StaggeredTurboSystem
extends TwinTurboSystem

enum StaggeredMode { SIZE_DIFFERENCE, ELECTRIC_ASSIST, SUPERCHARGER_PRIMARY }

export(StaggeredMode) var staggered_mode = StaggeredMode.SIZE_DIFFERENCE
var electric_turbo: ElectricTurboSystem = null
var supercharger: SuperchargerSystem = null

func _init(system: Node).(system):
    if staggered_mode == StaggeredMode.ELECTRIC_ASSIST:
        electric_turbo = ElectricTurboSystem.new(turbo_system)
    elif staggered_mode == StaggeredMode.SUPERCHARGER_PRIMARY:
        supercharger = SuperchargerSystem.new(turbo_system)
        supercharger.max_boost_pressure = turbo_system.max_boost_pressure * 0.7

func update(delta: float):
    match staggered_mode:
        StaggeredMode.SIZE_DIFFERENCE:
            super.update(delta)
        StaggeredMode.ELECTRIC_ASSIST:
            update_electric_assist(delta)
        StaggeredMode.SUPERCHARGER_PRIMARY:
            update_supercharger_primary(delta)

func update_electric_assist(delta: float):
    electric_turbo.update(delta)
    var rpm_normalized = turbo_system.get_rpm_normalized()
    if rpm_normalized > 0.6:
        super.update(delta)
        current_boost = electric_turbo.current_boost * super.current_boost
    else:
        current_boost = electric_turbo.current_boost
        turbo.boost_target = 1.0

func update_supercharger_primary(delta: float):
    supercharger.update(delta)
    var rpm_normalized = turbo_system.get_rpm_normalized()
    turbo.boost_target = turbo_system.max_boost_pressure * smoothstep(0.4, 0.8, rpm_normalized)
    turbo.update(delta)
    current_boost = supercharger.current_boost * turbo.current_boost
    current_efficiency = (supercharger.current_efficiency + turbo.current_efficiency) * 0.9

func get_data() -> Dictionary:
    var data = super.get_data()
    data["type"] = "Staggered Twin Turbo"
    data["staggered_mode"] = staggered_mode
    if staggered_mode == StaggeredMode.ELECTRIC_ASSIST:
        data["electric_boost"] = electric_turbo.current_boost
    elif staggered_mode == StaggeredMode.SUPERCHARGER_PRIMARY:
        data["supercharger_boost"] = supercharger.current_boost
    return data