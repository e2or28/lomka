extends Control

const RoomMap = preload("res://sim/room_map.gd")
const RunState = preload("res://sim/run_state.gd")
const Organs = preload("res://sim/organs.gd")
const Schemas = preload("res://sim/data/schemas.gd")
const Harvest = preload("res://sim/harvest.gd")
const Pickup = preload("res://sim/pickup.gd")

const INK := Color(0.045, 0.055, 0.065, 0.94)
const PAPER := Color(0.94, 0.89, 0.77)
const MUTED := Color(0.59, 0.62, 0.58)
const ACCENT := Color(1.0, 0.59, 0.35)
const MINT := Color(0.63, 0.86, 0.65)
const CELL_WIDTH := 128.0
const GAP := 5.0

var state: RunState = null
var player_index := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _text(at: Vector2, text: String, size_px: int = 14, color: Color = PAPER) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _panel(rect: Rect2, border: Color = Color(0.3, 0.31, 0.27)) -> void:
	draw_rect(rect, INK)
	draw_rect(rect, border, false, 1)


func _draw() -> void:
	if state == null:
		return
	var player := state.actor_of_slot(player_index)
	if player == null:
		return
	var viewport := get_viewport_rect().size
	var slot = state.slots[player_index]
	_panel(Rect2(18, 18, 272, 68))
	_text(Vector2(32, 40), "СЛУЖАЩИЙ  /  P%d" % (player_index + 1), 12, MUTED)
	_text(Vector2(32, 67), "%.0f / %.0f HP" % [player.health, player.max_health()], 22)
	var hp := clampf(player.health / maxf(1, player.max_health()), 0, 1)
	draw_rect(Rect2(176, 53, 96, 8), Color(0.2, 0.22, 0.21))
	draw_rect(Rect2(176, 53, 96 * hp, 8), MINT)
	if player_index == 0:
		_text(Vector2(20, 105), "WASD · идти    Стрелки · стрелять", 12)
		_text(Vector2(20, 123), "F · извлечь    E · подобрать    1 · отладка", 12)
	else:
		_text(Vector2(20, 105), "Левый стик · идти    Правый · стрелять", 12)
		_text(Vector2(20, 123), "X · извлечь    A · подобрать    1 · отладка", 12)
	if state.occupied_count() > 1:
		_text(Vector2(310, 105), "V · игрок и камера", 12, MINT)
	_panel(Rect2(viewport.x - 204, 18, 186, 68), ACCENT.darkened(0.5))
	_text(Vector2(viewport.x - 188, 40), "РОЗЫСК / HEAT", 12, ACCENT)
	_text(Vector2(viewport.x - 188, 69), "%03d" % state.heat, 28, PAPER)
	_draw_map(viewport)
	_draw_boss(viewport)
	if Organs.has_behaviour(slot, "keep_moving"):
		var remaining := maxf(0, (180.0 - slot.stationary_ticks) / 60.0)
		var text := "Сердце курьера · двигайся"
		if slot.stationary_ticks > 0:
			text = "Сердце · до штрафа %.1f с" % remaining if remaining > 0 else "Сердце · −5 HP/с. Двигайся!"
		_panel(Rect2(18, 136, 272, 30), ACCENT.darkened(0.6))
		_text(Vector2(28, 156), text, 13, ACCENT)

	var row := Vector2((viewport.x - (CELL_WIDTH + GAP) * 8 + GAP) / 2, viewport.y - 76)
	var hovered := ""
	for i in Schemas.ORGAN_SLOTS.size():
		var socket: String = Schemas.ORGAN_SLOTS[i]
		var at := row + Vector2(i * (CELL_WIDTH + GAP), 0)
		var rect := Rect2(at, Vector2(CELL_WIDTH, 60))
		var id: String = slot.organs[socket]
		var has_organ := id != ""
		var over := rect.has_point(get_global_mouse_position())
		_panel(rect, ACCENT if over else (MINT.darkened(0.45) if has_organ else MUTED.darkened(0.6)))
		_text(at + Vector2(10, 21), Organs.SLOT_NAMES[socket], 13, PAPER if has_organ else MUTED)
		var short_name := "Обычный"
		if id == "courier_heart": short_name = "Курьера"
		elif id == "armored_spine": short_name = "Бронированный"
		_text(at + Vector2(10, 43), short_name, 12, MINT if has_organ else MUTED.darkened(0.2))
		if over:
			hovered = socket

	var synergies := Organs.active_synergies(slot)
	var caption := "ТЕЛО / P%d   ·   Наведи на слот, чтобы прочитать эффект" % (player_index + 1)
	if not synergies.is_empty():
		var synergy: Dictionary = Organs.SYNERGIES[synergies[0]]
		caption = synergy["name"] + "  ·  " + synergy["description"]
	_panel(Rect2(row + Vector2(0, -28), Vector2((CELL_WIDTH + GAP) * 8 - GAP, 24)))
	_text(row + Vector2(10, -11), caption, 12, MINT if not synergies.is_empty() else MUTED)
	_draw_context(player, slot, row, hovered)
	if state.party_down():
		var at := Vector2(viewport.x * 0.5 - 230, viewport.y * 0.5 - 48)
		_panel(Rect2(at, Vector2(460, 96)), ACCENT)
		_text(at + Vector2(30, 39), "ЗАБЕГ ОКОНЧЕН", 28, ACCENT)
		_text(at + Vector2(30, 70), "R — начать заново", 16)


func _draw_boss(viewport: Vector2) -> void:
	var boss = null
	for actor in state.actors:
		if actor.archetype == "tandem" and actor.alive:
			boss = actor
			break
	if boss == null:
		return
	var at := Vector2(viewport.x * 0.5 - 208, 20)
	_panel(Rect2(at, Vector2(416, 66)), Color(0.48, 0.27, 0.18))
	_text(at + Vector2(15, 24), "ТАНДЕМ  /  МИНИ-БОСС", 14, ACCENT)
	_text(at + Vector2(306, 24), "%.0f / %.0f" % [boss.health, boss.max_health()], 12)
	draw_rect(Rect2(at + Vector2(15, 39), Vector2(386, 10)), Color(0.22, 0.14, 0.12))
	draw_rect(Rect2(at + Vector2(15, 39), Vector2(386 * boss.health / boss.max_health(), 10)), ACCENT)
	if boss.attack_ticks > 0:
		_text(at + Vector2(114, 85), "ВЫСТРЕЛ — УХОДИ С ЛИНИИ", 13, ACCENT)


func _draw_context(player, slot, row: Vector2, hovered: String) -> void:
	var title := ""
	var description := ""
	var footer := ""
	var progress := 0.0
	if not slot.downed:
		var corpse = Harvest.nearest(state, player)
		if corpse != null:
			var record := Organs.organ(corpse.organ_id)
			title = ("F" if player_index == 0 else "X") + "  ДЕРЖАТЬ  ·  " + record["name"]
			description = record["description"]
			var old: String = slot.organs[record["slot"]]
			footer = "+%d HEAT  ·  1 с без движения и стрельбы" % record["heat"]
			if old != "":
				footer += "  ·  Прежний орган останется на полу"
			if slot.harvest_target == corpse.id:
				progress = float(slot.harvest_ticks) / Harvest.DURATION_TICKS
		else:
			var nearest = null
			var shortest := INF
			for pickup in state.pickups:
				var reach: float = pickup.radius + player.radius
				var distance: float = pickup.position.distance_squared_to(player.position)
				if distance <= reach * reach and distance < shortest:
					nearest = pickup
					shortest = distance
			if nearest != null and nearest.kind == Pickup.KIND_ORGAN:
				var record := Organs.organ(nearest.content_id)
				title = ("E" if player_index == 0 else "A") + "  УСТАНОВИТЬ  ·  " + record["name"]
				description = record["description"]
				footer = "Без роста Heat. Прежний орган остаётся на полу."
	if hovered != "":
		var record := Organs.organ(slot.organs[hovered])
		title = Organs.SLOT_NAMES[hovered] + "  /  " + record.get("name", "Обычный орган")
		description = record.get("description", "Без особых эффектов. Найди сильного врага с органом для этого слота.")
		footer = "Органы разных слотов работают вместе."
		progress = 0.0
	if title == "":
		return
	var at := row + Vector2(90, -143)
	_panel(Rect2(at, Vector2(879, 108)), ACCENT.darkened(0.4))
	_text(at + Vector2(16, 27), title, 18, ACCENT)
	_text(at + Vector2(16, 52), description, 15)
	_text(at + Vector2(16, 79), footer, 12, MUTED)
	draw_rect(Rect2(at + Vector2(0, 104), Vector2(879 * progress, 4)), ACCENT)


func _draw_map(viewport: Vector2) -> void:
	if state.room.id == "": return
	var at := Vector2(viewport.x - 204, 98)
	_panel(Rect2(at, Vector2(186, 178)))
	_text(at + Vector2(12, 23), RoomMap.NAMES[state.room.id], 16)
	var positions := {"center": Vector2(0, 0), "north": Vector2(0, -1),
		"south": Vector2(0, 1), "west": Vector2(-1, 0), "east": Vector2(1, 0)}
	for id in RoomMap.IDS:
		var cell: Vector2 = at + Vector2(80, 71) + positions[id] * 27
		var color := MINT if id == state.room.id else MUTED.darkened(0.55)
		if id != state.room.id and state.room_states.has(id): color = MUTED
		draw_rect(Rect2(cell, Vector2(23, 20)), color)
		if id == "north": _text(cell + Vector2(7, 15), "!", 14, INK)
	_text(at + Vector2(12, 138), "Проходы открыты" if state.room_cleared() else "Зачисти комнату для выхода", 11, MINT if state.room_cleared() else ACCENT)
	_text(at + Vector2(12, 159), "↑ Главный зал" if state.room.id == "south" else "Иди к зелёной стрелке", 11, MUTED)
