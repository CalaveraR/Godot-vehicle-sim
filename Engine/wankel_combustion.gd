# wankel_combustion.gd
extends CombustionSystem
class_name WankelCombustionSystem

func update_combustion_events():
    var events_per_rotor = 3
    var angle_per_event = 360.0 / (EngineConfig.chambers * events_per_rotor)
    var current_angle = crankshaft.get_angle()
    
    active_events = 0
    for rotor in range(EngineConfig.chambers):
        for event in range(events_per_rotor):
            var phase = (rotor * events_per_rotor + event) * angle_per_event
            var angle_diff = fmod(current_angle - phase + 360.0, 360.0)
            if angle_diff > 30.0 and angle_diff < 150.0:
                active_events += 1