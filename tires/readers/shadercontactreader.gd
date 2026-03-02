class_name ShaderContactReader
extends Node3D

@export var grid_w: int = 90
@export var grid_h: int = 120
@export var tire_width: float = 0.205
@export var tire_radius: float = 0.33
@export var shader_texture: Texture2D

# Roadmap: leitura atual usa get_image/get_data (baseline funcional).
# Próxima etapa: ring buffer assíncrono para evitar stalls de readback.

var _cell_local_pos: PackedVector3Array = []
var _initialized: bool = false

func _initialize() -> void:
	if _initialized:
		return

	_cell_local_pos.clear()
	var step_deg := 3.0

	for iy in range(grid_h):
		var angle_deg := iy * step_deg
		var theta := deg_to_rad(angle_deg)
		for ix in range(grid_w):
			var u := float(ix) / float(max(1, grid_w - 1)) - 0.5
			var local_pt := Vector3(u * tire_width, 0.0, -tire_radius)
			var rot := Basis(Vector3.UP, theta)
			_cell_local_pos.append(rot * local_pt)

	_initialized = true

func _rebuild() -> void:
	_initialized = false
	_initialize()

func set_source_texture(tex: Texture2D) -> void:
	shader_texture = tex

func read_samples(xform: Transform3D, now_s: float = -1.0, fallback_normal_ws: Vector3 = Vector3.UP) -> Array[TireSample]:
	if not _initialized:
		_initialize()

	if now_s < 0.0:
		now_s = Time.get_unix_time_from_system()

	if not shader_texture:
		return []

	var img := shader_texture.get_image()
	if img.get_format() != Image.FORMAT_RGBAF:
		push_error("ShaderContactReader: textura deve estar no formato FORMAT_RGBAF (float).")
		return []

	var data := img.get_data()
	var bytes_per_pixel := 16
	var expected_cells := grid_w * grid_h
	var available_cells := data.size() / bytes_per_pixel

	if available_cells < expected_cells:
		push_warning("ShaderContactReader: textura menor que a grade esperada. Esperado %d células, obtido %d." % [expected_cells, available_cells])

	var total_cells := min(expected_cells, available_cells)
	var samples: Array[TireSample] = []
	var inv := xform.affine_inverse()
	var normal_ws := fallback_normal_ws.normalized()

	for idx in range(total_cells):
		var offset := idx * bytes_per_pixel
		var penetration := maxf(data.decode_float(offset), 0.0)
		var slip_x := data.decode_float(offset + 4)
		var slip_y := data.decode_float(offset + 8)
		var conf := clampf(data.decode_float(offset + 12), 0.0, 1.0)

		var world_pos := xform * _cell_local_pos[idx]
		var local_pos := inv * world_pos
		var local_normal := (inv.basis * normal_ws).normalized()

		var sample := TireSample.from_shader(
			idx % grid_w,
			idx / grid_w,
			local_pos,
			local_normal,
			penetration,
			conf,
			Vector2(slip_x, slip_y),
			world_pos,
			normal_ws
		)
		sample.timestamp_s = now_s
		samples.append(sample)

	return samples

func set_grid_w(value: int) -> void:
	if value != grid_w:
		grid_w = value
		_rebuild()

func set_grid_h(value: int) -> void:
	if value != grid_h:
		grid_h = value
		_rebuild()

func set_tire_width(value: float) -> void:
	if value != tire_width:
		tire_width = value
		_rebuild()

func set_tire_radius(value: float) -> void:
	if value != tire_radius:
		tire_radius = value
		_rebuild()
