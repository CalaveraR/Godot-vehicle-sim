class_name AirSuspension
extends SuspensionSystem

export var air_pressure = 500.0 # kPa
export var air_volume = 5.0 # Liters
var min_air_pressure = 300.0
var max_air_pressure = 700.0

func _ready():
    suspension_type = SUSPENSION_TYPE.AIR

func calculate_specific_geometry(total_load: float):
    var new_pressure = total_load / (air_volume * 0.001) + min_air_pressure
    air_pressure = clamp(new_pressure, min_air_pressure, max_air_pressure)
    base_vertical_stiffness = air_pressure * 300.0

func adjust_ride_height(height: float):
    var pressure_adjustment = height * 50.0
    air_pressure = clamp(air_pressure + pressure_adjustment, min_air_pressure, max_air_pressure)

func get_suspension_type_name() -> String:
    return "Air Suspension"