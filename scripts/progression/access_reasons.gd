extends RefCounted

const OK := &"OK"
const UNKNOWN_ENTRY := &"UNKNOWN_ENTRY"
const UNKNOWN_FEATURE := &"UNKNOWN_FEATURE"
const UNKNOWN_ACTION := &"UNKNOWN_ACTION"
const INVALID_CONTEXT := &"INVALID_CONTEXT"
const FEATURE_LOCKED := &"FEATURE_LOCKED"
const HOST_ONLY := &"HOST_ONLY"
const NOT_SESSION_OWNER := &"NOT_SESSION_OWNER"
const TARGET_MISSING := &"TARGET_MISSING"
const INCOMPATIBLE_TARGET := &"INCOMPATIBLE_TARGET"
const STALE_SESSION := &"STALE_SESSION"
const ALREADY_OWNED := &"ALREADY_OWNED"
const DELIVERY_PENDING := &"DELIVERY_PENDING"
const PHASE_BLOCKED := &"PHASE_BLOCKED"
const STATION_BUSY := &"STATION_BUSY"
const ACTOR_BUSY := &"ACTOR_BUSY"
const NO_WORKERS := &"NO_WORKERS"
const MISSING_EQUIPMENT := &"MISSING_EQUIPMENT"
const MISSING_UPGRADE := &"MISSING_UPGRADE"
const ROOM_TOO_SMALL := &"ROOM_TOO_SMALL"
const NO_CAPACITY := &"NO_CAPACITY"
const TRAINING_NOT_READY := &"TRAINING_NOT_READY"
const TOO_FAR := &"TOO_FAR"
const HANDS_BUSY := &"HANDS_BUSY"
const INSUFFICIENT_FUNDS := &"INSUFFICIENT_FUNDS"

static func text(reason_code: StringName, reason_args: Dictionary = {}) -> String:
	match reason_code:
		OK: return ""
		UNKNOWN_ENTRY, UNKNOWN_FEATURE, UNKNOWN_ACTION, INVALID_CONTEXT: return "Действие недоступно."
		FEATURE_LOCKED: return "Эта возможность ещё не открыта."
		HOST_ONLY: return "Покупку подтверждает хозяин кафе."
		NOT_SESSION_OWNER: return "Это действие может завершить только тот, кто его начал."
		TARGET_MISSING: return "Цель больше недоступна."
		INCOMPATIBLE_TARGET: return "Выбранный объект не подходит для этого действия."
		STALE_SESSION: return "Эта операция уже изменилась. Обнови состояние."
		ALREADY_OWNED: return "Уже установлено."
		DELIVERY_PENDING: return "Доставка уже в пути."
		PHASE_BLOCKED: return str(reason_args.get("text", "Сначала заверши текущий этап."))
		STATION_BUSY: return str(reason_args.get("text", "Сначала заверши текущий заказ."))
		ACTOR_BUSY: return str(reason_args.get("text", "Сначала освободи сотрудника."))
		NO_WORKERS: return "Сначала создай или назначь сотрудника."
		MISSING_EQUIPMENT: return str(reason_args.get("text", "Сначала установи нужное оснащение."))
		MISSING_UPGRADE: return str(reason_args.get("text", "Сначала установи предыдущее улучшение."))
		ROOM_TOO_SMALL: return str(reason_args.get("text", "Сначала расширь помещение."))
		NO_CAPACITY: return str(reason_args.get("text", "Нет свободного места."))
		TRAINING_NOT_READY: return str(reason_args.get("text", "Обучение пока не готово к запуску."))
		TOO_FAR: return str(reason_args.get("text", "Подойди ближе."))
		HANDS_BUSY: return "Сначала освободи руки."
		INSUFFICIENT_FUNDS:
			var missing := int(reason_args.get("missing", 0))
			return "Не хватает %d." % missing if missing > 0 else "Не хватает денег."
		_: return str(reason_args.get("text", "Действие недоступно."))
