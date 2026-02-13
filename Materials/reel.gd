extends Node3D

var fruits = ["bell", "cherry", "chest", "clover", "diamond", "lemon", "seven"]
var slots = [] 
var spinning = false

func _ready():
	randomize()
	create_slots_3x3()
	create_spin_button()
	fill_random()


func create_slots_3x3():
	for row in 3:
		for col in 3:
			var square = MeshInstance3D.new()
			square.mesh = PlaneMesh.new()
			square.mesh.size = Vector2(1.2, 1.2)  
			
		
			
			var x = (col - 1) * 1.3
			var y = (1 - row) * 1.3
			square.position = Vector3(x, y, 0)
			
			
			var material = StandardMaterial3D.new()
			square.material_override = material
			
			add_child(square)
			slots.append(square)

func create_spin_button():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var btn = Button.new()
	btn.text = "SPIN"
	btn.position = Vector2(100, 200)
	btn.pressed.connect(_on_spin_pressed)
	canvas.add_child(btn)

func _on_spin_pressed():
	if spinning:
		return
	
	spinning = true
	
	
	for i in 15:
		change_all_random()
		await get_tree().create_timer(0.1).timeout
	
	
	fill_random()
	spinning = false

func change_all_random():
	for i in 9:
		var random_fruit = fruits[randi() % fruits.size()]
		var path = "res://textures/" + random_fruit + ".png"
		var texture = load(path)
		
		if texture and slots[i] and slots[i].material_override:
			slots[i].material_override.albedo_texture = texture

func fill_random():
	change_all_random()
