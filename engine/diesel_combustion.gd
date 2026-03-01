# diesel_combustion.gd
extends CombustionSystem
class_name DieselCombustionSystem

var injection_start_curve: Curve2D

func _init(crankshaft_node: Node):
    super(crankshaft_node)
    injection_start_curve = Curve2D.new()
    injection_start_curve.add_point(Vector2(0.0, 20.0))   # Baixo RPM
    injection_start_curve.add_point(Vector2(0.5, 15.0))   # RPM médio
    injection_start_curve.add_point(Vector2(1.0, 10.0))   # Alto RPM

func update_combustion_events():
    var angle_per_cylinder = 720.0 / EngineConfig.chambers
    var current_angle = crankshaft.get_angle()
    
    active_events = 0
    for i in range(EngineConfig.chambers):
        var phase = i * angle_per_cylinder
        var angle_diff = fmod(current_angle - phase + 720.0, 720.0)
        
        # Ângulo de injeção baseado no RPM
        var rpm_norm = EngineConfig.get_rpm_normalized(crankshaft.rpm)
        var injection_angle = injection_start_curve.sample(rpm_norm)
        
        if angle_diff > (360.0 - injection_angle) or angle_diff < 10.0:
            active_events += 1