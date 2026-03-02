class_name TireCoreParityValidator
extends RefCounted

var _loaded_path: String = ""
var _vectors: Array = []

func _load_vectors(path: String) -> void:
	if path == _loaded_path:
		return
	_loaded_path = path
	_vectors = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("cases"):
		_vectors = parsed["cases"]

func validate_contact_patch(patch: ContactPatchData, vectors_path: String, tol: float = 0.02) -> void:
	_load_vectors(vectors_path)
	if _vectors.is_empty():
		return
	var ref: Dictionary = _vectors[0]
	if not ref.has("expected"):
		return
	var expected: Dictionary = ref["expected"]
	var dz := abs(patch.max_penetration - float(expected.get("penetration_max", patch.max_penetration)))
	var dc := abs(patch.patch_confidence - float(expected.get("contact_confidence", patch.patch_confidence)))
	if dz > tol or dc > tol:
		push_warning("[TireCoreParityValidator] patch diverged from golden vector beyond tolerance")
