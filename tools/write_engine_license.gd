extends SceneTree

func _initialize() -> void:
	var file:=FileAccess.open("res://LICENSES/GodotEngine-MIT.txt",FileAccess.WRITE)
	if not file:
		quit(1)
		return
	file.store_string(Engine.get_license_text())
	file.close()
	print("Wrote exact running Godot engine MIT notice")
	quit()
