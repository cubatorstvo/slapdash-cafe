extends RefCounted
## Shared base goods for purchases and journey prices. Every product declares its owning feature.
const ITEMS := {
	"meat_kit": {"name":"Гриль, тарелка и приборы для мяса","price":120,"kind":"equipment","star":2,"feature":"kitchen_pair"},
	"pasta_kit": {"name":"Плита, кастрюля и приборы для макарон","price":120,"kind":"equipment","star":2,"feature":"kitchen_pair"},
	"grill_kit": {"name":"Общая жарочная поверхность и мясной комплект","price":140,"kind":"equipment","star":3,"feature":"kitchen_grill"},
	"assembly_kit": {"name":"Стол сборки, булки и соусы","price":140,"kind":"equipment","star":3,"feature":"kitchen_grill"},
	"fire_kit": {"name":"Набор огня и овощей для солянки","price":160,"kind":"equipment","star":4,"feature":"kitchen_solyanka"},
	"stir_kit": {"name":"Мешалка и овощи для солянки","price":160,"kind":"equipment","star":4,"feature":"kitchen_solyanka"},
	"salt_kit": {"name":"Соль и овощи для солянки","price":160,"kind":"equipment","star":4,"feature":"kitchen_solyanka"},
	"sauce": {"name":"Миска соуса","price":24,"kind":"equipment","feature":"shop_basic"},
	"plates": {"name":"Три тарелки","price":30,"kind":"equipment","feature":"shop_basic"},
	"cup": {"name":"Бокал 300 мл","price":30,"kind":"equipment","feature":"shop_basic"},
	"pan": {"name":"Дырявая сковорода с горелкой","price":54,"kind":"equipment","feature":"shop_basic"},
	"jug": {"name":"Кувшин для вина","price":54,"kind":"equipment","feature":"shop_basic"},
	"sauce_ramp": {"name":"Соусный трамплин","price":75,"kind":"equipment","star":1,"feature":"video_recording"},
	"counter": {"name":"Стол и шкафчик","price":120,"kind":"station","star":1,"feature":"clone_growth"},
	"kitchen": {"name":"Парная кухня","price":250,"kind":"station","star":2,"feature":"kitchen_pair"},
	"grill_kitchen": {"name":"Специализированная бургерная кухня","price":380,"kind":"station","star":3,"feature":"kitchen_grill"},
	"solyanka_kitchen": {"name":"Кухня «Солянка» на три роли","price":520,"kind":"station","star":4,"feature":"kitchen_solyanka"},
	"lab_0": {"name":"Лабораторная колба","price":40,"kind":"lab","feature":"clone_lab"},
	"lab_1": {"name":"Блок питания лаборатории","price":60,"kind":"lab","feature":"clone_lab"},
	"lab_2": {"name":"Стабилизатор клонирования","price":80,"kind":"lab","feature":"clone_lab"},
	"sign": {"name":"Вывеска «Мы почти умеем»","price":45,"kind":"decor","star":1,"feature":"stars"},
	"plants": {"name":"Зелёный уголок","price":110,"kind":"decor","star":1,"feature":"stars"},
	"lights": {"name":"Гирлянда на честном слове","price":40,"kind":"garland","star":1,"feature":"stars"}
}
