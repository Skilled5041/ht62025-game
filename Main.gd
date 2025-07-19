extends Node3D

@export var note_scene: PackedScene  # Set this to Note.tscn in the editor
var hit_objects: Array = []

var spawn_z = 100.0  # Distance from camera to spawn notes
var scroll_speed = 10.0
 
func load_beatmap_from_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Cannot open file: " + path)
		return {}
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var result = json.parse(json_text)
	var data = JSON.parse_string(json_text)
	return data


func _ready():
	var beatmap_data = load_beatmap_from_json("res://beatmaps/death_piano.json")
	hit_objects = beatmap_data["hit_objects"]
	
	for hit_object in hit_objects:
		var lane = hit_object["x"]
		lanes[lane].append(hit_object)
		
	
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = load("res://beatmaps/audio.mp3")
	audio_player.play()

	
func render_notes():
	for i in range(4):
		for j in range(minIndex[i], len(lanes[i])):
			var note_time_seconds = lanes[i][j]["time"] / 1000.0
			
			# If note is offscreen, don't show it anymore
			if time_elapsed > note_time_seconds && !lanes[i][j]["is_hold"]:
				minIndex[i] = j + 1
				note_objects[i][j].visible = false
			elif lanes[i][j]["is_hold"] && time_elapsed > lanes[i][j]["end_time"] / 1000:
				minIndex[i] = j + 1
				note_objects[i][j].visible = false
			if note_time_seconds - time_elapsed > 1:
				break
				
			if len(note_objects[i]) <= j:
				var cube = MeshInstance3D.new()
				cube.mesh = BoxMesh.new()
				cube.position = Vector3((note_time_seconds - time_elapsed) * -40 + 20, 0, i - 1.5)
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(1.0, 0.0, 1.0)  # Purple
				cube.material_override = mat
				cube.scale = Vector3(1, 0.2, 1)
				note_objects[i].append(cube)
				
				# If long note
				if lanes[i][j]["is_hold"]:
					mat = StandardMaterial3D.new()
					mat.albedo_color = Color(0.3, 0.8, 0.6)
					cube.material_override = mat
					cube.position = Vector3((note_time_seconds - time_elapsed) * -40 + 20 - ((lanes[i][j]["end_time"] / 1000) - (lanes[i][j]["time"] / 1000)) * 20, 0, i - 1.5)
					cube.scale = Vector3(((lanes[i][j]["end_time"] / 1000) - (lanes[i][j]["time"] / 1000)) * 40, 0.2, 1)
				
				add_child(cube)
			else:
				if !lanes[i][j]["is_hold"]:
					note_objects[i][j].position = Vector3((note_time_seconds - time_elapsed) * -40 + 20, 0, i - 1.5)
				else:
					note_objects[i][j].position = Vector3((note_time_seconds - time_elapsed) * -40 + 20 - ((lanes[i][j]["end_time"] / 1000) - (lanes[i][j]["time"] / 1000)) * 20, 0, i - 1.5)
			

static var time_elapsed = 0
static var minIndex = [0, 0, 0, 0]
static var lanes = [[], [], [], []]
static var note_objects = [[], [], [], []]
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time_elapsed += delta
	
	render_notes()
