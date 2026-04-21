extends AudioStreamPlayer

const level_music = preload("res://assets/Art/BasicMusic.mp3")

func _play_music(music: AudioStream, volume = 0.0):
	if stream == music and playing:
		return
	stream = music
	volume_db = volume
	play()

func play_music_level():
	_play_music(level_music)

const battle_music = preload("res://assets/Art/BattleMusic.mp3")

func play_music_battle():
	_play_music(battle_music)
	

var sfx_player = AudioStreamPlayer.new()

const title_music = preload("res://assets/Art/TitleMusic.mp3")

func play_music_title():
	_play_music(title_music)


func _ready():
	add_child(sfx_player)

func play_sfx(sound: AudioStream):
	sfx_player.stream = sound
	sfx_player.play()
