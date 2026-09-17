extends RefCounted
## Shared base goods for purchases and journey prices.
const ITEMS := {
	"meat_kit": {"name":"Гриль, тарелка и приборы для мяса","price":120,"kind":"equipment","star":2},
	"pasta_kit": {"name":"Плита, кастрюля и приборы для макарон","price":120,"kind":"equipment","star":2},
	"sauce": {"name":"Миска соуса","price":24,"kind":"equipment"},
	"plates": {"name":"Три тарелки","price":30,"kind":"equipment"},
	"cup": {"name":"Бокал 300 мл","price":30,"kind":"equipment"},
	"pan": {"name":"Дырявая сковорода с горелкой","price":54,"kind":"equipment"},
	"jug": {"name":"Кувшин для вина","price":54,"kind":"equipment"},
	"sauce_ramp": {"name":"Соусный трамплин","price":75,"kind":"equipment","star":1},
	"counter": {"name":"Стол и шкафчик","price":120,"kind":"station","star":1},
	"kitchen": {"name":"Парная кухня","price":250,"kind":"station","star":2},
	"lab_0": {"name":"Лабораторная колба","price":40,"kind":"lab"},
	"lab_1": {"name":"Блок питания лаборатории","price":60,"kind":"lab"},
	"lab_2": {"name":"Стабилизатор клонирования","price":80,"kind":"lab"},
	"sign": {"name":"Вывеска «Мы почти умеем»","price":45,"kind":"decor","star":1},
	"plants": {"name":"Зелёный уголок","price":110,"kind":"decor","star":1},
	"lights": {"name":"Гирлянда на честном слове","price":40,"kind":"garland","star":1}
}
