extends Node
## Music and SFX management - replaces musicPlay/musicStop/soundPlay GMS2 scripts

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _max_sfx_players := 8

var _current_song: String = ""
var _fade_speed: float = 1.0
var _fading_in: bool = false
var _fading_out: bool = false
var _next_song: String = ""
var _music_volume: float = 1.0

# GMS2: musicPlaySplitted - intro+loop pattern
var _queued_loop_song: String = ""  # GMS2: nextSong - loop track to play after intro ends

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	# Connect finished signal for intro→loop transitions (GMS2: oMusicBox else branch)
	_music_player.finished.connect(_on_music_finished)

	for i in _max_sfx_players:
		var sfx := AudioStreamPlayer.new()
		sfx.bus = "SFX"
		sfx.max_polyphony = 4
		add_child(sfx)
		_sfx_players.append(sfx)

func _process(delta: float) -> void:
	if _fading_out:
		_music_volume -= _fade_speed * delta
		if _music_volume <= 0.0:
			_music_volume = 0.0
			_fading_out = false
			_music_player.stop()
			if _next_song != "":
				var song: String = _next_song
				_next_song = ""
				if _play_song_intro:
					# Intro from play_splitted: play once (no loop)
					_play_song_intro = false
					_play_song_once(song)
				else:
					_play_song(song)
				# GMS2: new track starts at instant full volume after fade-out
			# audio_sound_gain(bgm, 1, 0) — 0ms = instant
			_music_volume = 1.0
			_fading_in = false
		_music_player.volume_db = linear_to_db(_music_volume)

	elif _fading_in:
		_music_volume += _fade_speed * delta
		if _music_volume >= 1.0:
			_music_volume = 1.0
			_fading_in = false
		_music_player.volume_db = linear_to_db(_music_volume)

func play(song_name: String, fade_speed: float = 10.0) -> void:
	if not GameManager.music_enabled:
		return
	if song_name == _current_song:
		return

	_queued_loop_song = ""  # Clear any pending intro→loop transition
	_fade_speed = fade_speed
	if _music_player.playing:
		_next_song = song_name
		_fading_out = true
	else:
		# GMS2: Fresh play starts at full volume instantly
		_music_volume = 1.0
		_fading_in = false
		_play_song(song_name)

func play_now(song_name: String) -> void:
	if not GameManager.music_enabled:
		return
	_fading_in = false
	_fading_out = false
	_queued_loop_song = ""
	_music_volume = 1.0
	_play_song(song_name)

## GMS2: musicPlaySplitted(intro, 0, loop) - play intro once, then auto-transition to loop track
func play_splitted(intro_song: String, loop_song: String, fade_speed: float = 10.0) -> void:
	if not GameManager.music_enabled:
		return

	_queued_loop_song = loop_song  # Queue the loop track for when intro finishes
	_fade_speed = fade_speed
	if _music_player.playing:
		_next_song = intro_song
		_fading_out = true
		# _play_song will be called from _process when fade completes,
		# but we need the intro to NOT loop — handled in _play_song_no_loop
		# Override: use _next_song_no_loop flag
		_play_song_intro = true
	else:
		# GMS2: Fresh play starts at full volume instantly (audio_sound_gain(bgm, 1, 0))
		_music_volume = 1.0
		_fading_in = false
		_play_song_once(intro_song)

var _play_song_intro: bool = false  # Flag: next song from fade should play once (no loop)

func stop(fade_speed: float = 1.0) -> void:
	_fade_speed = fade_speed
	_fading_out = true
	_next_song = ""
	_queued_loop_song = ""

func _play_song(song_name: String) -> void:
	_play_song_internal(song_name, true)

func _play_song_once(song_name: String) -> void:
	## Play a song without looping (for intro tracks in musicPlaySplitted)
	_play_song_internal(song_name, false)

func _play_song_internal(song_name: String, do_loop: bool) -> void:
	var path := ""
	for ext in ["ogg", "mp3", "wav"]:
		var try_path := "res://assets/sounds/%s.%s" % [song_name, ext]
		if ResourceLoader.exists(try_path):
			path = try_path
			break
	if path == "":
		push_warning("Music not found: " + song_name)
		_current_song = song_name  # Prevent repeated warnings
		return

	var stream := load(path) as AudioStream
	if stream:
		# Set looping based on parameter
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = do_loop
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = do_loop
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if do_loop else AudioStreamWAV.LOOP_DISABLED

		_music_player.stream = stream
		_music_player.volume_db = linear_to_db(_music_volume)
		_music_player.play()
		_current_song = song_name
		GameManager.current_music = song_name

func _on_music_finished() -> void:
	## GMS2: oMusicBox else branch - when intro finishes, auto-start loop track
	## "if (!audio_is_playing(bgm) && nextSong != undefined) { ... }"
	if _queued_loop_song != "":
		var loop_song: String = _queued_loop_song
		_queued_loop_song = ""
		# Instant start, no fade (GMS2: gainSpeed = 0, fading = false)
		_music_volume = 1.0
		_fading_in = false
		_fading_out = false
		_play_song(loop_song)  # Play with looping enabled

## GMS2: soundPlay(sound) - singleton sound (does NOT play if same sound already playing)
func play_sfx(sfx_name: String) -> void:
	var path := ""
	for ext in ["ogg", "mp3", "wav"]:
		var try_path := "res://assets/sounds/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(try_path):
			path = try_path
			break
	if path == "":
		return

	var stream := load(path) as AudioStream
	if not stream:
		return

	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# All players busy, use the first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()

## GMS2: soundPlayOverlap(sound) - allows stacking the same sound multiple times
func play_sfx_overlap(sfx_name: String) -> void:
	var path := ""
	for ext in ["ogg", "mp3", "wav"]:
		var try_path := "res://assets/sounds/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(try_path):
			path = try_path
			break
	if path == "":
		return

	var stream := load(path) as AudioStream
	if not stream:
		return

	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# All players busy, use the first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()
