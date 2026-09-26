extends RefCounted

const EXPLANATIONS: Array[Dictionary] = [
	{"id":"p5.clone_core","stage":1,"feature_ids":["clone_lab"],"milestone_ids":[],"title":"Первый помощник","text":"Собери три детали лаборатории. Стандартная формула уже подходит для первого клона. После выращивания подготовь ему стол и покажи одно блюдо.","superseded_milestones":["first_live_lesson_accepted"],"superseded_features":[]},
	{"id":"p5.personal_learning","stage":1,"feature_ids":[],"milestone_ids":["first_live_lesson_accepted"],"title":"Личный урок принят","text":"Способ запомнил именно этот работник. Оставь его за оснащённым столом и дождись первого самостоятельного заказа.","superseded_milestones":["first_auto_served"],"superseded_features":[]},
	{"id":"p5.first_automation","stage":1,"feature_ids":[],"milestone_ids":["first_auto_served"],"title":"Клон начал зарабатывать","text":"Теперь он повторяет твой способ и обслуживает гостей. Вырасти второго помощника и передай работникам три стартовых блюда.","superseded_milestones":["first_masterclass_saved"],"superseded_features":["video_recording"]},
	{"id":"p5.video_recording","stage":2,"feature_ids":["video_recording"],"milestone_ids":[],"title":"Один показ — много учеников","text":"Запиши знакомое блюдо на шеф-стойке: E → Мастер-класс. Сохранённый фильм позволит учить других работников без нового личного показа.","superseded_milestones":["first_masterclass_saved"],"superseded_features":[]},
	{"id":"p5.video_learning","stage":2,"feature_ids":["video_training"],"milestone_ids":[],"title":"Покажи фильм работнику","text":"Установи телевизор в комнате отдыха. Компьютер → Обучение: выбери один стол и добавь фильм в очередь. Затем проверь работу ученика на заказе.","superseded_milestones":["first_video_trained_auto_served"],"superseded_features":[]},
	{"id":"p5.group_learning","stage":2,"feature_ids":["group_training"],"milestone_ids":[],"title":"Общий сеанс","text":"Выбери два совместимых стола и один фильм. Работники посмотрят его вместе и каждый получит свой навык. Уже освоенный фильм повторно не нужен.","superseded_milestones":["first_group_trained_auto_served"],"superseded_features":[]},
	{"id":"p5.formula","stage":2,"feature_ids":["formula_research"],"milestone_ids":[],"title":"Формула быстрее 100%","text":"В лаборатории можно улучшить темп новых клонов. Кресло обновит уже выращенных работников, когда формула станет быстрее их. Эта ветка необязательна.","superseded_milestones":[],"superseded_features":["kitchen_specialty"]},
	{"id":"p5.pair","stage":2,"feature_ids":["kitchen_pair"],"milestone_ids":[],"title":"Двое на одной кухне","text":"Расширь зал и установи парную кухню. Запиши роли мяса и макарон, затем обучи двух работников одним фильмом.","superseded_milestones":["first_pair_kitchen_auto_served"],"superseded_features":[]},
	{"id":"p5.specialization","stage":3,"feature_ids":["kitchen_specialty"],"milestone_ids":[],"title":"Бургерная","text":"Открой специализированный сектор. На бургерной два работника делят жарочную поверхность; покажи им, когда жарить котлету, а когда булку.","superseded_milestones":["first_specialty_kitchen_auto_served"],"superseded_features":[]},
	{"id":"p5.lab_scale","stage":3,"feature_ids":["lab_automation"],"milestone_ids":[],"title":"Помощь в лаборатории","text":"Работающих кухонь стало больше. Автоматика лаборатории освобождает время от посадки и извлечения клонов; привычные горшки тоже продолжают работать.","superseded_milestones":[],"superseded_features":["kitchen_orchestration"]},
	{"id":"p5.orchestration","stage":4,"feature_ids":["kitchen_orchestration"],"milestone_ids":[],"title":"Трое у одного котла","text":"В кухне «Солянка» три роли: огонь, перемешивание и соль. Запиши их по очереди или вместе с друзьями, затем покажи общий фильм бригаде.","superseded_milestones":["first_solyanka_auto_served"],"superseded_features":[]},
	{"id":"p5.large_scale","stage":4,"feature_ids":["lab_automation_large","recalibration_automation_large"],"milestone_ids":[],"title":"Кафе работает в большом масштабе","text":"Новые улучшения ускоряют выращивание и обновление большого штата. Покупай их по потребности: финальная проверка требует освоенных кухонь, а не всей мебели.","superseded_milestones":[],"superseded_features":[]}
]

static func snapshot_sets(snapshot: Dictionary) -> Dictionary:
	var features := {}
	for raw_id in snapshot.get("unlocked_features", []): features[str(raw_id)] = true
	var milestones := {}
	var raw_milestones: Variant = snapshot.get("milestones", {})
	if raw_milestones is Dictionary:
		for raw_id in raw_milestones: milestones[str(raw_id)] = true
	return {"features":features,"milestones":milestones}

static func explanation_by_id(explanation_id: String) -> Dictionary:
	for definition in EXPLANATIONS:
		if str(definition.id) == explanation_id: return definition.duplicate(true)
	return {}

static func applicable(definition: Dictionary, sets: Dictionary) -> bool:
	var features: Dictionary = sets.get("features", {})
	var milestones: Dictionary = sets.get("milestones", {})
	for id in definition.get("superseded_milestones", []):
		if milestones.has(str(id)): return false
	for id in definition.get("superseded_features", []):
		if features.has(str(id)): return false
	for feature_id in definition.get("feature_ids", []):
		if features.has(str(feature_id)): return true
	for milestone_id in definition.get("milestone_ids", []):
		if milestones.has(str(milestone_id)): return true
	return false

static func collect_new(snapshot: Dictionary, previous_sets: Dictionary, seen: Dictionary, queued: Dictionary = {}) -> Array[Dictionary]:
	var current := snapshot_sets(snapshot)
	var previous_features: Dictionary = previous_sets.get("features", {})
	var previous_milestones: Dictionary = previous_sets.get("milestones", {})
	var result: Array[Dictionary] = []
	for definition in EXPLANATIONS:
		var explanation_id := str(definition.id)
		if seen.has(explanation_id) or queued.has(explanation_id) or not applicable(definition, current): continue
		var triggered := false
		for feature_id in definition.get("feature_ids", []):
			var key := str(feature_id)
			if current.features.has(key) and not previous_features.has(key): triggered = true; break
		if not triggered:
			for milestone_id in definition.get("milestone_ids", []):
				var key := str(milestone_id)
				if current.milestones.has(key) and not previous_milestones.has(key): triggered = true; break
		if triggered: result.append(definition.duplicate(true))
	return result

static func collapse_catchup(snapshot: Dictionary, seen: Dictionary) -> Dictionary:
	var sets := snapshot_sets(snapshot)
	var applicable_unseen: Array[Dictionary] = []
	for definition in EXPLANATIONS:
		if not seen.has(str(definition.id)) and applicable(definition, sets): applicable_unseen.append(definition)
	if applicable_unseen.is_empty(): return {"current":{},"skip_ids":[]}
	var current: Dictionary = applicable_unseen.back().duplicate(true)
	var skip_ids: Array[String] = []
	for index in range(applicable_unseen.size() - 1): skip_ids.append(str(applicable_unseen[index].id))
	return {"current":current,"skip_ids":skip_ids}

static func can_present(state: Dictionary) -> bool:
	if str(state.get("ui_mode", "world")) != "world": return false
	for blocker in ["input_blocked","holding_item","cooking","teaching","confirming","inspection","sleep","urgent_notice"]:
		if bool(state.get(blocker, false)): return false
	return true
