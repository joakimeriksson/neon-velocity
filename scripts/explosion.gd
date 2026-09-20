class_name Explosion
extends Node3D

## One-shot burst: additive spark particles, a light flash, then frees itself.

static var _spark_tex: GradientTexture2D


static func spawn(parent: Node, pos: Vector3, size := 1.0, color := Color(1.0, 0.55, 0.15)) -> void:
	var e := Explosion.new()
	parent.add_child(e)
	e.global_position = pos
	e._build(size, color)


func _build(size: float, color: Color) -> void:
	if _spark_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
		_spark_tex = GradientTexture2D.new()
		_spark_tex.gradient = g
		_spark_tex.fill = GradientTexture2D.FILL_RADIAL
		_spark_tex.fill_from = Vector2(0.5, 0.5)
		_spark_tex.fill_to = Vector2(0.5, 0.0)
		_spark_tex.width = 64
		_spark_tex.height = 64

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(color.lightened(0.5), 0.9), Color(color, 0.8), Color(color.darkened(0.4), 0.45), Color(0.2, 0.05, 0.0, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5 * size
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 6.0 * size
	pm.initial_velocity_max = 22.0 * size
	pm.damping_min = 8.0
	pm.damping_max = 14.0
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.7 * size
	pm.scale_max = 2.0 * size
	pm.color_ramp = ramp_tex

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _spark_tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = mat

	var p := GPUParticles3D.new()
	p.amount = int(40 + 30 * size)
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.process_material = pm
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true

	var light := OmniLight3D.new()
	light.light_color = color.lightened(0.3)
	light.light_energy = 6.0 * size
	light.omni_range = 30.0 * size
	light.shadow_enabled = false
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, ^"light_energy", 0.0, 0.4)
	tween.tween_interval(0.8)
	tween.tween_callback(queue_free)
