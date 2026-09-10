extends Control

const RoomMap = preload("res://sim/room_map.gd")
const RunState = preload("res://sim/run_state.gd")
const Organs = preload("res://sim/organs.gd")
const Schemas = preload("res://sim/data/schemas.gd")
const Revive = preload("res://sim/revive.gd")
const Harvest = preload("res://sim/harvest.gd")
const Pickup = preload("res://sim/pickup.gd")
const Items = preload("res://sim/items.gd")
const Bestiary = preload("res://sim/bestiary.gd")

const INK := Color(0.045, 0.055, 0.065, 0.94)
const PAPER := Color(0.94, 0.89, 0.77)
const MUTED := Color(0.59, 0.62, 0.58)
const ACCENT := Color(1.0, 0.59, 0.35)
const MINT := Color(0.63, 0.86, 0.65)
const CELL_WIDTH := 128.0
const GAP := 5.0

var state: RunState = null
var player_index := 0
var keyboard_slot := 0
var network_mode := false
var can_restart := true


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
	if player_index == keyboard_slot:
		_text(Vector2(20, 105), "WASD · идти    Стрелки · стрелять", 12)
		_text(Vector2(20, 123), "F · извлечь   E · подобрать   Пробел · перерыв   1 · отладка", 12)
	else:
		_text(Vector2(20, 105), "Левый стик · идти    Правый · стрелять", 12)
		_text(Vector2(20, 123), "X · извлечь   A · подобрать   LB · перерыв   1 · отладка", 12)
	if state.occupied_count() > 1 and not network_mode:
		_text(Vector2(310, 105), "V · игрок и камера", 12, MINT)
	_panel(Rect2(viewport.x - 204, 18, 186, 68), ACCENT.darkened(0.5))
	_text(Vector2(viewport.x - 188, 40), "РОЗЫСК / HEAT", 12, ACCENT)
	_text(Vector2(viewport.x - 188, 69), "%03d" % state.heat, 28, PAPER)
	_draw_map(viewport)
	_draw_boss(viewport)
	_draw_reinforcements(viewport)
	if Organs.has_behaviour(slot, "keep_moving"):
		var remaining := maxf(0, (180.0 - slot.stationary_ticks) / 60.0)
		var text := "Сердце курьера · двигайся"
		if slot.stationary_ticks > 0:
			text = "Сердце · до штрафа %.1f с" % remaining if remaining > 0 else "Сердце · −5 HP/с. Двигайся!"
		_panel(Rect2(18, 136, 272, 30), ACCENT.darkened(0.6))
		_text(Vector2(28, 156), text, 13, ACCENT)

	var hovered_item := _draw_items(slot)
	_draw_skill(slot)

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
		_text(at + Vector2(10, 43), _short_name(id), 12, MINT if has_organ else MUTED.darkened(0.2))
		if over:
			hovered = socket

	var synergies := Organs.active_synergies(slot)
	var caption := "ТЕЛО / P%d   ·   Наведи на слот, чтобы прочитать эффект" % (player_index + 1)
	if not synergies.is_empty():
		var synergy: Dictionary = Organs.SYNERGIES[synergies[0]]
		caption = synergy["name"] + "  ·  " + synergy["description"]
	_panel(Rect2(row + Vector2(0, -28), Vector2((CELL_WIDTH + GAP) * 8 - GAP, 24)))
	_text(row + Vector2(10, -11), caption, 12, MINT if not synergies.is_empty() else MUTED)
	_draw_context(player, slot, row, hovered, hovered_item)
	if state.party_down():
		var at := Vector2(viewport.x * 0.5 - 230, viewport.y * 0.5 - 48)
		_panel(Rect2(at, Vector2(460, 96)), ACCENT)
		_text(at + Vector2(30, 39), "ЗАБЕГ ОКОНЧЕН", 28, ACCENT)
		_text(at + Vector2(30, 70), "R — начать заново" if can_restart else "Ведущий может начать новый забег", 16)


func _draw_reinforcements(viewport: Vector2) -> void:
	if state.pending_spawns.is_empty(): return
	var remaining := maxf(0.0, (float(state.pending_spawns[0].spawn_tick) - state.tick) / 60.0)
	var at := Vector2(viewport.x * 0.5 - 200, 100)
	_panel(Rect2(at, Vector2(400, 44)), ACCENT)
	_text(at + Vector2(14, 28), "ПОДКРЕПЛЕНИЕ · %d · через %.1f с" % [state.pending_spawns.size(), remaining], 16, ACCENT)


func _draw_boss(viewport: Vector2) -> void:
	var boss = null
	for actor in state.actors:
		if actor.archetype in ["tandem", "oil_baron"] and actor.alive:
			boss = actor
			break
	if boss == null:
		return
	var at := Vector2(viewport.x * 0.5 - 208, 20)
	_panel(Rect2(at, Vector2(416, 66)), Color(0.48, 0.27, 0.18))
	_text(at + Vector2(15, 24), "НЕФТЯНОЙ БАРОН" if boss.archetype == "oil_baron" else "ТАНДЕМ  /  МИНИ-БОСС", 14, ACCENT)
	_text(at + Vector2(306, 24), "%.0f / %.0f" % [boss.health, boss.max_health()], 12)
	draw_rect(Rect2(at + Vector2(15, 39), Vector2(386, 10)), Color(0.22, 0.14, 0.12))
	draw_rect(Rect2(at + Vector2(15, 39), Vector2(386 * boss.health / boss.max_health(), 10)), ACCENT)
	if boss.attack_ticks > 0:
		_text(at + Vector2(114, 85), "ЗАЛП — УХОДИ С ЛИНИЙ" if boss.archetype == "oil_baron" else "ВЫСТРЕЛ — УХОДИ С ЛИНИИ", 13, ACCENT)


func _short_name(id: String) -> String:
	var name: String = Organs.organ(id).get("name", "")
	if name == "": return "Обычный"
	var words := name.split(" ")
	return words[words.size() - 1].capitalize()


## Собранные предметы: карточка с буквой, число повторов углом.
func _draw_items(slot) -> String:
	if slot.items.is_empty(): return ""
	var counts := {}
	for id in slot.items: counts[id] = int(counts.get(id, 0)) + 1
	_panel(Rect2(18, 176, 272, 52), MINT.darkened(0.6))
	_text(Vector2(28, 194), "ПРЕДМЕТЫ", 11, MUTED)
	var hovered := ""
	var i := 0
	for id in counts:
		var rect := Rect2(28 + i * 34, 199, 30, 22)
		var over := rect.has_point(get_global_mouse_position())
		draw_rect(rect, PAPER.darkened(0.1) if over else PAPER.darkened(0.35))
		_text(rect.position + Vector2(5, 16), Items.item(id).get("badge", "?"), 14, INK)
		if int(counts[id]) > 1:
			_text(rect.position + Vector2(20, 9), "%d" % counts[id], 10, INK)
		if over: hovered = id
		i += 1
	return hovered


func _draw_skill(slot) -> void:
	if Bestiary.character(slot.character_id).get("skill", "") != "lunch_break": return
	var text := "ПЕРЕРЫВ · чемодан готов"
	var color := MINT
	if slot.cover_ticks > 0:
		text = "ПЕРЕРЫВ · чемодан стоит %.1f с" % (slot.cover_ticks / 60.0)
		color = ACCENT
	elif slot.skill_cooldown_ticks > 0:
		text = "ПЕРЕРЫВ · снова через %.1f с" % (slot.skill_cooldown_ticks / 60.0)
		color = MUTED
	var top := 176.0 if slot.items.is_empty() else 234.0
	_panel(Rect2(18, top, 272, 30), color.darkened(0.6))
	_text(Vector2(28, top + 20), text, 12, color)


func _draw_context(player, slot, row: Vector2, hovered: String, hovered_item: String) -> void:
	var title := ""
	var description := ""
	var compare := ""
	var footer := ""
	var progress := 0.0
	if not slot.downed:
		var corpse = Harvest.nearest(state, player)
		if corpse != null:
			var record := Organs.organ(corpse.organ_id)
			title = ("F" if player_index == keyboard_slot else "X") + "  ДЕРЖАТЬ  ·  " + record["name"]
			description = record["description"]
			compare = _instead_of(slot, record["slot"])
			footer = "+%d HEAT  ·  1 с без движения и стрельбы" % record["heat"]
			if slot.harvest_target == corpse.id:
				progress = float(slot.harvest_ticks) / Harvest.DURATION_TICKS
		else:
			var nearest = Pickup.nearest(state, player)
			var key := "E" if player_index == keyboard_slot else "A"
			if nearest != null and nearest.kind == Pickup.KIND_ORGAN:
				var record := Organs.organ(nearest.content_id)
				title = key + "  УСТАНОВИТЬ  ·  " + record["name"]
				description = record["description"]
				compare = _instead_of(slot, record["slot"])
				footer = "Без роста Heat. Прежний орган остаётся на полу."
			elif nearest != null and nearest.kind == Pickup.KIND_ITEM:
				var record := Items.item(nearest.content_id)
				title = key + "  ВЗЯТЬ  ·  " + record["name"]
				description = record["description"]
				footer = "Предмет остаётся до конца забега. Одинаковые складываются."
	if hovered_item != "":
		var record := Items.item(hovered_item)
		title = "ПРЕДМЕТ  /  " + record["name"]
		description = record["description"]
		compare = ""
		footer = "Предметы работают вместе с органами."
		progress = 0.0
	if hovered != "":
		var record := Organs.organ(slot.organs[hovered])
		title = Organs.SLOT_NAMES[hovered] + "  /  " + record.get("name", "Обычный орган")
		description = record.get("description", "Без особых эффектов. Найди сильного врага с органом для этого слота.")
		compare = ""
		footer = "Органы разных слотов работают вместе, одного слота — вытесняют друг друга."
		progress = 0.0
	var teammate = Revive.nearest(state, player) if not slot.downed else null
	if teammate != null:
		title = ("E" if player_index == keyboard_slot else "A") + "  ДЕРЖАТЬ · ПОДНЯТЬ P%d" % (teammate.slot + 1)
		description = "5 секунд рядом без движения и стрельбы"
		compare = ""
		footer = "Отпустишь кнопку или отойдёшь — подъём начнётся заново."
		progress = float(slot.revive_ticks) / Revive.DURATION_TICKS
	elif slot.downed:
		title = "ВЫ УПАЛИ · ждите товарища"
		description = "Товарищ может поднять вас за 5 секунд, удерживая E / A рядом."
		compare = ""
		footer = "После подъёма: 30% здоровья и короткая защита от урона."
		progress = 0.0
		for helper in state.slots:
			if helper.revive_target == player.id:
				progress = float(helper.revive_ticks) / Revive.DURATION_TICKS
				title = "ВАС ПОДНИМАЕТ P%d" % (helper.index + 1)
	if title == "":
		return
	var height := 128.0 if compare != "" else 104.0
	var at := row + Vector2(90, -35 - height)
	_panel(Rect2(at, Vector2(879, height)), ACCENT.darkened(0.4))
	_text(at + Vector2(16, 27), title, 18, ACCENT)
	_text(at + Vector2(16, 52), description, 15)
	if compare != "":
		_text(at + Vector2(16, 76), compare, 13, MINT)
	_text(at + Vector2(16, height - 28), footer, 12, MUTED)
	draw_rect(Rect2(at + Vector2(0, height - 4), Vector2(879 * progress, 4)), ACCENT)


## Слот один, органов на него несколько: без этой строки замена сердца
## выглядит бесплатной, а она снимает прежние эффекты и сочетания.
func _instead_of(slot, socket: String) -> String:
	var old: String = slot.organs.get(socket, "")
	if old == "":
		return "Слот «%s» пуст." % Organs.SLOT_NAMES[socket]
	var record := Organs.organ(old)
	return "Вместо: %s — %s" % [record["name"], record["description"]]


func _draw_map(viewport: Vector2) -> void:
	if state.room.id == "": return
	var at := Vector2(viewport.x - 204, 98)
	_panel(Rect2(at, Vector2(186, 178)))
	_text(at + Vector2(12, 23), RoomMap.NAMES[state.room.id], 16)
	var positions := {"center": Vector2(0, 0), "north": Vector2(0, -1),
		"south": Vector2(0, 1), "west": Vector2(-2, 0), "east": Vector2(1, 0),
		"oil_baron": Vector2(-1, 0)}
	for id in RoomMap.IDS:
		var cell: Vector2 = at + Vector2(80, 84) + positions[id] * 24
		var color := MINT if id == state.room.id else MUTED.darkened(0.55)
		if id != state.room.id and state.room_states.has(id): color = MUTED
		draw_rect(Rect2(cell, Vector2(23, 20)), color)
		if id in ["north", "oil_baron"]: _text(cell + Vector2(7, 15), "!", 14, INK)
	_text(at + Vector2(12, 138), "Проходы открыты" if state.room_cleared() else "Зачисти комнату для выхода", 11, MINT if state.room_cleared() else ACCENT)
	_text(at + Vector2(12, 159), "↑ Главный зал" if state.room.id == "south" else "Иди к зелёной стрелке", 11, MUTED)
