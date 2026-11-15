extends Node

## Plays a whole championship on autopilot and prints what the flow did: each round's
## standings and points, then the final table entry. Run headless:
##   AG_AUTOPILOT=1 AG_NO_MUSIC=1 AG_LAPS=1 godot --headless --path . --fixed-fps 60 tools/flow_probe.tscn
## Prints "FLOW OK" and quits once the championship result reaches the high-score screen.

class Watcher extends Node:
	var _round_seen := -1
	var _wait := 0.0

	func _process(delta: float) -> void:
		var scene := get_tree().current_scene
		if scene is Race:
			var race: Race = scene
			if race.state != Race.State.FINISHED or race._results == null:
				return
			# Let the stragglers finish or time out so the points are settled.
			_wait += delta
			if _wait < 18.0 or Game.champ_round == _round_seen:
				return
			_wait = 0.0
			_round_seen = Game.champ_round
			var line := "round %d  %s:" % [Game.champ_round + 1, TrackDefs.ALL[Game.track_index].name]
			for ship_name in Game.champ_standings():
				line += "  %s %d (+%d)" % [ship_name, Game.champ_points[ship_name], Game.champ_round_points(ship_name)]
			print(line, "   player score so far ", Game.champ_score)
			Game.champ_continue()
		elif scene != null and not Game.last_result.is_empty():
			var key: String = Game.table_key(Game.last_result.track)
			print("final: ", Game.last_result, "  table '", key, "'  qualifies ", Highscores.qualifies(key, int(Game.last_result.score.total)))
			print("FLOW OK")
			get_tree().quit()


func _ready() -> void:
	get_tree().root.add_child.call_deferred(Watcher.new())
	Game.start_championship.call_deferred()
