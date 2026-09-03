extends RefCounted
## Журнал команд: что игроки нажали и на каком тике.
##
## Нужен трижды. Первое — реплей-тест: прогнать один журнал дважды из одного
## сида и сверить хеш состояния, то есть поймать недетерминизм до того, как
## он станет рассинхроном на M2. Второе — отладка рассинхрона: журнал хоста
## и журнал клиента сравниваются построчно. Третье — запись забега для
## разбора багов, которые воспроизводятся раз в двадцать попыток.

const Command = preload("res://sim/input/command.gd")

## tick -> (slot_index -> Command)
var _frames: Dictionary = {}
var last_tick: int = -1


func record(slot_index: int, command: Command) -> void:
	if not _frames.has(command.tick):
		_frames[command.tick] = {}
	_frames[command.tick][slot_index] = command
	last_tick = maxi(last_tick, command.tick)


## Отсутствующий слот значит «ничего не нажимал», а не «пропусти тик».
func frame(tick: int) -> Dictionary:
	return _frames.get(tick, {})


func size() -> int:
	return _frames.size()


func to_dict() -> Dictionary:
	var ticks := _frames.keys()
	ticks.sort()
	var frames_out: Array = []
	for tick in ticks:
		var slots: Dictionary = _frames[tick]
		var slot_indices := slots.keys()
		slot_indices.sort()
		var entries: Array = []
		for slot_index in slot_indices:
			entries.append({
				"command": slots[slot_index].to_dict(),
				"slot": slot_index,
			})
		frames_out.append({"entries": entries, "tick": tick})
	return {"frames": frames_out}


static func from_dict(data: Dictionary):
	var journal := new()
	for frame_data in data.get("frames", []):
		for entry in frame_data.get("entries", []):
			journal.record(int(entry["slot"]), Command.from_dict(entry["command"]))
	return journal
