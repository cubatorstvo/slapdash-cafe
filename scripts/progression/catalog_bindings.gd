extends RefCounted
## Explicit P5.05 catalogue bindings. The JSON handoff is not executed at runtime.

const GROUP_ORDER: Array[String] = [
	"base_lab", "first_rest", "rest_comfort", "staff_activities", "television",
	"formula_research", "manual_growth_help", "recalibration", "recalibration_tuning", "rest_games",
	"lab_scale", "calibration_scale", "rest_large", "lab_scale_large", "calibration_scale_large", "rest_atmosphere"
]

const GROUPS := {
	"base_lab":{"feature_id":"clone_lab","min_stars":1,"milestones":["first_star_earned"],"features":["shop_basic"],"sort_order":10,"title":"Базовая лаборатория","benefit":"Три установки дают стандартную формулу 100% и два горшка.","locked_reason":"Получи первую звезду.","category":"lab","new_feature":false},
	"first_rest":{"feature_id":"rest_basics","min_stars":1,"milestones":["first_clone_created"],"features":["staff_roster"],"sort_order":20,"title":"Место для первого помощника","benefit":"Диван уже есть. Кресло-мешок и качалка — добровольные дополнительные места.","locked_reason":"Вырасти первого клона.","category":"lounge","new_feature":false},
	"rest_comfort":{"feature_id":"rest_comfort","min_stars":1,"milestones":["first_staff_rest_completed"],"features":["rest_basics"],"sort_order":30,"title":"Немного уюта","benefit":"Каждый предмет добавляет 2% к качеству занятых мест.","locked_reason":"Заверши первый ночной отдых с работником.","category":"lounge","new_feature":true},
	"staff_activities":{"feature_id":"rest_extended","min_stars":1,"milestones":["first_staff_rest_completed","repeat_manual_clone_growth_completed"],"features":["rest_basics"],"sort_order":40,"title":"Занятия после смены","benefit":"Выбери места для растущей команды; для трёх больших предметов расширь комнату.","locked_reason":"Заверши отдых с работником и два ручных выращивания.","category":"lounge","new_feature":false},
	"television":{"feature_id":"video_training","min_stars":2,"milestones":["first_masterclass_saved"],"features":["video_recording"],"sort_order":50,"title":"Первый учебный фильм","benefit":"Телевизор обучает сотрудников сохранённым способам.","locked_reason":"На 2★ сохрани первый мастер-класс.","category":"lounge","new_feature":false},
	"formula_research":{"feature_id":"formula_upgrades","min_stars":2,"milestones":["first_group_training_completed"],"features":["formula_research"],"sort_order":60,"title":"Формула быстрее 100%","benefit":"Усилитель повышает потолок до 150%; клапан и демпфер облегчают эксперимент.","locked_reason":"На 2★ заверши один общий просмотр с выдачей навыков двум столам.","category":"lab","new_feature":false},
	"manual_growth_help":{"feature_id":"lab_growth_upgrades","min_stars":2,"milestones":["repeat_manual_clone_growth_completed"],"features":["clone_growth"],"sort_order":70,"title":"Помощь у горшков","benefit":"Кормушка и полив убирают повторные действия, лампы ускоряют рост.","locked_reason":"Получи 2★ и заверши два ручных выращивания.","category":"lab","new_feature":false},
	"recalibration":{"feature_id":"recalibration","min_stars":2,"milestones":["first_group_training_completed","formula_improvement_relevant"],"features":["formula_upgrades"],"sort_order":80,"title":"Обновить старого работника","benefit":"Кресло переносит пользу лучшей формулы на уже выращенного клона.","locked_reason":"Исследуй формулу быстрее хотя бы одного существующего работника.","category":"lab","new_feature":false},
	"recalibration_tuning":{"feature_id":"recalibration_tuning","min_stars":2,"milestones":["first_recalibration_completed"],"features":["recalibration"],"sort_order":90,"title":"Помощь в ритме","benefit":"Синхронизатор и мягкие импульсы облегчают следующие процедуры.","locked_reason":"Хотя бы один клон должен реально повысить темп после рекалибровки.","category":"lab","new_feature":true},
	"rest_games":{"feature_id":"rest_games","min_stars":2,"milestones":["first_staff_rest_completed","first_group_training_completed","lounge_expansion_1_completed"],"features":["rest_extended"],"sort_order":100,"title":"Команда отдыхает вместе","benefit":"Три добровольных предложения: футбол, автомат и уютный текстиль.","locked_reason":"На 2★ освой групповое обучение и расширь комнату до просторной.","category":"lounge","new_feature":true},
	"lab_scale":{"feature_id":"lab_automation","min_stars":3,"milestones":["first_specialty_kitchen_auto_served","staff_6_seen"],"features":["clone_growth"],"sort_order":110,"title":"Лаборатория для нескольких линий","benefit":"После запуска бургерной можно увеличить число горшков и упростить выпуск.","locked_reason":"Получи 3★, обслужи заказ бургерной и собери штат из 6 работников.","category":"lab","new_feature":false},
	"calibration_scale":{"feature_id":"recalibration_automation","min_stars":3,"milestones":["first_recalibration_completed","first_specialty_kitchen_auto_served","staff_6_seen"],"features":["recalibration","lab_automation"],"sort_order":120,"title":"Ускорение команды","benefit":"Очередь кресла обслуживает работников; турбоблок поднимает потолок формулы до 200%.","locked_reason":"Успешно ускорь одного клона; на 3★ запусти бургерную и собери 6 работников.","category":"lab","new_feature":true},
	"rest_large":{"feature_id":"rest_large","min_stars":3,"milestones":["first_staff_rest_completed","first_specialty_kitchen_auto_served","lounge_expansion_2_completed"],"features":["rest_extended"],"sort_order":130,"title":"Большая комната — новые занятия","benefit":"Теннис и музыкальный автомат добавляют хорошие места для выросшей команды.","locked_reason":"На 3★ запусти бургерную и установи расширение большой комнаты.","category":"lounge","new_feature":false},
	"lab_scale_large":{"feature_id":"lab_automation_large","min_stars":4,"milestones":["first_solyanka_auto_served","staff_9_seen"],"features":["lab_automation"],"sort_order":140,"title":"Выпуск для большого кафе","benefit":"Вторая секция даёт 12 горшков; пульт держит запас, климат ускоряет рост.","locked_reason":"На 4★ обслужи солянку и собери штат из 9 работников.","category":"lab","new_feature":true},
	"calibration_scale_large":{"feature_id":"recalibration_automation_large","min_stars":4,"milestones":["first_recalibration_completed","first_solyanka_auto_served","staff_9_seen"],"features":["recalibration_automation","lab_automation_large"],"sort_order":150,"title":"Быстрое обновление большого штата","benefit":"Ускоритель сокращает время автоматического кресла, синтезатор даёт потолок 250%.","locked_reason":"На 4★ запусти солянку, собери 9 работников и заверши полезную рекалибровку.","category":"lab","new_feature":true},
	"rest_atmosphere":{"feature_id":"rest_atmosphere","min_stars":4,"milestones":["first_staff_rest_completed","first_solyanka_auto_served","lounge_expansion_2_completed"],"features":["rest_large"],"sort_order":160,"title":"Последние штрихи отдыха","benefit":"Аквариум и тёплый свет — ещё два варианта обустройства большой комнаты.","locked_reason":"На 4★ обслужи солянку; нужна большая комната отдыха.","category":"lounge","new_feature":true}
}

const EXPANSIONS := {
	"content.lab_expansion.1":{"min_stars":3,"features":["clone_growth"],"milestones":["first_specialty_kitchen_auto_served","staff_6_seen"],"title":"Лаборатория с оранжереей","locked_reason":"На 3★ запусти бургерную и собери 6 работников.","tier_from":0},
	"content.lab_expansion.2":{"min_stars":4,"features":["lab_automation"],"milestones":["first_solyanka_auto_served","staff_9_seen"],"title":"Большая биолаборатория","locked_reason":"На 4★ запусти солянку и собери 9 работников.","tier_from":1},
	"content.lounge_expansion.1":{"min_stars":1,"features":["rest_basics"],"milestones":["first_staff_rest_completed","repeat_manual_clone_growth_completed"],"title":"Просторная комната","locked_reason":"Заверши первый отдых и два ручных выращивания.","tier_from":0},
	"content.lounge_expansion.2":{"min_stars":3,"features":["rest_extended"],"milestones":["first_staff_rest_completed","first_specialty_kitchen_auto_served"],"title":"Большая комната","locked_reason":"На 3★ запусти бургерную после первого отдыха.","tier_from":1}
}

const GROUP_ITEMS := {
	"base_lab":["lab_0","lab_1","lab_2"],
	"first_rest":["rest_sofa","rest_upgrade_sofa","rest_beanbag","rest_upgrade_beanbag","rest_rocking_chair","rest_upgrade_rocking_chair"],
	"rest_comfort":["rest_plants","rest_floor_lamp"],
	"staff_activities":["rest_bookcase","rest_upgrade_bookcase","rest_board_games","rest_upgrade_board_games","rest_tea_station","rest_upgrade_tea_station","rest_snack_fridge","rest_upgrade_snack_fridge"],
	"television":["rest_television"],
	"formula_research":["lab_power","lab_valve","lab_damper"],
	"manual_growth_help":["lab_feeder","lab_irrigation","lab_lamps"],
	"recalibration":["lab_chair"],
	"recalibration_tuning":["lab_cal_focus","lab_cal_slow"],
	"rest_games":["rest_foosball","rest_upgrade_foosball","rest_arcade","rest_upgrade_arcade","rest_textiles"],
	"lab_scale":["lab_rack","lab_planter","lab_extractor","lab_nutrients"],
	"calibration_scale":["lab_cal_auto","lab_power_2"],
	"rest_large":["rest_table_tennis","rest_upgrade_table_tennis","rest_jukebox","rest_upgrade_jukebox"],
	"lab_scale_large":["lab_rack_2","lab_production","lab_climate"],
	"calibration_scale_large":["lab_cal_speed","lab_power_3"],
	"rest_atmosphere":["rest_aquarium","rest_upgrade_aquarium","rest_ambient"]
}

const ITEMS := {
	"lab_0":{"group":"base_lab","context":"base_lab_purchase","internal":"lab_0","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"lab_1":{"group":"base_lab","context":"base_lab_purchase","internal":"lab_1","stage":1,"lab_tier":0,"lounge_tier":0,"requires":["lab_0"],"upgrade":false,"sort":20},
	"lab_2":{"group":"base_lab","context":"base_lab_purchase","internal":"lab_2","stage":2,"lab_tier":0,"lounge_tier":0,"requires":["lab_1"],"upgrade":false,"sort":30},
	"rest_sofa":{"group":"first_rest","context":"lounge_purchase","internal":"sofa","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"rest_upgrade_sofa":{"group":"first_rest","context":"lounge_purchase","internal":"sofa","stage":0,"lab_tier":0,"lounge_tier":0,"requires":["rest_sofa"],"upgrade":true,"sort":11},
	"rest_beanbag":{"group":"first_rest","context":"lounge_purchase","internal":"beanbag","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":20},
	"rest_upgrade_beanbag":{"group":"first_rest","context":"lounge_purchase","internal":"beanbag","stage":0,"lab_tier":0,"lounge_tier":0,"requires":["rest_beanbag"],"upgrade":true,"sort":21},
	"rest_rocking_chair":{"group":"first_rest","context":"lounge_purchase","internal":"rocking_chair","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":30},
	"rest_upgrade_rocking_chair":{"group":"first_rest","context":"lounge_purchase","internal":"rocking_chair","stage":0,"lab_tier":0,"lounge_tier":0,"requires":["rest_rocking_chair"],"upgrade":true,"sort":31},
	"rest_plants":{"group":"rest_comfort","context":"lounge_purchase","internal":"plants","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"rest_floor_lamp":{"group":"rest_comfort","context":"lounge_purchase","internal":"floor_lamp","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":20},
	"rest_bookcase":{"group":"staff_activities","context":"lounge_purchase","internal":"bookcase","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"rest_upgrade_bookcase":{"group":"staff_activities","context":"lounge_purchase","internal":"bookcase","stage":0,"lab_tier":0,"lounge_tier":0,"requires":["rest_bookcase"],"upgrade":true,"sort":11},
	"rest_board_games":{"group":"staff_activities","context":"lounge_purchase","internal":"board_games","stage":0,"lab_tier":0,"lounge_tier":1,"requires":[],"upgrade":false,"sort":20},
	"rest_upgrade_board_games":{"group":"staff_activities","context":"lounge_purchase","internal":"board_games","stage":0,"lab_tier":0,"lounge_tier":1,"requires":["rest_board_games"],"upgrade":true,"sort":21},
	"rest_tea_station":{"group":"staff_activities","context":"lounge_purchase","internal":"tea_station","stage":0,"lab_tier":0,"lounge_tier":1,"requires":[],"upgrade":false,"sort":30},
	"rest_upgrade_tea_station":{"group":"staff_activities","context":"lounge_purchase","internal":"tea_station","stage":0,"lab_tier":0,"lounge_tier":1,"requires":["rest_tea_station"],"upgrade":true,"sort":31},
	"rest_snack_fridge":{"group":"staff_activities","context":"lounge_purchase","internal":"snack_fridge","stage":0,"lab_tier":0,"lounge_tier":1,"requires":[],"upgrade":false,"sort":40},
	"rest_upgrade_snack_fridge":{"group":"staff_activities","context":"lounge_purchase","internal":"snack_fridge","stage":0,"lab_tier":0,"lounge_tier":1,"requires":["rest_snack_fridge"],"upgrade":true,"sort":41},
	"rest_television":{"group":"television","context":"lounge_purchase","internal":"television","stage":0,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"lab_power":{"group":"formula_research","context":"laboratory_purchase","internal":"lab_power","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"lab_valve":{"group":"formula_research","context":"laboratory_purchase","internal":"lab_valve","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":20},
	"lab_damper":{"group":"formula_research","context":"laboratory_purchase","internal":"lab_damper","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":30},
	"lab_feeder":{"group":"manual_growth_help","context":"laboratory_purchase","internal":"lab_feeder","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"lab_irrigation":{"group":"manual_growth_help","context":"laboratory_purchase","internal":"lab_irrigation","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":20},
	"lab_lamps":{"group":"manual_growth_help","context":"laboratory_purchase","internal":"lab_lamps","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":30},
	"lab_chair":{"group":"recalibration","context":"laboratory_purchase","internal":"lab_chair","stage":3,"lab_tier":0,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"lab_cal_focus":{"group":"recalibration_tuning","context":"laboratory_purchase","internal":"lab_cal_focus","stage":3,"lab_tier":0,"lounge_tier":0,"requires":["lab_chair"],"upgrade":false,"sort":10},
	"lab_cal_slow":{"group":"recalibration_tuning","context":"laboratory_purchase","internal":"lab_cal_slow","stage":3,"lab_tier":0,"lounge_tier":0,"requires":["lab_chair"],"upgrade":false,"sort":20},
	"rest_foosball":{"group":"rest_games","context":"lounge_purchase","internal":"foosball","stage":0,"lab_tier":0,"lounge_tier":1,"requires":[],"upgrade":false,"sort":10},
	"rest_upgrade_foosball":{"group":"rest_games","context":"lounge_purchase","internal":"foosball","stage":0,"lab_tier":0,"lounge_tier":1,"requires":["rest_foosball"],"upgrade":true,"sort":11},
	"rest_arcade":{"group":"rest_games","context":"lounge_purchase","internal":"arcade","stage":0,"lab_tier":0,"lounge_tier":1,"requires":[],"upgrade":false,"sort":20},
	"rest_upgrade_arcade":{"group":"rest_games","context":"lounge_purchase","internal":"arcade","stage":0,"lab_tier":0,"lounge_tier":1,"requires":["rest_arcade"],"upgrade":true,"sort":21},
	"rest_textiles":{"group":"rest_games","context":"lounge_purchase","internal":"textiles","stage":0,"lab_tier":0,"lounge_tier":1,"requires":[],"upgrade":false,"sort":30},
	"lab_rack":{"group":"lab_scale","context":"laboratory_purchase","internal":"lab_rack","stage":3,"lab_tier":1,"lounge_tier":0,"requires":[],"upgrade":false,"sort":10},
	"lab_planter":{"group":"lab_scale","context":"laboratory_purchase","internal":"lab_planter","stage":3,"lab_tier":1,"lounge_tier":0,"requires":["lab_irrigation"],"upgrade":false,"sort":20},
	"lab_extractor":{"group":"lab_scale","context":"laboratory_purchase","internal":"lab_extractor","stage":3,"lab_tier":1,"lounge_tier":0,"requires":[],"upgrade":false,"sort":30},
	"lab_nutrients":{"group":"lab_scale","context":"laboratory_purchase","internal":"lab_nutrients","stage":3,"lab_tier":1,"lounge_tier":0,"requires":["lab_feeder"],"upgrade":false,"sort":40},
	"lab_cal_auto":{"group":"calibration_scale","context":"laboratory_purchase","internal":"lab_cal_auto","stage":3,"lab_tier":1,"lounge_tier":0,"requires":["lab_chair"],"upgrade":false,"sort":10},
	"lab_power_2":{"group":"calibration_scale","context":"laboratory_purchase","internal":"lab_power_2","stage":3,"lab_tier":1,"lounge_tier":0,"requires":["lab_power"],"upgrade":false,"sort":20},
	"rest_table_tennis":{"group":"rest_large","context":"lounge_purchase","internal":"table_tennis","stage":0,"lab_tier":0,"lounge_tier":2,"requires":[],"upgrade":false,"sort":10},
	"rest_upgrade_table_tennis":{"group":"rest_large","context":"lounge_purchase","internal":"table_tennis","stage":0,"lab_tier":0,"lounge_tier":2,"requires":["rest_table_tennis"],"upgrade":true,"sort":11},
	"rest_jukebox":{"group":"rest_large","context":"lounge_purchase","internal":"jukebox","stage":0,"lab_tier":0,"lounge_tier":2,"requires":[],"upgrade":false,"sort":20},
	"rest_upgrade_jukebox":{"group":"rest_large","context":"lounge_purchase","internal":"jukebox","stage":0,"lab_tier":0,"lounge_tier":2,"requires":["rest_jukebox"],"upgrade":true,"sort":21},
	"lab_rack_2":{"group":"lab_scale_large","context":"laboratory_purchase","internal":"lab_rack_2","stage":3,"lab_tier":2,"lounge_tier":0,"requires":["lab_rack"],"upgrade":false,"sort":10},
	"lab_production":{"group":"lab_scale_large","context":"laboratory_purchase","internal":"lab_production","stage":3,"lab_tier":2,"lounge_tier":0,"requires":["lab_planter","lab_feeder","lab_extractor"],"upgrade":false,"sort":20},
	"lab_climate":{"group":"lab_scale_large","context":"laboratory_purchase","internal":"lab_climate","stage":3,"lab_tier":2,"lounge_tier":0,"requires":["lab_lamps"],"upgrade":false,"sort":30},
	"lab_cal_speed":{"group":"calibration_scale_large","context":"laboratory_purchase","internal":"lab_cal_speed","stage":3,"lab_tier":2,"lounge_tier":0,"requires":["lab_cal_auto"],"upgrade":false,"sort":10},
	"lab_power_3":{"group":"calibration_scale_large","context":"laboratory_purchase","internal":"lab_power_3","stage":3,"lab_tier":2,"lounge_tier":0,"requires":["lab_power_2"],"upgrade":false,"sort":20},
	"rest_aquarium":{"group":"rest_atmosphere","context":"lounge_purchase","internal":"aquarium","stage":0,"lab_tier":0,"lounge_tier":2,"requires":[],"upgrade":false,"sort":10},
	"rest_upgrade_aquarium":{"group":"rest_atmosphere","context":"lounge_purchase","internal":"aquarium","stage":0,"lab_tier":0,"lounge_tier":2,"requires":["rest_aquarium"],"upgrade":true,"sort":11},
	"rest_ambient":{"group":"rest_atmosphere","context":"lounge_purchase","internal":"ambient","stage":0,"lab_tier":0,"lounge_tier":2,"requires":[],"upgrade":false,"sort":20}
}

static func item(item_id: String) -> Dictionary:
	if not ITEMS.has(item_id): return {}
	var row: Dictionary = ITEMS[item_id].duplicate(true)
	var group: Dictionary = GROUPS[str(row.group)]
	row.item_id = item_id
	row.feature = str(group.feature_id)
	row.min_stars = int(group.min_stars)
	return row

static func is_catalogue_feature(feature_id: String) -> bool:
	return not feature_patch(feature_id).is_empty()

static func feature_patch(feature_id: String) -> Dictionary:
	for group_id in GROUP_ORDER:
		var group: Dictionary = GROUPS[group_id]
		if str(group.feature_id) != feature_id: continue
		var patch := {
			"id":feature_id,
			"title_key":str(group.title),
			"min_stars":int(group.min_stars),
			"requires_features":(group.features as Array).duplicate(),
			"requires_milestones":(group.milestones as Array).duplicate(),
			"unlock_rule_id":"always",
			"benefit":str(group.benefit),
			"locked_reason":str(group.locked_reason),
			"announce":true
		}
		if bool(group.new_feature):
			patch.sort_order = int(group.sort_order) + 300
		return patch
	if not EXPANSIONS.has(feature_id): return {}
	var expansion: Dictionary = EXPANSIONS[feature_id]
	return {
		"id":feature_id,
		"title_key":str(expansion.title),
		"min_stars":int(expansion.min_stars),
		"requires_features":(expansion.features as Array).duplicate(),
		"requires_milestones":(expansion.milestones as Array).duplicate(),
		"unlock_rule_id":"always",
		"locked_reason":str(expansion.locked_reason),
		"announce":false
	}

static func extra_feature_ids() -> Array[String]:
	var ids: Array[String] = []
	for group_id in GROUP_ORDER:
		var group: Dictionary = GROUPS[group_id]
		if bool(group.new_feature): ids.append(str(group.feature_id))
	return ids

static func ordered_groups(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group_id in GROUP_ORDER:
		var group: Dictionary = GROUPS[group_id]
		if str(group.category) != category: continue
		var copy: Dictionary = group.duplicate(true)
		copy.group_id = group_id
		result.append(copy)
	return result

static func group_item_ids(group_id: String) -> Array[String]:
	var result: Array[String] = []
	for raw in GROUP_ITEMS.get(group_id, []):
		result.append(str(raw))
	return result

static func item_ids() -> Array[String]:
	var result: Array[String] = []
	for group_id in GROUP_ORDER:
		result.append_array(group_item_ids(group_id))
	return result
