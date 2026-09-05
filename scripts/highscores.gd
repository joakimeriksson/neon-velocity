extends Node

## Autoload. Per-circuit top-10 tables, persisted to user://highscores.json.

const PATH := "user://highscores.json"
const MAX_ENTRIES := 10
## Arcade-style seed table so a fresh install has something to beat.
const SEED := [["ACE", 1400], ["ZED", 1150], ["KAI", 900], ["RIO", 650], ["NUL", 400]]

var tables := {}  # track name -> Array[Dictionary] sorted by score desc


func _ready() -> void:
	_load()


func top(track: String) -> Array:
	if not tables.has(track):
		tables[track] = []
		for s in SEED:
			tables[track].append({"name": s[0], "score": s[1], "time": 0.0, "best_lap": 0.0, "position": 0})
	return tables[track]


func qualifies(track: String, score: int) -> bool:
	var t := top(track)
	return t.size() < MAX_ENTRIES or score > int(t[-1].score)


## Inserts and returns the 0-based rank, or -1 if it didn't make the table.
func add(track: String, entry: Dictionary) -> int:
	if not qualifies(track, int(entry.score)):
		return -1
	var t := top(track)
	var rank := t.size()
	for i in t.size():
		if int(entry.score) > int(t[i].score):
			rank = i
			break
	t.insert(rank, entry)
	if t.size() > MAX_ENTRIES:
		t.resize(MAX_ENTRIES)
	_save()
	return rank


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		tables = data


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(tables, "\t"))
