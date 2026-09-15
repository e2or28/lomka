extends RefCounted

const Attacks = preload("res://sim/guard_attacks.gd")
const ShotGeometry = preload("res://sim/shot_geometry.gd")
const SpriteMesh = preload("res://game/sprite_mesh.gd")
const Reinforcements = preload("res://sim/reinforcements.gd")
const ROOT := Vector2(80, 194)
const HEIGHT := 156.0
## Дубинка идёт вниз быстро, а корпус возвращается медленно: удар должен
## читаться как удар, а не как покачивание.
const STRIKE := 0.11
const RECOVER := 0.46
## Пояс: ниже него кадр стоит на месте, выше — валится вперёд.
const WAIST := 124.0
## Стрелок держит кадр выстрела дольше, чем длится сам выстрел: иначе
## вспышка мелькает на один кадр и читается как рябь.
const FIRE_HOLD := 0.38
## Скорость, на которой шаг уже виден. Ниже неё охрана стоит.
const STRIDE_SPEED := 24.0
## Сетка на бойца, а не одна на всех: агентов двое, бить они могут
## одновременно, и общий меш второй из них затёр бы первому до отрисовки.
static var _surfaces: Dictionary = {}
const SPRITES := ["oil_baron", "soldier", "soldier_front", "soldier_dark", "soldier_dark_front",
	"soldier_fire", "soldier_fire_front", "soldier_dark_fire", "soldier_dark_fire_front",
	"soldier_kneel", "soldier_kneel_front", "soldier_dark_kneel", "soldier_dark_kneel_front",
	"ice_agent", "ice_agent_front", "ice_agent_windup", "ice_agent_windup_front",
	"helicopter", "helicopter_wreck", "soldier_rope", "soldier_dark_rope", "barrel"]


static func handles(actor) -> bool:
	return Attacks.PROFILES.has(actor.behaviour) or actor.behaviour == "prop"


## Время, прошедшее с удара дубинкой, или -1 вне удара. Отсчёт идёт от
## остатка восстановления, а не от своего таймера: сейв и сеть сохраняют
## cooldown, и фаза после загрузки совпадает с тем, что было до неё.
static func strike_age(actor) -> float:
	if not actor.alive or actor.behaviour != "baton" or actor.attack_ticks > 0:
		return -1.0
	var age: float = float(Attacks.PROFILES.baton.recovery) - float(actor.cooldown)
	return age if actor.cooldown > 0.0 and age < STRIKE + RECOVER else -1.0


## Наклон корпуса: вниз за STRIKE, обратно за RECOVER.
static func strike_lean(age: float) -> float:
	if age < 0.0:
		return 0.0
	if age < STRIKE:
		return smoothstep(0.0, STRIKE, age) * 0.42
	return lerpf(0.42, 0.0, smoothstep(STRIKE, STRIKE + RECOVER, age))


## Кадр замаха валится вперёд вокруг пояса — дубинка описывает дугу вниз.
## Ноги остаются на месте: боец бьёт, а не падает.
static func strike_point(p: Vector2, lean: float) -> Vector2:
	if lean == 0.0 or p.y >= WAIST:
		return p
	var bend := 1.0 - smoothstep(64.0, WAIST, p.y)
	var pivot := Vector2(ROOT.x, WAIST)
	return pivot + (p - pivot).rotated(lean * bend)


## Время с выстрела, или -1 вне выстрела. Как и удар, считается от остатка
## восстановления: сейв и сеть хранят cooldown, а не свой таймер.
static func fire_age(actor) -> float:
	if not actor.alive or actor.behaviour != "rifleman" or actor.attack_ticks > 0:
		return -1.0
	var age: float = float(Attacks.PROFILES.rifleman.recovery) - float(actor.cooldown)
	return age if actor.cooldown > 0.0 and age < FIRE_HOLD else -1.0


## Шаг охраны. Кадров ходьбы в наборе нет, поэтому ноги отрываются от пола
## попеременно из той же стойки, а корпус оседает в такт шагу.
static func stride_point(p: Vector2, phase: float, amount: float) -> Vector2:
	if amount <= 0.0:
		return p
	var result := p
	if p.y >= WAIST:
		var leg := smoothstep(WAIST, 188.0, p.y)
		var lift: float = maxf(0.0, sin(phase + (0.0 if p.x < ROOT.x else PI)))
		result.y -= pow(lift, 1.3) * 7.5 * leg * amount
	else:
		result.y -= absf(sin(phase)) * 1.7 * amount
		result.x += sin(phase) * 1.1 * amount
	return result


static func stride_amount(actor) -> float:
	if not actor.alive or actor.attack_ticks > 0:
		return 0.0
	return clampf((actor.velocity.length() - STRIDE_SPEED) / 90.0, 0.0, 1.0)


const RIDING_FALLBACK := "soldier_dark_rope"

static func riding_frame(actor, textures: Dictionary) -> String:
	if not Reinforcements.riding(actor):
		return ""
	var own: String = actor.archetype + "_rope"
	if textures.get(own) != null:
		return own
	return RIDING_FALLBACK if textures.get(RIDING_FALLBACK) != null else ""


static func frame(actor, textures: Dictionary = {}) -> String:
	if actor.behaviour == "prop":
		return actor.archetype
	# Имя записи в бестиарии — gunship, а спрайт Саши называется вертушкой.
	if actor.behaviour == "gunship":
		return "helicopter" if actor.alive else "helicopter_wreck"
	var riding := riding_frame(actor, textures)
	if riding != "": return riding
	var name: String = actor.archetype
	if actor.behaviour == "oil_baron": return name
	var pose := ""
	if actor.alive and actor.behaviour == "baton" and (actor.attack_ticks > 0 or strike_age(actor) >= 0.0):
		pose = "_windup"
	elif actor.alive and actor.behaviour == "rifleman":
		if actor.attack_ticks > 0: pose = "_kneel"
		elif fire_age(actor) >= 0.0: pose = "_fire"
	var tail := "_front" if actor.standing_front else ""
	if pose != "" and not textures.is_empty() and textures.get(name + pose + tail) == null:
		pose = ""
	return name + pose + tail


static func root_for(actor, size: Vector2) -> Vector2:
	if actor.behaviour in ["oil_baron", "gunship", "prop"]:
		return Vector2(size.x * 0.5, size.y)
	return ROOT


static func draw(view: Node2D, textures: Dictionary, actor, at: Vector2, tint: Color,
		phase: float = 0.0) -> bool:
	var chosen := frame(actor, textures)
	var sprite: Texture2D = textures.get(chosen)
	if sprite == null: return false
	var side: float = 1.0 if actor.standing_front or actor.behaviour == "oil_baron" else float(actor.facing)
	if not actor.alive: tint *= Color(0.48, 0.43, 0.39)
	var lift := Reinforcements.rope_height(actor)
	var root := root_for(actor, sprite.get_size())
	if Reinforcements.riding(actor):
		# У старого тёмного кадра обрезанный холст; совмещаем оба по кисти.
		var palm := Vector2(80, 28) if chosen == "soldier_rope" else Vector2(52, 26)
		root.x = palm.x
		rope(view, at, lift, textures.get("rope"), tint, root.y - palm.y)
	view.draw_set_transform(at - Vector2(0, lift), 0.0, Vector2(side, 1))
	var lean := strike_lean(strike_age(actor))
	# Анфас бьёт на зрителя, и поворот вокруг пояса там читается слабо:
	# наклон уменьшен, зато корпус заметнее оседает.
	if actor.standing_front: lean *= 0.45
	var walk := stride_amount(actor)
	if lean != 0.0 or walk > 0.0:
		var surface: SpriteMesh = _surfaces.get(actor.id)
		if surface == null:
			surface = SpriteMesh.new()
			_surfaces[actor.id] = surface
		surface.prepare(sprite.get_size())
		var vertices := PackedVector2Array()
		for p in surface.points:
			var moved := stride_point(p, phase, walk)
			vertices.append(strike_point(moved, lean) - root + Vector2(0, lean * 9.0))
		surface.draw(view, sprite, vertices, tint)
	else:
		view.draw_texture(sprite, -root, tint)
	view.draw_set_transform(Vector2.ZERO)
	return true


static func warning(view: Node2D, actor, origin: Vector2) -> void:
	if actor.attack_ticks <= 0: return
	var profile: Dictionary = Attacks.PROFILES[actor.behaviour]
	var strength := 1.0 - float(actor.attack_ticks) / float(profile.windup)
	var at: Vector2 = origin + actor.position
	var color := Color(1.0, 0.58, 0.19, 0.35 + strength * 0.5)
	if actor.behaviour == "baton":
		var center: float = actor.attack_aim.angle()
		var points := PackedVector2Array([at])
		for i in 21:
			points.append(at + Vector2.RIGHT.rotated(center - Attacks.MELEE_HALF_ANGLE \
				+ 2 * Attacks.MELEE_HALF_ANGLE * i / 20.0) * Attacks.MELEE_REACH)
		view.draw_colored_polygon(points, Color(color, 0.10 + strength * 0.10))
		view.draw_arc(at, Attacks.MELEE_REACH, center - Attacks.MELEE_HALF_ANGLE,
			center + Attacks.MELEE_HALF_ANGLE, 24, color, 2)
	else:
		var reach := float(actor.stack.compute().get("range", 850.0))
		var from := at + ShotGeometry.offset(profile.kind, actor.attack_aim, actor.facing, actor.standing_front)
		for angle in profile.angles:
			var direction: Vector2 = actor.attack_aim.rotated(angle)
			view.draw_dashed_line(from, from + direction * reach, color, 1.5, 13)
	view.draw_arc(at, actor.radius + 7, -PI / 2, -PI / 2 + TAU * strength, 32, color, 3)


static func clear() -> void:
	_surfaces.clear()


## Канат от рук бойца до высоты, на которой висит вертушка. Верх берётся от
## точки высадки, а не от самой машины: она за время спуска смещается, и
## канат отрывался бы от её брюха.
static func rope(view: Node2D, at: Vector2, lift: float, texture: Texture2D, tint: Color, hand_height: float = HEIGHT * 0.86) -> void:
	var top := at - Vector2(0, Reinforcements.ROPE_HEIGHT + hand_height)
	var hands := at - Vector2(0, lift + hand_height)
	if texture == null:
		view.draw_line(top, hands, Color(0.62, 0.52, 0.3, tint.a), 3.0)
		return
	var width := texture.get_width()
	view.draw_texture_rect(texture, Rect2(top.x - width * 0.5, top.y, width, hands.y - top.y),
		true, tint)


## Десант в проёме вертушки: уменьшенный, потому что боец в полный рост
## выше её борта и торчал бы над обшивкой во весь свой рост.
const CABIN_SCALE := 0.42
const CABIN_AT := Vector2(-26.0, -52.0)
const CABIN_STEP := 30.0

static func cabin(view: Node2D, textures: Dictionary, at: Vector2, side: float,
		tint: Color, squad: int) -> void:
	var seated: Texture2D = textures.get("soldier_kneel")
	if seated == null:
		return
	for i in mini(squad, 2):
		var offset := Vector2((CABIN_AT.x - i * CABIN_STEP) * side, CABIN_AT.y)
		view.draw_set_transform(at + offset, 0.0, Vector2(side * CABIN_SCALE, CABIN_SCALE))
		view.draw_texture(seated, -ROOT, tint)
		view.draw_set_transform(Vector2.ZERO)
