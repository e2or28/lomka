extends RefCounted
var open_progress := 0.0
var _initialized := false

func clear() -> void:
	open_progress = 0.0
	_initialized = false

func advance(state, delta: float) -> void:
	var opened: bool = state.room_cleared()
	if not _initialized:
		open_progress = 1.0 if opened else 0.0
		_initialized = true
	elif opened:
		open_progress = minf(1.0, open_progress + delta / 0.42)
	else:
		open_progress = 0.0
