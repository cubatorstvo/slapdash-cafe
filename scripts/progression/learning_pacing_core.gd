extends RefCounted

const EXPLANATIONS: Array[Dictionary] = [
	{"id":"p5.clone_core","stage":1,"feature_ids":["clone_growth","production_tables"],"milestone_ids":["first_clone_created"],"title":"Первый помощник","text":"Клон — рабочий ресурс кафе. Выращивай его в лаборатории, назначай за производственный стол и обучай реальным способом приготовления."},
	{"id":"p5.personal_learning","stage":1,"feature_ids":["production_tables"],"milestone_ids":["first_live_lesson_accepted"],"title":"Личный урок принят","text":"Работник запомнил принятый способ. Теперь ему можно доверить подходящие заказы; повторный урок использует обычный компактный интерфейс."},
	{"id":"p5.first_automation","stage":1,"feature_ids":[],"milestone_ids":["first_auto_served"],"title":"Первая самостоятельная подача","text":"Автоматизация считается освоенной только после реальной подачи клиенту. Доступные действия уже работают независимо от этого сообщения."},
	{"id":"p5.video_recording","stage":2,"feature_ids":["video_recording"],"milestone_ids":["first_masterclass_saved"],"title":"Способ можно записывать","text":"Принятый мастер-класс сохраняется в видеотеку. Одна запись затем может распространять знакомый способ без повторного личного урока."},
	{"id":"p5.video_learning","stage":2,"feature_ids":["video_training"],"milestone_ids":["first_video_training_completed"],"title":"Обучение по видео","text":"Просмотр считается освоенным после реальной выдачи навыка присутствовавшему работнику. Само назначение фильма ещё не завершает обучение."},
	{"id":"p5.group_learning","stage":2,"feature_ids":[],"milestone_ids":["first_group_training_completed"],"title":"Общий сеанс","text":"Один совместимый способ можно передать нескольким столам за общий сеанс. Это один знакомый цикл, а не отдельная серия подсказок для каждого стола."},
	{"id":"p5.specialization","stage":3,"feature_ids":["kitchen_specialty","formula_upgrades","recalibration"],"milestone_ids":[],"title":"Специализация","text":"На этом этапе важны подходящие роли, оснащение и качество действующих работников. Новые варианты внутри знакомых систем открываются как единый набор."},
	{"id":"p5.lab_scale","stage":3,"feature_ids":["content.lab_expansion.1","lab_growth_upgrades","rest_extended"],"milestone_ids":[],"title":"Кафе растёт","text":"Расширения дают больше места и вариантов развития. Уже известные товары остаются видимыми, а временные препятствия показываются прямо у действия."},
	{"id":"p5.orchestration","stage":4,"feature_ids":["kitchen_orchestration","lab_automation","recalibration_automation"],"milestone_ids":[],"title":"Координация","text":"Поздний этап объединяет уже знакомые циклы: производство, развитие работников и автоматизацию. Новые варианты не требуют заново проходить вводные уроки."},
	{"id":"p5.large_scale","stage":4,"feature_ids":["content.lab_expansion.2","lab_automation_large","recalibration_automation_large","rest_large"],"milestone_ids":[],"title":"Большое кафе","text":"Поздние наборы вводятся одним объяснением общей пользы. Конкретные условия покупки и восстановления остаются у соответствующего действия."}
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
