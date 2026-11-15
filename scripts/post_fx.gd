class_name PostFx
extends CanvasLayer

## The speed pass (shaders/post_fx.gdshader): drawn over the 3D view and under the HUD.
## Follows one ship; Race points it at the player. Off with the "Speed effects" setting.

var ship: Ship

var _rect: ColorRect
var _mat: ShaderMaterial
var _boost := 0.0
var _hit := 0.0
var _speed := 0.0
var _connected: Ship


func _ready() -> void:
	layer = -1
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/post_fx.gdshader")
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	Settings.changed.connect(func(_key: String): _apply_setting())
	_apply_setting()


func _apply_setting() -> void:
	visible = Settings.get_value("video/speed_fx")


func _process(delta: float) -> void:
	if not visible or ship == null or not is_instance_valid(ship):
		return
	if ship != _connected:
		_connected = ship
		ship.boosted.connect(func(): _boost = 1.0)
		ship.hit_taken.connect(func(_damage: float, _by: String, _weapon: String): _hit = 1.0)
	_boost *= exp(-2.2 * delta)
	_hit *= exp(-5.0 * delta)
	_speed = lerpf(_speed, ship.speed / maxf(ship.max_speed, 1.0), minf(6.0 * delta, 1.0))
	_mat.set_shader_parameter("speed", _speed)
	_mat.set_shader_parameter("boost", _boost)
	_mat.set_shader_parameter("hit", _hit)
	_mat.set_shader_parameter("draft", ship.draft)
