class_name Projectile
extends Node3D

## Rockets, homing missiles and mines. They ride the track rather than flying in world space:
## position is (distance along the lap, lateral offset), so a rocket follows the road round a
## corner the way Wipeout's do, and a missile steers sideways toward its target's lane.

enum Kind { ROCKET, MISSILE, MINE }

const WEAPON_NAMES := ["ROCKET", "MISSILE", "MINE"]
const DAMAGE := [22.0, 28.0, 16.0]
const LIFETIME := [3.5, 6.0, 25.0]
const HIT_RADIUS := [3.2, 3.4, 3.0]
const COLOR := [Color(1.0, 0.55, 0.15), Color(1.0, 0.25, 0.3), Color(1.0, 0.9, 0.2)]

var kind := Kind.ROCKET
var race: Race
var owner_ship: Ship
var target: Ship
var s := 0.0            ## position along the lap, in track frames
var lateral := 0.0      ## metres right of the centre line
var speed := 150.0      ## m/s along the track

var _age := 0.0
var _mesh: MeshInstance3D
var _voice: AudioStreamPlayer3D
var _voice_pb   # SoundGeneratorPlayback
var _voice_check := 0.0


func _ready() -> void:
	var color: Color = COLOR[kind]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	# Mines stay under the bloom threshold so they read as yellow orbs, not white glare.
	mat.emission_energy_multiplier = 1.3 if kind == Kind.MINE else 4.0
	_mesh = MeshInstance3D.new()
	if kind == Kind.MINE:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		_mesh.mesh = sphere
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.22
		capsule.height = 1.8
		_mesh.mesh = capsule
		_mesh.rotation.x = PI / 2.0   # lie along the direction of travel (-Z)
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 3.0
		light.omni_range = 14.0
		light.shadow_enabled = false
		add_child(light)
		add_child(_make_trail(color))
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_place()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME[kind]:
		if kind != Kind.MINE:
			Explosion.spawn(race, global_position, 0.5, COLOR[kind])
		queue_free()
		return

	_update_voice(delta)
	if kind == Kind.MINE:
		var pulse := 0.8 + 0.2 * sin(_age * 9.0)
		_mesh.scale = Vector3.ONE * pulse
	else:
		s += speed * delta / race.track.step
		if kind == Kind.MISSILE and is_instance_valid(target) and not target.is_eliminated:
			lateral = move_toward(lateral, target.track_lateral, 16.0 * delta)
		var limit := race.track.track_width * 0.5 - 0.8
		lateral = clampf(lateral, -limit, limit)
		_place()

	for ship in race.ships:
		if ship.is_eliminated or ship.weapon_immune():
			continue
		# Your own rocket can't hit you; your own mines can, once they've armed.
		if ship == owner_ship and (kind != Kind.MINE or _age < 1.5):
			continue
		if ship.global_position.distance_to(global_position) < HIT_RADIUS[kind]:
			_hit(ship)
			return


## A rocket carries its motor sound with it (Godot's doppler does the fly-by); an armed mine
## ticks faster the closer a ship gets. Only weapons near the player get a voice.
func _update_voice(delta: float) -> void:
	if not ClassDB.class_exists("SoundGenerator") or Game.attract:
		return
	_voice_check -= delta
	if _voice_check > 0.0 and _voice == null:
		return
	var listener := race.player
	var away := global_position.distance_to(listener.global_position)
	if _voice == null:
		_voice_check = 0.4
		if away > 160.0:
			return
		var gen = ClassDB.class_call_static("SoundGenerator", "from_file", "res://audio/models/%s.toml" % ("mine_armed" if kind == Kind.MINE else "rocket_flight"))
		if gen == null or gen.get_error() != "":
			return
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = gen
		_voice.bus = &"SFX"
		_voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		_voice.unit_size = 10.0
		_voice.max_distance = 220.0
		_voice.volume_db = -6.0
		_voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		add_child(_voice)
		_voice.play()
		_voice_pb = _voice.get_stream_playback()
	elif away > 220.0:
		_voice.queue_free()
		_voice = null
		_voice_pb = null
		return
	if kind == Kind.MINE:
		var nearest := INF
		for ship in race.ships:
			if not ship.is_eliminated:
				nearest = minf(nearest, ship.global_position.distance_to(global_position))
		_voice_pb.set_inputs({"proximity": clampf(1.0 - nearest / 45.0, 0.0, 1.0)})
	else:
		_voice_pb.set_inputs({"thrust": 0.9, "proximity": clampf(1.0 - away / 80.0, 0.0, 1.0)})


func _place() -> void:
	global_transform = race.track.get_point(s, lateral, 1.1 if kind != Kind.MINE else 0.7)


func _hit(ship: Ship) -> void:
	var landed := ship.apply_damage(DAMAGE[kind], owner_ship.ship_name if is_instance_valid(owner_ship) else "", WEAPON_NAMES[kind])
	if landed:
		Explosion.spawn(race, global_position, 1.0, COLOR[kind])
		var blast := "mine_blast" if kind == Kind.MINE else "explosion"
		if ship.is_player:
			Sfx.play(blast)
		else:
			Sfx.play_at(blast, global_position, 1.0, 0.0, 40.0)
	else:
		# Absorbed by a shield.
		Explosion.spawn(race, global_position, 0.5, Items.COLORS[Items.SHIELD])
		Sfx.play_at("shield_block", global_position, 1.0, 0.0, 30.0)
	race.report_hit(owner_ship, ship, WEAPON_NAMES[kind], landed)
	queue_free()


func _make_trail(color: Color) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 8.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.4
	pm.scale_max = 0.8
	pm.color = Color(color, 0.6)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.35
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = Vector3(0, 0, 0.9)
	return p
