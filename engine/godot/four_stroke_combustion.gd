# four_stroke_combustion.gd
extends CombustionSystem
class_name FourStrokeCombustionSystem

func update_combustion_events():
    var angle_per_cylinder = 720.0 / EngineConfig.chambers
    var current_angle = crankshaft.get_angle()
    
    active_events = 0
    for i in range(EngineConfig.chambers):
        var phase = i * angle_per_cylinder
        var angle_diff = fmod(current_angle - phase + 720.0, 720.0)
        if angle_diff < 30.0 or angle_diff > 690.0:
            active_events += 1