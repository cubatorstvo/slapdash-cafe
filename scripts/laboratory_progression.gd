extends RefCounted
## Purchases, prices and progression shared by UI and host simulation.
const EXPERIMENT_PRICE := 20
const CLONE_PRICE := 60
const RECALIBRATION_PRICE := 10
const STAGES := [
	{"name":"Малая лаборатория","price":0,"star":0,"left":-5.0,"back":18.5},
	{"name":"Лаборатория с оранжереей","price":220,"star":1,"left":-8.7,"back":22.0},
	{"name":"Большая биолаборатория","price":480,"star":2,"left":-11.8,"back":27.0}
]
const ITEMS := {
	"lab_power":{"name":"Усилитель формулы · потолок 150%","price":180,"branch":"formula","star":1,"tier":0,"requires":[]},
	"lab_power_2":{"name":"Турбоблок формулы · потолок 200%","price":320,"branch":"formula","star":2,"tier":1,"requires":["lab_power"]},
	"lab_power_3":{"name":"Синтезатор формулы · потолок 250%","price":540,"branch":"formula","star":2,"tier":2,"requires":["lab_power_2"]},
	"lab_valve":{"name":"Точный клапан · плавная колба","price":90,"branch":"formula","star":1,"tier":0,"requires":[]},
	"lab_damper":{"name":"Демпфер · медленная стрелка","price":120,"branch":"formula","star":1,"tier":0,"requires":[]},
	"lab_feeder":{"name":"Кормушка · сама кормит проростки","price":75,"branch":"growing","star":1,"tier":0,"requires":[]},
	"lab_irrigation":{"name":"Бак с насосом · автоматический полив","price":90,"branch":"growing","star":1,"tier":0,"requires":[]},
	"lab_planter":{"name":"Посадочная установка · земля и капля одной кнопкой","price":150,"branch":"growing","star":1,"tier":1,"requires":["lab_irrigation"]},
	"lab_extractor":{"name":"Извлекатель · сам освобождает клонов","price":180,"branch":"growing","star":1,"tier":1,"requires":[]},
	"lab_production":{"name":"Пульт · поддерживать запас клонов","price":240,"branch":"growing","star":2,"tier":2,"requires":["lab_planter","lab_feeder","lab_extractor"]},
	"lab_lamps":{"name":"Фитолампы · выращивание быстрее на 25%","price":100,"branch":"growing","star":1,"tier":0,"requires":[]},
	"lab_nutrients":{"name":"Питательный дозатор · ещё +25% к скорости роста","price":150,"branch":"growing","star":1,"tier":1,"requires":["lab_feeder"]},
	"lab_climate":{"name":"Климатическая установка · ещё +50% к скорости роста","price":250,"branch":"growing","star":2,"tier":2,"requires":["lab_lamps"]},
	"lab_rack":{"name":"Стеллаж · ещё четыре горшка","price":160,"branch":"growing","star":1,"tier":1,"requires":[]},
	"lab_rack_2":{"name":"Вторая секция · ещё шесть горшков","price":300,"branch":"growing","star":2,"tier":2,"requires":["lab_rack"]},
	"lab_chair":{"name":"Кресло рекалибровки · ритм импульсов","price":45,"branch":"calibration","star":1,"tier":0,"requires":[]},
	"lab_cal_focus":{"name":"Точный синхронизатор · шире зона хорошего попадания","price":85,"branch":"calibration","star":1,"tier":0,"requires":["lab_chair"]},
	"lab_cal_slow":{"name":"Мягкие импульсы · больше времени на реакцию","price":100,"branch":"calibration","star":1,"tier":0,"requires":["lab_chair"]},
	"lab_cal_auto":{"name":"Автоматическая рекалибровка · очередь сотрудников","price":220,"branch":"calibration","star":2,"tier":1,"requires":["lab_chair"]},
	"lab_cal_speed":{"name":"Ускоритель кресла · автопрокачка вдвое быстрее","price":180,"branch":"calibration","star":2,"tier":2,"requires":["lab_cal_auto"]}
}
static func catalogue() -> Dictionary:
	var result: Dictionary={}
	for id in ITEMS:
		var spec: Dictionary=ITEMS[id].duplicate(true)
		spec.kind="lab_upgrade"
		if str(spec.branch)=="calibration": spec.feature="recalibration"
		elif id in ["lab_feeder","lab_irrigation","lab_planter","lab_extractor","lab_production"]: spec.feature="lab_automation"
		else: spec.feature="clone_growth"
		result[id]=spec
	return result

static func error(p, id: String) -> String:
	if not ITEMS.has(id): return "Прибор не найден."
	var spec: Dictionary=ITEMS[id]
	if id in p.lab_upgrades: return "Уже установлено."
	if p.lab_stage<3: return "Сначала собери стол исследования."
	if p.stars<int(spec.star): return "Нужна звезда %d."%spec.star
	if p.lab_tier<int(spec.tier): return "Сначала расширь лабораторию: "+str(STAGES[int(spec.tier)].name)+"."
	for prerequisite in spec.requires:
		if prerequisite not in p.lab_upgrades: return "Сначала установи: "+str(ITEMS[prerequisite].name)+"."
	return ""

static func expand(p) -> String:
	if p.lab_tier>=2: return "Лаборатория уже максимального размера."
	var spec: Dictionary=STAGES[p.lab_tier+1]
	if p.stars<int(spec.star): return "Нужна звезда %d."%spec.star
	if p.cash<int(spec.price): return "Не хватает денег."
	p.cash-=int(spec.price)
	p.lab_tier+=1
	p.revision+=1
	return ""

static func formula_range(p) -> Vector2:
	if "lab_power_3" in p.lab_upgrades: return Vector2(1.75,2.50)
	if "lab_power_2" in p.lab_upgrades: return Vector2(1.40,2.00)
	if "lab_power" in p.lab_upgrades: return Vector2(1.00,1.50)
	return Vector2(0.70,1.00)

static func growth_speed(p) -> float:
	return 1.0+(0.25 if "lab_lamps" in p.lab_upgrades else 0.0)+(0.25 if "lab_nutrients" in p.lab_upgrades else 0.0)+(0.50 if "lab_climate" in p.lab_upgrades else 0.0)

static func pot_count(p) -> int:
	return 2+(4 if "lab_rack" in p.lab_upgrades else 0)+(6 if "lab_rack_2" in p.lab_upgrades else 0)

static func blank_calibration() -> Dictionary:
	return {"phase":"idle","clone_id":0,"station":0,"owner":0,"age":0.0,"revision":0,"target":0.7,"start":0.7,"remaining":0.0,"hits":[],"misses":0,"focus":false,"slow":false,"notice":""}
