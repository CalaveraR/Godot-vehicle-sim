# Utilitário opcional para exportar snapshots de entrada/saída do core
# para os testes golden em Rust.
class_name CoreSnapshotRecorder
extends RefCounted

static func save_snapshot(path: String, wheel_state: Dictionary, samples: Array, core_output: Dictionary) -> void:
	var payload := {
		"version": "sim_calibration_v1",
		"wheel": wheel_state,
		"samples": samples,
		"expected": {
			"fx": float(core_output.get("Fx", 0.0)),
			"fy": float(core_output.get("Fy", 0.0)),
			"fz": float(core_output.get("Fz", 0.0)),
			"mz": float(core_output.get("Mz", 0.0)),
			"confidence": float(core_output.get("contact_confidence", 0.0)),
		},
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload, "\t"))
