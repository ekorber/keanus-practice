extends Control


func _draw() -> void:
	var center : Vector2 = size / 2.0
	var radius : float = min(size.x, size.y) / 2.0
	draw_circle(center, radius, Color(1.0, 0.84, 0.0))

	# Draw orange "C" in the center
	var font : Font = ThemeDB.fallback_font
	var font_size : int = int(radius * 1.4)
	var text_size : Vector2 = font.get_string_size("C", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos : Vector2 = center + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	draw_string(font, text_pos, "C", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.9, 0.5, 0.0))
