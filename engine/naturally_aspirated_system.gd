class_name NaturallyAspiratedSystem
extends InductionSystem

func update(delta: float, rpm: float, throttle: float):
    current_boost = 1.0
    current_efficiency = 1.0
    turbo_spooled = false
    turbo_load_factor = 0.0
    current_backpressure = 1.0
    turbo_surge = false
    supercharger_drag = 0.0
    intake_temperature = EngineConfig.ambient_temp

func get_boost() -> float:
    return current_boost

func get_intake_temp() -> float:
    return intake_temperature

func get_data() -> Dictionary:
    var data = super.get_data()
    data["type"] = "Naturally Aspirated"
    return data