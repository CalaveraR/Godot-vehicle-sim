class_name TireCore
extends RefCounted

var confidence_min_for_contact: float = 0.1
var emergency_fz_falloff_rate: float = 10.0
var energy_delta_limit: float = 8000.0
var conventions: Dictionary = TireCoreReference.DEFAULT_CONVENTIONS.duplicate(true)

func step_wheel(
	shader_samples: Array[TireSample],
	raycast_samples: Array[TireSample],
	dt: float,
	current_velocity_ws: Vector3 = Vector3.ZERO,
	previous_fz: float = 0.0
) -> TireForces:
	var merged := _merge_samples(shader_samples, raycast_samples)
	var patch := ContactPatchData.from_samples(merged)
	var normalized := _normalize_and_aggregate(merged)
	var out := TireForces.new()
	out.contact_confidence = float(normalized.get("contact_confidence", patch.patch_confidence))
	out.center_of_pressure_ws = _center_of_pressure_ws(merged, patch.normalized_weights)

	if patch.patch_confidence < confidence_min_for_contact and raycast_samples.is_empty():
		out.Fz = _smooth_to_zero(previous_fz, dt)
		out.debug = {
			"safety": "emergency_no_ground",
			"patch_confidence": patch.patch_confidence,
			"sample_count": merged.size(),
		}
		return out

	var base_k := 120000.0
	var base_c := 3000.0
	var pen_rate := _estimate_penetration_rate(merged)
	var pen_avg := float(normalized.get("penetration_avg", patch.penetration_avg))
	out.Fz = maxf(0.0, base_k * pen_avg + base_c * pen_rate)

	var slip := patch.average_slip
	var mu := 1.0
	out.Fx = -slip.x * out.Fz * 0.5
	out.Fy = -slip.y * out.Fz * 0.7
	var tangential := Vector2(out.Fx, out.Fy)
	var max_tangent := mu * out.Fz
	if tangential.length() > max_tangent and tangential.length() > 0.0:
		tangential = tangential.normalized() * max_tangent
		out.Fx = tangential.x
		out.Fy = tangential.y

	out.Mz = out.Fy * (patch.center_of_pressure_local.x)
	_apply_energy_clamp(out, current_velocity_ws, dt)
	out.debug = {
		"patch_confidence": patch.patch_confidence,
		"penetration_avg": patch.penetration_avg,
		"penetration_max": patch.penetration_max,
		"sample_count": merged.size(),
	}
	return out

func _merge_samples(shader_samples: Array[TireSample], raycast_samples: Array[TireSample]) -> Array[TireSample]:
	var out: Array[TireSample] = []
	for s in shader_samples:
		out.append(s)
	for s in raycast_samples:
		out.append(s)
	return out

func _estimate_penetration_rate(samples: Array[TireSample]) -> float:
	if samples.is_empty():
		return 0.0
	var acc := 0.0
	var n := 0
	for s in samples:
		acc += s.penetration_velocity
		n += 1
	return acc / float(max(n, 1))

func _smooth_to_zero(previous_fz: float, dt: float) -> float:
	var t := clampf(dt * emergency_fz_falloff_rate, 0.0, 1.0)
	return lerpf(previous_fz, 0.0, t)

func _apply_energy_clamp(forces: TireForces, velocity_ws: Vector3, dt: float) -> void:
	if dt <= 0.0:
		return
	var f := Vector3(forces.Fx, forces.Fz, forces.Fy)
	var delta_e := abs(f.dot(velocity_ws) * dt)
	if delta_e <= energy_delta_limit:
		return
	var scale := energy_delta_limit / maxf(delta_e, 1e-6)
	forces.Fx *= scale
	forces.Fy *= scale
	forces.Fz *= scale
	forces.Mz *= scale
	forces.debug["energy_clamped"] = true
	forces.debug["energy_scale"] = scale


func _normalize_and_aggregate(samples: Array[TireSample]) -> Dictionary:
	var mapped: Array = []
	mapped.resize(samples.size())
	for i in range(samples.size()):
		var sample := samples[i]
		mapped[i] = {
			"weight": maxf(sample.penetration, 0.0) * clampf(sample.confidence, 0.0, 1.0),
			"penetration": sample.penetration,
			"slip_x": sample.slip_vector.x,
			"slip_y": sample.slip_vector.y,
		}
	return TireCoreReference.aggregate_patch(mapped, conventions)


func _center_of_pressure_ws(samples: Array[TireSample], normalized_weights: Array) -> Vector3:
	if samples.is_empty() or normalized_weights.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	for i in range(min(samples.size(), normalized_weights.size())):
		acc += samples[i].contact_pos_ws * float(normalized_weights[i])
	return acc
