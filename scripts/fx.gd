class_name Fx

## Small shared effects: a soft glow sprite, an expanding shock ring, spark emitters.
## Plain statics, no autoload, so ship.gd can use them from a `-s` script too.

static var _soft: GradientTexture2D
static var _ring_shader: Shader = preload("res://shaders/ring.gdshader")


## Radial falloff sprite, white, alpha 1 in the centre.
static func soft_texture() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 64
		_soft.height = 64
	return _soft


## Additive, unshaded glow quad lying in its local XZ plane.
static func glow_quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = soft_texture()
	mat.albedo_color = color
	mat.disable_fog = true
	var quad := PlaneMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A shock ring that expands in the XY plane of `at` and fades: boosts, pickups, blasts.
static func ring(parent: Node, at: Transform3D, color: Color, size := 6.0, seconds := 0.45) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("progress", 0.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_transform = at
	var tween := mi.create_tween()
	tween.tween_property(mat, ^"shader_parameter/progress", 1.0, seconds)
	tween.tween_callback(mi.queue_free)


## Sparks thrown off a wall: off until `emitting` is set, emits in world space.
static func sparks(amount := 48) -> GPUParticles3D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 0.85, 1), Color(1, 0.8, 0.3, 1), Color(1, 0.35, 0.05, 0.7), Color(0.6, 0.1, 0.0, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.5, 1)
	pm.spread = 38.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -24.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color_ramp = ramp_tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = soft_texture()
	mat.albedo_color = Color(2.5, 2.0, 1.4)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.55
	p.local_coords = false
	p.emitting = false
	p.process_material = pm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
