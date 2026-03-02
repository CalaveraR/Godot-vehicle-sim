# SurfaceManager.gd (exemplo de implementação)
extends Node

# Texturas de superfície pré-definidas
enum SURFACE_TYPE {
    ASPHALT_SMOOTH = 1,
    ASPHALT_ROUGH = 2,
    GRAVEL = 3,
    DIRT = 4,
    WET_ASPHALT = 5
}

# Dados de superfície por área
var surface_areas = {
    "track": {
        "bounds": AABB(Vector3(-1000,0,-1000), Vector3(2000,0,2000)),
        "type": SURFACE_TYPE.ASPHALT_SMOOTH,
        "grip": 1.0,
        "water_depth": 0.0,
        "temperature": 25.0
    },
    "grass": {
        "bounds": AABB(Vector3(-2000,0,-2000), Vector3(4000,0,4000)),
        "type": SURFACE_TYPE.DIRT,
        "grip": 0.7,
        "water_depth": 0.02,
        "temperature": 22.0
    }
}

func get_water_depth(position: Vector3) -> float:
    for area in surface_areas.values():
        if area.bounds.has_point(position):
            return area.water_depth
    return 0.0

func get_surface_data(position: Vector3) -> Dictionary:
    for area in surface_areas.values():
        if area.bounds.has_point(position):
            return {
                "texture_type": area.type,
                "grip_factor": area.grip,
                "temperature": area.temperature
            }
    
    # Retorno padrão se não encontrar área
    return {
        "texture_type": SURFACE_TYPE.ASPHALT_SMOOTH,
        "grip_factor": 1.0,
        "temperature": 20.0
    }