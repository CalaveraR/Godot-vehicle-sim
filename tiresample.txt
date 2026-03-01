# res://core/data/sample/TireSample.gd
class_name TireSample
extends RefCounted

# --- Gerador de ID único (para anti‑reciclagem) ---
static var _next_id: int = 0

# --- Identidade / validade ---
var id: int = -1
var valid: bool = false
var timestamp_s: float = 0.0
var frame_id: int = 0

# --- Geometria (local da roda = físico) ---
var contact_pos_local: Vector3 = Vector3.ZERO
var contact_normal_local: Vector3 = Vector3.UP

# --- World (debug/telemetria) ---
var contact_pos_ws: Vector3 = Vector3.ZERO
var contact_normal_ws: Vector3 = Vector3.UP

# --- Medidas físicas ---
var penetration: float = 0.0
var confidence: float = 0.0

# --- Dinâmica / slip ---
var slip_vector: Vector2 = Vector2.ZERO
var slip_magnitude: float = 0.0
var slip_magnitude_sq: float = 0.0
var penetration_velocity: float = 0.0

# --- Índices de grid (quando vier do shader) ---
var grid_x: int = -1
var grid_y: int = -1


func _init() -> void:
	id = _next_id
	_next_id += 1
	frame_id = Engine.get_process_frames()  # ou use seu próprio contador


# -------------------------------------------------------------------
# Fábricas (NUNCA chamar _init gigante “na mão”)
# -------------------------------------------------------------------
static func from_shader(
	grid_x: int,
	grid_y: int,
	contact_pos_local: Vector3,
	contact_normal_local: Vector3,
	penetration: float,
	confidence: float
) -> TireSample:
	var s := TireSample.new()
	s.grid_x = grid_x
	s.grid_y = grid_y
	s.contact_pos_local = contact_pos_local
	s.contact_normal_local = contact_normal_local
	s.penetration = penetration
	s.confidence = confidence
	s.valid = true
	s.timestamp_s = Time.get_unix_time_from_system()
	s.update_derived()
	return s


static func from_raycast(
	contact_pos_ws: Vector3,
	contact_normal_ws: Vector3,
	penetration: float,
	confidence: float,
	slip_vector: Vector2 = Vector2.ZERO,
	penetration_velocity: float = 0.0
) -> TireSample:
	var s := TireSample.new()
	s.contact_pos_ws = contact_pos_ws
	s.contact_normal_ws = contact_normal_ws
	s.penetration = penetration
	s.confidence = confidence
	s.slip_vector = slip_vector
	s.penetration_velocity = penetration_velocity
	s.valid = true
	s.timestamp_s = Time.get_unix_time_from_system()
	s.update_derived()
	return s


# -------------------------------------------------------------------
# Gerenciamento de pooling / reset
# -------------------------------------------------------------------
func reset() -> void:
	valid = false
	timestamp_s = 0.0
	frame_id = 0

	contact_pos_local = Vector3.ZERO
	contact_normal_local = Vector3.UP
	contact_pos_ws = Vector3.ZERO
	contact_normal_ws = Vector3.UP

	penetration = 0.0
	confidence = 0.0

	slip_vector = Vector2.ZERO
	slip_magnitude = 0.0
	slip_magnitude_sq = 0.0
	penetration_velocity = 0.0

	grid_x = -1
	grid_y = -1

	# id e _next_id NÃO são resetados – cada instância mantém seu ID único


# -------------------------------------------------------------------
# Métodos auxiliares
# -------------------------------------------------------------------
func update_derived() -> void:
	slip_magnitude_sq = slip_vector.length_squared()
	slip_magnitude = sqrt(slip_magnitude_sq)


func copy() -> TireSample:
	var s := TireSample.new()
	s.valid = valid
	s.timestamp_s = timestamp_s
	s.frame_id = frame_id

	s.contact_pos_local = contact_pos_local
	s.contact_normal_local = contact_normal_local
	s.contact_pos_ws = contact_pos_ws
	s.contact_normal_ws = contact_normal_ws

	s.penetration = penetration
	s.confidence = confidence

	s.slip_vector = slip_vector
	s.slip_magnitude = slip_magnitude
	s.slip_magnitude_sq = slip_magnitude_sq
	s.penetration_velocity = penetration_velocity

	s.grid_x = grid_x
	s.grid_y = grid_y
	return s


func _to_string() -> String:
	return "TireSample(id=%d, valid=%s, pos_ws=%s)" % [id, valid, contact_pos_ws]