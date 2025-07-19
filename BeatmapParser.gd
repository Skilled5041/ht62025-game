extends Node
class_name BeatmapParser

# === DATA CLASSES ===

class General:
	var audio_filename := ""
	var audio_lead_in := 0
	var audio_hash := ""
	var preview_time := -1
	var countdown := 1
	var sample_set := "Normal"
	var stack_leniency := 0.7
	var mode := 0
	var letterbox_in_breaks := false
	var story_fire_in_front := true
	var use_skin_sprites := false
	var always_show_playfield := false
	var overlay_position := "NoChange"
	var skin_preference := ""
	var epilepsy_warning := false
	var countdown_offset := 0
	var special_style := false
	var widescreen_storyboard := false
	var samples_match_playback_rate := false

class Editor:
	var bookmarks: Array[int] = []
	var distance_spacing := 1.0
	var beat_divisor := 4
	var grid_size := 32
	var timeline_zoom := 1.0

class Metadata:
	var title := ""
	var title_unicode := ""
	var artist := ""
	var artist_unicode := ""
	var creator := ""
	var version := ""
	var source := ""
	var tags: Array[String] = []
	var beatmap_id := 0
	var beatmap_set_id := 0

class Difficulty:
	var hp_drain_rate := 5.0
	var circle_size := 5.0
	var overall_difficulty := 5.0
	var approach_rate := 5.0
	var slider_multiplier := 1.0
	var slider_tick_rate := 1.0

class Event:
	var type := ""
	var start_time := 0
	var params: Array[String] = []

class TimingPoint:
	var time := 0
	var beat_length := 0.0
	var meter := 4
	var sample_set := 0
	var sample_index := 0
	var volume := 100
	var uninherited := true
	var effects := 0

class Colours:
	var combos: Dictionary = {}
	var slider_track_override := Color()
	var slider_border := Color()

class HitSample:
	var normal_set := 0
	var addition_set := 0
	var index := 0
	var volume := 0
	var filename := ""

class HitObject:
	var x := 0
	var y := 0
	var time := 0
	var type := 0
	var hit_sound := 0
	var params: Array = []
	var hit_sample := HitSample.new()

# === BEATMAP STRUCTURE ===

class Beatmap:
	var format_version := 14
	var general := General.new()
	var editor := Editor.new()
	var metadata := Metadata.new()
	var difficulty := Difficulty.new()
	var events: Array[Event] = []
	var timing_points: Array[TimingPoint] = []
	var colours := Colours.new()
	var hit_objects: Array[HitObject] = []

# === PARSER FUNCTION ===

func parse_osu_file(path: String) -> Beatmap:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open file: " + path)
		return null
	
	var beatmap := Beatmap.new()
	var section := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges(true)
		if line.begins_with("osu file format v"):
			beatmap.format_version = int(line.split("v")[1])
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.strip_edges(true).substr(1, line.length() - 2)
			continue
		if line == "" or line.begins_with("//"):
			continue

		match section:
			"General":
				var kv = line.split(":", false, 2)
				if kv.size() == 2:
					_set_var(beatmap.general, kv[0].strip_edges(true), kv[1].strip_edges(true))
			"Editor":
				var kv = line.split(":", false, 2)
				if kv.size() == 2:
					if kv[0] == "Bookmarks":
						beatmap.editor.bookmarks = []
						for s in kv[1].split(","):
							beatmap.editor.bookmarks.append(int(s))
					else:
						_set_var(beatmap.editor, kv[0].strip_edges(true), kv[1].strip_edges(true))
			"Metadata":
				var kv = line.split(":", false, 2)
				if kv.size() == 2:
					if kv[0] == "Tags":
						beatmap.metadata.tags = []
						for tag in kv[1].strip_edges(true).split(" "):
							beatmap.metadata.tags.append(tag)
					else:
						_set_var(beatmap.metadata, kv[0].strip_edges(true), kv[1].strip_edges(true))
			"Difficulty":
				var kv = line.split(":", false, 2)
				if kv.size() == 2:
					_set_var(beatmap.difficulty, kv[0].strip_edges(true), kv[1].strip_edges(true))
			"Events":
				var ev = line.split(",", false)
				var e := Event.new()
				e.type = ev[0]
				if ev.size() > 1: e.start_time = int(ev[1])
				if ev.size() > 2:
					var slice = ev.slice(2, ev.size())
					e.params = []
					for v in slice:
						e.params.append(v)

				beatmap.events.append(e)
			"TimingPoints":
				var parts = line.split(",", false)
				if parts.size() >= 8:
					var tp := TimingPoint.new()
					tp.time = int(parts[0])
					tp.beat_length = float(parts[1])
					tp.meter = int(parts[2])
					tp.sample_set = int(parts[3])
					tp.sample_index = int(parts[4])
					tp.volume = int(parts[5])
					tp.uninherited = parts[6] == "1"
					tp.effects = int(parts[7])
					beatmap.timing_points.append(tp)
			"Colours":
				var kv = line.split(":", false, 2)
				if kv.size() == 2:
					var name = kv[0].strip_edges(true)
					var rgb_strings = kv[1].strip_edges(true).split(",")
					var rgb = []
					for s in rgb_strings:
						rgb.append(int(s))
					var color = Color(rgb[0]/255.0, rgb[1]/255.0, rgb[2]/255.0)
					if name.begins_with("Combo"):
						beatmap.colours.combos[name] = color
					elif name == "SliderTrackOverride":
						beatmap.colours.slider_track_override = color
					elif name == "SliderBorder":
						beatmap.colours.slider_border = color
			"HitObjects":
				var parts = line.split(",", false)
				if parts.size() >= 5:
					var ho := HitObject.new()
					ho.x = int(parts[0])
					ho.y = int(parts[1])
					ho.time = int(parts[2])
					ho.type = int(parts[3])
					ho.hit_sound = int(parts[4])
					if parts.size() > 5:
						ho.params = parts.slice(5, parts.size() - 1)
					if parts.size() > 6:
						var sample_parts = parts[parts.size() - 1].split(":")
						if sample_parts.size() >= 5:
							ho.hit_sample.normal_set = int(sample_parts[0])
							ho.hit_sample.addition_set = int(sample_parts[1])
							ho.hit_sample.index = int(sample_parts[2])
							ho.hit_sample.volume = int(sample_parts[3])
							ho.hit_sample.filename = sample_parts[4]
					beatmap.hit_objects.append(ho)

	return beatmap


# === UTILITIES ===

func _set_var(target: Object, key: String, value: String) -> void:
	if not (key in target):
		return
	var current_value = target[key]
	match typeof(current_value):
		TYPE_BOOL:
			target[key] = value == "1"
		TYPE_INT:
			target[key] = int(value)
		TYPE_FLOAT:
			target[key] = float(value)
		TYPE_STRING:
			target[key] = value
