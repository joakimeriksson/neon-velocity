class_name RibbonTrail
extends MeshInstance3D

## A light trail: a flat ribbon laid along the path `source` has travelled, fading and
## narrowing toward its tail. Lives in world space, so it bends through corners behind
## the ship instead of turning with it.

var source: Node3D
var color := Color(0.4, 0.9, 1.0)
var width := 0.15         ## half width at the head, metres
var seconds := 0.4        ## how long a point of the trail lasts
var level := 0.0          ## brightness 0..1+, set by the owner every frame

var _points: Array[Vector3] = []
var _rights: Array[Vector3] = []
var _ages: Array[float] = []
var _mesh := ImmediateMesh.new()

static var _material: StandardMaterial3D
static var _profile: GradientTexture1D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.vertex_color_use_as_albedo = true
		# Soft across its width: a bright core fading out to nothing at both edges.
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.5, 0.65, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_profile = GradientTexture1D.new()
		_profile.gradient = g
		_profile.width = 32
		_material.albedo_texture = _profile
		_material.disable_fog = true
	material_override = _material


## Drop the history: after a teleport the ribbon would otherwise span the jump.
func clear() -> void:
	_points.clear()
	_rights.clear()
	_ages.clear()
	_mesh.clear_surfaces()


func _process(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	for i in _ages.size():
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] > seconds:
		_ages.remove_at(0)
		_points.remove_at(0)
		_rights.remove_at(0)
	var head := source.global_position
	var right := source.global_transform.basis.x.normalized()
	# A new point every 0.6 m of travel; between samples the head rides with the source.
	if _points.is_empty() or _points[-1].distance_squared_to(head) > 0.36:
		_points.append(head)
		_rights.append(right)
		_ages.append(0.0)
	_mesh.clear_surfaces()
	if _points.size() < 2 or level < 0.01:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size() + 1:
		var p := head if i == _points.size() else _points[i]
		var r := right if i == _points.size() else _rights[i]
		var life := 0.0 if i == _points.size() else _ages[i] / seconds
		var fade := pow(1.0 - life, 1.6)
		var c := Color(color.r, color.g, color.b, minf(fade * level, 0.8))
		var w := width * (0.4 + 0.6 * (1.0 - life))
		_mesh.surface_set_color(c)
		_mesh.surface_set_uv(Vector2(0, life))
		_mesh.surface_add_vertex(p - r * w)
		_mesh.surface_set_color(c)
		_mesh.surface_set_uv(Vector2(1, life))
		_mesh.surface_add_vertex(p + r * w)
	_mesh.surface_end()
