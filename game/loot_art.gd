extends RefCounted
## Лут на полу: тень, спрайт или карточка и подпись подбора.
##
## Лежит на полу, поэтому рисуется до тел: подошедший накрывает его собой.
## Напольный спрайт крупнее оружия в руке, чтобы лут читался на пёстром полу.

const Pickup = preload("res://sim/pickup.gd")
const Organs = preload("res://sim/organs.gd")
const Items = preload("res://sim/items.gd")
const Arsenal = preload("res://sim/arsenal.gd")
const OrganArt = preload("res://game/organ_art.gd")

const PAPER := Color(0.93, 0.88, 0.72)


static func draw(view: Node2D, textures: Dictionary, pickup: Pickup, at: Vector2,
		highlighted: bool, key: String) -> void:
	var ground: Texture2D = textures.get(pickup.content_id + "_ground")
	view.draw_set_transform(at, 0.0, Vector2(1.0, 0.34))
	view.draw_circle(Vector2.ZERO, 28.0 if ground != null else pickup.radius * 0.7,
		Color(0.0, 0.0, 0.0, 0.28))
	view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var sprite: Texture2D = ground if ground != null else textures.get(pickup.content_id + "_top")
	if pickup.kind == Pickup.KIND_ORGAN:
		if not OrganArt.draw_ground(view, textures, pickup.content_id, at):
			_badge(view, at, Organs.organ(pickup.content_id).get("badge", "?"))
	elif pickup.kind == Pickup.KIND_ITEM:
		_badge(view, at, Items.item(pickup.content_id).get("badge", "?"))
	elif sprite != null:
		var size := sprite.get_size()
		if ground != null:
			size *= 54.0 / size.x
		view.draw_texture_rect(sprite, Rect2(at - size * 0.5, size), false)
	else:
		view.draw_rect(Rect2(at - Vector2(9, 4), Vector2(18, 8)), PAPER, true)

	if not highlighted:
		return
	view.draw_arc(at, pickup.radius, 0, TAU, 28, Color(1, 1, 1, 0.35), 1.5)
	var caption := key + " · " + _name_of(pickup)
	var width := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var label_at := at + Vector2(-width * 0.5, -pickup.radius - 6)
	view.draw_rect(Rect2(label_at + Vector2(-5, -14), Vector2(width + 10, 19)), Color(0.04, 0.04, 0.04, 0.8))
	view.draw_string(ThemeDB.fallback_font, label_at,
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.89, 0.65))


static func _name_of(pickup: Pickup) -> String:
	match pickup.kind:
		Pickup.KIND_ORGAN:
			return Organs.organ(pickup.content_id).get("name", pickup.content_id)
		Pickup.KIND_ITEM:
			return Items.item(pickup.content_id).get("name", pickup.content_id)
	return Arsenal.weapon(pickup.content_id).get("name", pickup.content_id)


## Карточка с буквой — заглушка до спрайтов Саши, см. art/README.md.
static func _badge(view: Node2D, at: Vector2, badge: String) -> void:
	var card := Rect2(at - Vector2(17, 21), Vector2(34, 42))
	view.draw_rect(card, PAPER, true)
	view.draw_rect(card, Color(0.2, 0.18, 0.15), false, 1.5)
	var width := ThemeDB.fallback_font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	view.draw_string(ThemeDB.fallback_font, at + Vector2(-width * 0.5, 9), badge,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.16, 0.15, 0.14))
