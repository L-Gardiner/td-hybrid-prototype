extends RefCounted
class_name WavePreviewHelper

const PREVIEW_TYPE_COUNTS: String = "counts"
const PREVIEW_TYPE_WEIGHTS: String = "weights"
const PREVIEW_TYPE_UNKNOWN: String = "unknown"
const PREVIEW_TYPE_NONE: String = "none"

static func build_preview(waves: Variant, wave_index: int, in_progress: bool) -> Dictionary:
	var result: Dictionary = {
		"total_wave_count": 0,
		"next_wave_index": wave_index,
		"next_wave_number": 0,
		"preview_type": PREVIEW_TYPE_UNKNOWN,
		"entries": [],
		"message": "",
		"in_progress": in_progress
	}
	if waves is Array:
		result["total_wave_count"] = waves.size()
	else:
		result["message"] = "Unknown"
		return result
	var total: int = int(result["total_wave_count"])
	var next_index: int = wave_index
	if in_progress:
		next_index = wave_index + 1
	result["next_wave_index"] = next_index
	result["next_wave_number"] = next_index + 1
	if total == 0 or next_index >= total:
		result["preview_type"] = PREVIEW_TYPE_NONE
		result["message"] = "Final wave cleared"
		return result
	var wave_def: Variant = waves[next_index]
	if wave_def is Dictionary:
		var wave_dict: Dictionary = wave_def
		if wave_dict.has("composition"):
			var comp_entries: Array = _build_composition_entries(wave_dict["composition"])
			if comp_entries.is_empty():
				result["preview_type"] = PREVIEW_TYPE_UNKNOWN
				result["message"] = "Unknown"
				return result
			result["preview_type"] = PREVIEW_TYPE_COUNTS
			result["entries"] = comp_entries
			return result
		if wave_dict.has("weights"):
			var weight_entries: Array = _build_weight_entries(wave_dict["weights"])
			if weight_entries.is_empty():
				result["preview_type"] = PREVIEW_TYPE_UNKNOWN
				result["message"] = "Unknown"
				return result
			result["preview_type"] = PREVIEW_TYPE_WEIGHTS
			result["entries"] = weight_entries
			return result
	result["preview_type"] = PREVIEW_TYPE_UNKNOWN
	result["message"] = "Unknown"
	return result

static func _build_composition_entries(value: Variant) -> Array:
	var entries: Array = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				var entry_dict: Dictionary = entry
				if entry_dict.has("type") and entry_dict.has("count"):
					var type_id: String = str(entry_dict["type"])
					var count_value: int = int(entry_dict["count"])
					if count_value > 0:
						entries.append({
							"enemy_id": type_id,
							"label": _format_enemy_label(type_id),
							"count": count_value
						})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) == int(b["count"]):
			return str(a["label"]) < str(b["label"])
		return int(a["count"]) > int(b["count"])
	)
	return entries

static func _build_weight_entries(value: Variant) -> Array:
	var entries: Array = []
	if value is Dictionary:
		var weights: Dictionary = value
		var total_weight: float = 0.0
		for key in weights.keys():
			total_weight += float(weights[key])
		if total_weight <= 0.0:
			return entries
		for key in weights.keys():
			var weight: float = float(weights[key])
			var percent: float = (weight / total_weight) * 100.0
			entries.append({
				"enemy_id": str(key),
				"label": _format_enemy_label(str(key)),
				"percent": percent
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["percent"]) == float(b["percent"]):
			return str(a["label"]) < str(b["label"])
		return float(a["percent"]) > float(b["percent"])
	)
	return entries

static func _format_enemy_label(type_id: String) -> String:
	if type_id == "":
		return "Unknown"
	var parts: PackedStringArray = type_id.split("_")
	var formatted: Array[String] = []
	for part in parts:
		if part.length() > 0:
			formatted.append(part.capitalize())
	if formatted.is_empty():
		return "Unknown"
	return " ".join(formatted)
