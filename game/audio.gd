extends Node

var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var current_key := ""
var music_enabled := true
var effects_enabled := true

func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -12
	add_child(music)
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -8
		add_child(player)
		voices.append(player)

func configure(settings: Dictionary) -> void:
	music_enabled = settings.get("music", true)
	effects_enabled = settings.get("effects", true)
	if music:
		music.volume_db = -12 if music_enabled else -80

func play_music(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if current_key == key:
		return
	current_key = key
	var path := "res://assets/audio/music/%s.wav" % key
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	music.play()

func play_sfx(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not effects_enabled:
		return
	var path := "res://assets/audio/%s.ogg" % key
	if not ResourceLoader.exists(path):
		return
	for player in voices:
		if not player.playing:
			player.stream = load(path)
			player.play()
			return
