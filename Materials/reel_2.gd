extends Control

@export var speed : float = 2000.0
var spinning = false
var stopping = false

@onready var symbols = $Symbols

func start_spin():
	speed = 2000
	spinning = true
	stopping = false

func stop_spin():
	stopping = true

func _process(delta):
	if spinning:
		symbols.position.y += speed * delta
		
		
		if symbols.position.y > 300:
			symbols.position.y = 0
		
		
		if stopping:
			speed = lerp(speed, 0.0, 0.05)
			
			if speed < 10:
				speed = 0
				spinning = false
