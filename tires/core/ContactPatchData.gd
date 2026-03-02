class_name ContactPatchData
extends RefCounted

var samples: Array[TireSample] = []
var patch_confidence: float = 0.0

var center_of_pressure_local: Vector3 = Vector3.ZERO
var center_of_pressure_ws: Vector3 = Vector3.ZERO
var avg_normal_local: Vector3 = Vector3.UP
var avg_normal_ws: Vector3 = Vector3.UP

var penetration_avg: float = 0.0
var penetration_max: float = 0.0
var contact_area_est: float = 0.0

var average_slip: Vector2 = Vector2.ZERO
var total_weight: float = 0.0

static func from_samples(samples_in: Array[TireSample]) -> ContactPatchData:
	var out := ContactPatchData.new()
	out.samples = samples_in
	if samples_in.is_empty():
		return out

	var weighted_pos_local := Vector3.ZERO
	var weighted_pos_ws := Vector3.ZERO
	var weighted_normal_local := Vector3.ZERO
	var weighted_normal_ws := Vector3.ZERO
	var weighted_slip := Vector2.ZERO
	var conf_sum := 0.0
	var penetration_sum := 0.0
	var valid_count := 0

	for sample in samples_in:
		if not sample.valid:
			continue
		var w := maxf(sample.penetration, 0.0) * clampf(sample.confidence, 0.0, 1.0)
		if w <= 0.0:
			continue
		weighted_pos_local += sample.contact_pos_local * w
		weighted_pos_ws += sample.contact_pos_ws * w
		weighted_normal_local += sample.contact_normal_local * w
		weighted_normal_ws += sample.contact_normal_ws * w
		weighted_slip += sample.slip_vector * w
		penetration_sum += sample.penetration
		out.penetration_max = maxf(out.penetration_max, sample.penetration)
		conf_sum += sample.confidence
		out.total_weight += w
		valid_count += 1

	if out.total_weight <= 0.0 or valid_count == 0:
		return out

	out.center_of_pressure_local = weighted_pos_local / out.total_weight
	out.center_of_pressure_ws = weighted_pos_ws / out.total_weight
	out.avg_normal_local = (weighted_normal_local / out.total_weight).normalized()
	out.avg_normal_ws = (weighted_normal_ws / out.total_weight).normalized()
	out.average_slip = weighted_slip / out.total_weight
	out.penetration_avg = penetration_sum / float(valid_count)
	out.patch_confidence = clampf(conf_sum / float(valid_count), 0.0, 1.0)
	out.contact_area_est = out.total_weight
	return out
