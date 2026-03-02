extends RefCounted
class_name TireCoreReference

# Convenções numéricas usadas durante prototipagem em GDScript.
# A ideia é manter estes mesmos valores-base no equivalente Rust,
# permitindo ajustes em runtime sem quebrar a transição.
const DEFAULT_CONVENTIONS := {
	"epsilon": 1.0e-6,
	"min_stiffness": 1.0e-4,
	"min_positive_weight": 0.0,
	"contact_penetration_threshold": 0.0,
}

static func resolve_conventions(overrides: Dictionary = {}) -> Dictionary:
	var out := DEFAULT_CONVENTIONS.duplicate(true)
	for key in overrides.keys():
		out[key] = overrides[key]
	return out

static func normalize_weights(weights: Array, conventions: Dictionary = {}) -> Array:
	var cfg := resolve_conventions(conventions)
	var min_positive_weight: float = float(cfg.get("min_positive_weight", 0.0))
	var epsilon: float = float(cfg.get("epsilon", 1.0e-6))

	var sum := 0.0
	for value in weights:
		var w := float(value)
		if w > min_positive_weight:
			sum += w

	if sum <= epsilon:
		var zeros: Array = []
		zeros.resize(weights.size())
		for i in range(zeros.size()):
			zeros[i] = 0.0
		return zeros

	var normalized: Array = []
	normalized.resize(weights.size())
	for i in range(weights.size()):
		var w := float(weights[i])
		normalized[i] = (w / sum) if w > min_positive_weight else 0.0
	return normalized

static func aggregate_patch(samples: Array, conventions: Dictionary = {}) -> Dictionary:
	if samples.is_empty():
		return {
			"contact_confidence": 0.0,
			"penetration_avg": 0.0,
			"penetration_max": 0.0,
			"slip_x_avg": 0.0,
			"slip_y_avg": 0.0,
		}

	var cfg := resolve_conventions(conventions)
	var threshold: float = float(cfg.get("contact_penetration_threshold", 0.0))

	var raw_weights: Array = []
	raw_weights.resize(samples.size())
	for i in range(samples.size()):
		raw_weights[i] = float(samples[i].get("weight", 0.0))

	var weights := normalize_weights(raw_weights, cfg)

	var penetration_avg := 0.0
	var penetration_max := 0.0
	var slip_x_avg := 0.0
	var slip_y_avg := 0.0
	var contact_confidence := 0.0

	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		var w: float = float(weights[i])
		var penetration: float = float(sample.get("penetration", 0.0))
		var slip_x: float = float(sample.get("slip_x", 0.0))
		var slip_y: float = float(sample.get("slip_y", 0.0))

		if penetration > threshold:
			contact_confidence += w

		penetration_avg += penetration * w
		penetration_max = maxf(penetration_max, penetration)
		slip_x_avg += slip_x * w
		slip_y_avg += slip_y * w

	return {
		"contact_confidence": clampf(contact_confidence, 0.0, 1.0),
		"penetration_avg": penetration_avg,
		"penetration_max": penetration_max,
		"slip_x_avg": slip_x_avg,
		"slip_y_avg": slip_y_avg,
	}

static func compute_effective_radius(
	tire_radius: float,
	min_effective_radius: float,
	vertical_load: float,
	stiffness: float,
	conventions: Dictionary = {}
) -> float:
	if tire_radius <= 0.0:
		return 0.0

	var cfg := resolve_conventions(conventions)
	var min_stiffness: float = float(cfg.get("min_stiffness", 1.0e-4))
	var safe_stiffness := maxf(stiffness, min_stiffness)
	var compression := minf(maxf(vertical_load, 0.0) / safe_stiffness, tire_radius)
	return minf(maxf(tire_radius - compression, min_effective_radius), tire_radius)
