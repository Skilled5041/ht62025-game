extends Node3D

var speed := 10.0  # units per second
var target_position: Vector3 = Vector3.ZERO

func _process(delta):
	# Move forward along -Z axis toward the camera
	translate(Vector3(0, 0, -speed * delta))
	
	# Optional: destroy note if it goes past the camera
	if global_transform.origin.z < -5.0:
		queue_free()
