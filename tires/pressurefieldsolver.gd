class_name PressureFieldSolver
extends RefCounted

var enable_pressure_model: bool = true
var base_pressure: float = 200000.0
var load_sensitivity: float = 0.5
var min_contact_area: float = 1.0e-4

func solve(samples: Array[TireSample], patch: ContactPatch, delta: float) -> Dictionary:
	var patch_data := ContactPatchData.from_samples(samples)
	return solve_patch_data(patch_data, delta)

func solve_patch_data(patch_data: ContactPatchData, _delta: float) -> Dictionary:
	if not enable_pressure_model:
		return {
			"normal_loads": PackedFloat32Array(),
			"Fz_total": 0.0,
			"center_of_pressure_ws": patch_data.center_of_pressure_ws,
		}

	var loads := PackedFloat32Array()
	loads.resize(patch_data.samples.size())
	if patch_data.samples.is_empty() or patch_data.total_weight <= 0.0:
		return {
			"normal_loads": loads,
			"Fz_total": 0.0,
			"center_of_pressure_ws": patch_data.center_of_pressure_ws,
		}

	var contact_area := maxf(patch_data.contact_area_est, min_contact_area)
	var fz_total := 0.0
	for i in range(patch_data.samples.size()):
		var s := patch_data.samples[i]
		var local_pressure := base_pressure * pow(maxf(s.penetration, 0.0), load_sensitivity)
		var weight := (maxf(s.penetration, 0.0) * maxf(s.confidence, 0.0)) / patch_data.total_weight
		var normal_load := local_pressure * contact_area * weight
		loads[i] = normal_load
		fz_total += normal_load

	return {
		"normal_loads": loads,
		"Fz_total": fz_total,
		"center_of_pressure_ws": patch_data.center_of_pressure_ws,
	}
