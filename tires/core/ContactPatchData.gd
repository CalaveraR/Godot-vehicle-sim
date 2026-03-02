class_name ContactPatchData
extends RefCounted

# --- Sensor-level aggregation ---
var samples: Array[TireSample] = []
var patch_confidence: float = 0.0
var center_of_pressure_local: Vector3 = Vector3.ZERO
var avg_normal_local: Vector3 = Vector3.UP
var penetration_avg: float = 0.0
var penetration_max: float = 0.0
var contact_area_est: float = 0.0
var average_slip: Vector2 = Vector2.ZERO
var normalized_weights: Array = []
var total_weight: float = 0.0

# --- Runtime unified contract (typed replacement for Dictionary keys) ---
var total_force: Vector3 = Vector3.ZERO
var total_torque: Vector3 = Vector3.ZERO
var average_position: Vector3 = Vector3.ZERO
var average_normal: Vector3 = Vector3.UP
var contact_area: float = 0.0
var max_pressure: float = 0.0
var average_grip: float = 1.0
var weighted_grip: float = 1.0
var contact_points: Array = []
var contact_data: Dictionary = {}
var units: Dictionary = {"force": "N", "torque": "N.m"}
var space: Dictionary = {"total_force": "world", "total_torque": "world"}

static func from_samples(samples_in: Array[TireSample]) -> ContactPatchData:
	var out := ContactPatchData.new()
	out.samples = samples_in
	if samples_in.is_empty():
		return out

	var weighted_pos_local := Vector3.ZERO
	var weighted_normal_local := Vector3.ZERO
	var weighted_slip := Vector2.ZERO
	var conf_sum := 0.0
	var penetration_sum := 0.0
	var valid_count := 0
	var raw_weights: Array = []
	raw_weights.resize(samples_in.size())

	for i in range(samples_in.size()):
		var sample := samples_in[i]
		if not sample.valid:
			raw_weights[i] = 0.0
			continue
		var w := maxf(sample.penetration, 0.0) * clampf(sample.confidence, 0.0, 1.0)
		raw_weights[i] = w
		if w <= 0.0:
			continue
		weighted_pos_local += sample.contact_pos_local * w
		weighted_normal_local += sample.contact_normal_local * w
		weighted_slip += sample.slip_vector * w
		penetration_sum += sample.penetration
		out.penetration_max = maxf(out.penetration_max, sample.penetration)
		conf_sum += sample.confidence
		out.total_weight += w
		valid_count += 1

	out.normalized_weights = TireCoreReference.normalize_weights(raw_weights)

	if out.total_weight <= 0.0 or valid_count == 0:
		return out

	out.center_of_pressure_local = weighted_pos_local / out.total_weight
	out.avg_normal_local = (weighted_normal_local / out.total_weight).normalized()
	out.average_slip = weighted_slip / out.total_weight
	out.penetration_avg = penetration_sum / float(valid_count)
	out.patch_confidence = clampf(conf_sum / float(valid_count), 0.0, 1.0)
	out.contact_area_est = out.total_weight
	return out

func get_center_of_pressure_ws() -> Vector3:
	if samples.is_empty() or normalized_weights.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	for i in range(min(samples.size(), normalized_weights.size())):
		acc += samples[i].contact_pos_ws * float(normalized_weights[i])
	return acc
