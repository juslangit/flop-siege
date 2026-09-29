extends Node2D
## A blank canvas: whoever owns it hands it a drawing function.
## game.gd uses these for the backdrop, the catapult and the aiming dots.

var paint: Callable


func _draw() -> void:
	if paint.is_valid():
		paint.call(self)
