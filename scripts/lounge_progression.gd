extends RefCounted
## One shared daily bonus. Sleep poses never change productivity.
const Layout = preload("res://scripts/lounge_layout.gd")
const MAX_BONUS := 0.30
const STAGES := [
	{"name":"Небольшая комната","price":0,"star":0},
	{"name":"Просторная комната","price":180,"star":1},
	{"name":"Большая комната","price":420,"star":2}
]
const GOODS := {
	"sofa":{"name":"Диван на двоих","price":100,"tier":0,"quality":0.08},
	"television":{"name":"Телевизор · +4% к качеству дивана","price":90,"tier":0,"quality":0.0},
	"rocking_chair":{"name":"Кресло-качалка","price":60,"tier":0,"quality":0.12},
	"beanbag":{"name":"Кресло-мешок","price":35,"tier":0,"quality":0.10},
	"bookcase":{"name":"Книжный стеллаж","price":70,"tier":0,"quality":0.12},
	"plants":{"name":"Растения · +2% уюта","price":45,"tier":0,"quality":0.0},
	"floor_lamp":{"name":"Торшер · +2% уюта","price":35,"tier":0,"quality":0.0},
	"foosball":{"name":"Настольный футбол","price":150,"tier":1,"quality":0.14},
	"arcade":{"name":"Аркадный автомат","price":180,"tier":1,"quality":0.16},
	"board_games":{"name":"Настольные игры на четверых","price":80,"tier":1,"quality":0.12},
	"tea_station":{"name":"Чайный уголок на двоих","price":100,"tier":1,"quality":0.14},
	"snack_fridge":{"name":"Холодильник с перекусами","price":110,"tier":1,"quality":0.14},
	"table_tennis":{"name":"Настольный теннис","price":220,"tier":2,"quality":0.16},
	"jukebox":{"name":"Музыкальный автомат","price":160,"tier":2,"quality":0.16},
	"aquarium":{"name":"Аквариум","price":160,"tier":2,"quality":0.16},
	"textiles":{"name":"Ковры и шторы · +2% уюта","price":100,"tier":1,"quality":0.0},
	"ambient":{"name":"Гирлянда и тёплый свет · +2% уюта","price":140,"tier":2,"quality":0.0}
}

static func stamp(p) -> String:
	return "%d:%s:%s" % [p.lounge_tier,str(p.lounge_items),str(p.lounge_upgrades)]

static func shop_items() -> Dictionary:
	var result := {}
	for id in GOODS:
		var spec: Dictionary = GOODS[id]
		result["rest_"+id] = {"name":spec.name,"price":spec.price,"kind":"lounge","lounge_id":id,"upgrade":false}
		if float(spec.quality)>0:
			result["rest_upgrade_"+id] = {"name":"Улучшение: "+spec.name+" · +8% к качеству мест","price":maxi(40,int(spec.price*0.8)),"kind":"lounge","lounge_id":id,"upgrade":true}
	return result

static func item_error(p, spec: Dictionary) -> String:
	var id: String = spec.lounge_id
	if p.lounge_tier<int(GOODS[id].tier): return "Сначала расширь комнату: "+str(STAGES[int(GOODS[id].tier)].name)+"."
	if bool(spec.upgrade):
		if id not in p.lounge_items: return "Сначала установи сам предмет."
		if id in p.lounge_upgrades: return "Предмет уже улучшен."
	elif id in p.lounge_items: return "Уже установлено."
	return ""

static func slots(p) -> Array:
	var result := Layout.activity_slots(p.lounge_tier,p.lounge_items)
	for spot in result:
		spot.quality=float(GOODS[spot.item].quality)+(0.08 if spot.item in p.lounge_upgrades else 0.0)
		if spot.item=="sofa":
			if "television" in p.lounge_items: spot.quality+=0.04
			else: spot.activity="Болтает на диване"
	# Use the best available places; stable ID breaks ties identically on every peer.
	result.sort_custom(func(a,b):
		return str(a.id)<str(b.id) if is_equal_approx(float(a.quality),float(b.quality)) else float(a.quality)>float(b.quality))
	return result

static func report(p, workers: int) -> Dictionary:
	var available := slots(p)
	var covered := mini(workers,available.size())
	var comfort := 0.0
	for id in ["plants","floor_lamp","textiles","ambient"]:
		if id in p.lounge_items: comfort+=0.02
	var total := 0.0
	for i in range(covered): total+=float(available[i].quality)+comfort
	var bonus := minf(MAX_BONUS,total/float(workers)) if workers>0 else 0.0
	return {"workers":workers,"places":available.size(),"covered":covered,"comfort":comfort,"bonus":bonus,"multiplier":1.0+bonus}

static func expand(p) -> String:
	if p.lounge_tier>=2: return "Комната уже максимального размера."
	var next: Dictionary=STAGES[p.lounge_tier+1]
	if p.stars<int(next.star): return "Нужна звезда %d."%next.star
	if p.busy(): return "Сначала заверши проверку."
	if p.cash<int(next.price): return "Не хватает денег."
	p.cash-=int(next.price)
	p.lounge_tier+=1
	p.revision+=1
	return ""
