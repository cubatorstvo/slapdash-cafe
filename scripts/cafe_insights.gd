extends RefCounted
## Persistent service analytics and short-window event aggregation for a scaled cafe.
const FEED_WINDOW:=8.0
const MAX_FEED:=48

static func blank()->Dictionary:
	return {"clock":0.0,"serial":1,"dish":{},"stations":{},"losses":{},"loss_details":{},"feed":[]}

static func normalize(value: Variant)->Dictionary:
	var data: Dictionary=value.duplicate(true) if value is Dictionary else blank()
	for key in ["dish","stations","losses","loss_details"]:
		if not data.get(key,{}) is Dictionary: data[key]={}
	if not data.get("feed",[]) is Array: data.feed=[]
	data.clock=maxf(0.0,float(data.get("clock",0.0)))
	data.serial=maxi(1,int(data.get("serial",1)))
	return data

static func tick(data: Dictionary,delta: float)->void:
	data.clock=maxf(0.0,float(data.get("clock",0.0))+maxf(0.0,delta))

static func _dish(data: Dictionary,dish: String)->Dictionary:
	if not data.dish.has(dish):
		data.dish[dish]={"guests":0,"orders_completed":0,"orders_partial":0,"orders_failed":0,"portions_ordered":0,"portions_served":0,"portions_unserved":0,"revenue":0,"losses":{}}
	return data.dish[dish]

static func _station(data: Dictionary,id: int)->Dictionary:
	var key:=str(id)
	if not data.stations.has(key): data.stations[key]={"orders_completed":0,"portions_served":0,"revenue":0,"dish":{}}
	return data.stations[key]

static func _station_dish(row: Dictionary,dish: String)->Dictionary:
	if not row.dish.has(dish): row.dish[dish]={"orders_completed":0,"portions_served":0,"revenue":0}
	return row.dish[dish]

static func arrival(data: Dictionary,dish: String,portions: int)->void:
	var row:=_dish(data,dish)
	row.guests=int(row.guests)+1
	row.portions_ordered=int(row.portions_ordered)+maxi(1,portions)

static func portion(data: Dictionary,dish: String,station_id: int,payment: int)->void:
	var row:=_dish(data,dish)
	row.portions_served=int(row.portions_served)+1
	row.revenue=int(row.revenue)+maxi(0,payment)
	if station_id<=0: return
	var station:=_station(data,station_id)
	station.portions_served=int(station.portions_served)+1
	station.revenue=int(station.revenue)+maxi(0,payment)
	var detail:=_station_dish(station,dish)
	detail.portions_served=int(detail.portions_served)+1
	detail.revenue=int(detail.revenue)+maxi(0,payment)

static func complete(data: Dictionary,dish: String,station_id: int)->void:
	var row:=_dish(data,dish)
	row.orders_completed=int(row.orders_completed)+1
	if station_id<=0: return
	var station:=_station(data,station_id)
	station.orders_completed=int(station.orders_completed)+1
	var detail:=_station_dish(station,dish)
	detail.orders_completed=int(detail.orders_completed)+1

static func reason_label(reason: String)->String:
	return {
		"busy":"все подходящие столы были заняты",
		"unlearned":"нужное блюдо ещё не освоено",
		"equipment":"не хватает оборудования",
		"workers":"не хватает сотрудников",
		"training":"сотрудники были на обучении",
		"chef_wait":"слишком долго ждал личный заказ шефу",
		"closing":"обслуживание завершилось при закрытии",
		"no_station":"нет подходящего производственного стола",
		"menu_off":"Блюдо выключено в меню",
		"wait":"время ожидания закончилось"
	}.get(reason,"обслуживание не завершено")

static func suggestion(reason: String)->String:
	return {
		"busy":"Добавь подходящие столы или назначь им более быстрый мастер-класс.",
		"unlearned":"Назначь этому блюду мастер-класс в «Группах столов».",
		"equipment":"Заверши оснащение подходящих столов.",
		"workers":"Заполни вакансии свободными клонами или вырасти новых.",
		"training":"Дождись конца текущего занятия; следующие группы обучай между пиками спроса.",
		"chef_wait":"Разгрузи личную стойку шефа и не держи длинную очередь.",
		"closing":"Начинай крупные заказы раньше или держи достаточную производственную мощность.",
		"no_station":"Добавь подходящий тип кухни или производственный стол.",
		"menu_off":"Включи блюдо в активном меню подходящей группы.",
		"wait":"Ускорь способ приготовления или добавь подходящие столы."
	}.get(reason,"Проверь связанное блюдо, группу и состояние столов.")

static func loss(data: Dictionary,dish: String,reason: String,total: int,done: int,station_ids: Array,group_id := "")->void:
	var row:=_dish(data,dish)
	var partial:=done>0
	if partial: row.orders_partial=int(row.orders_partial)+1
	else: row.orders_failed=int(row.orders_failed)+1
	var missing:=maxi(0,total-done)
	row.portions_unserved=int(row.portions_unserved)+missing
	if not row.losses.has(reason): row.losses[reason]=0
	row.losses[reason]=int(row.losses[reason])+1
	if not data.losses.has(reason): data.losses[reason]=0
	data.losses[reason]=int(data.losses[reason])+1
	var sorted_ids:=station_ids.duplicate()
	sorted_ids.sort()
	var key: String="%s|%s|%s"%[reason,dish,"-".join(sorted_ids.map(func(id):return str(id)))]
	if not data.loss_details.has(key):
		data.loss_details[key]={"reason":reason,"dish":dish,"count":0,"portions_unserved":0,"stations":sorted_ids,"group":group_id}
	var detail: Dictionary=data.loss_details[key]
	detail.count=int(detail.count)+1
	detail.portions_unserved=int(detail.portions_unserved)+missing
	push_feed(data,"partial" if partial else "loss",{"dish":dish,"reason":reason,"done":done,"total":total,"stations":sorted_ids,"group":group_id},1)

static func _merge_key(kind: String,payload: Dictionary,source: String,source_name: String)->String:
	if kind=="partial": return "%s|%s|%s|%d|%d"%[kind,str(payload.get("dish","")),str(payload.get("reason","")),int(payload.get("done",0)),int(payload.get("total",0))]
	return "%s|%s|%s|%s|%s"%[kind,str(payload.get("dish","")),str(payload.get("reason","")),source,source_name]

static func push_feed(data: Dictionary,kind: String,payload: Dictionary={},amount := 1,source := "system",source_name := "")->Dictionary:
	var now: float=float(data.get("clock",0.0))
	var key:=_merge_key(kind,payload,source,source_name)
	for index in range(data.feed.size()-1,-1,-1):
		var entry: Dictionary=data.feed[index]
		if now-float(entry.get("at",0.0))>FEED_WINDOW: break
		if str(entry.get("merge_key",""))==key:
			entry.count=int(entry.get("count",0))+maxi(1,amount)
			entry.at=now
			entry.stations=_union_ids(entry.get("stations",[]),payload.get("stations",[]))
			entry.workers_missing=int(entry.get("workers_missing",0))+int(payload.get("workers_missing",0))
			return entry
	var entry: Dictionary={"id":int(data.get("serial",1)),"kind":kind,"source":source,"source_name":source_name,"count":maxi(1,amount),"at":now,"merge_key":key}
	data.serial=int(data.get("serial",1))+1
	for field in ["dish","reason","done","total","stations","group","name","record","workers_missing","text"]:
		if payload.has(field): entry[field]=payload[field].duplicate(true) if payload[field] is Array or payload[field] is Dictionary else payload[field]
	data.feed.push_front(entry)
	while data.feed.size()>MAX_FEED: data.feed.pop_back()
	return entry

static func _union_ids(a: Array,b: Variant)->Array:
	var result:=a.duplicate()
	if b is Array:
		for id in b:
			if id not in result: result.append(id)
	result.sort()
	return result

static func guest_word(value: int)->String:
	var n:=absi(value)%100
	var d:=n%10
	if n>=11 and n<=14: return "гостей"
	if d==1: return "гость"
	if d>=2 and d<=4: return "гостя"
	return "гостей"

static func table_word(value: int)->String:
	var n:=absi(value)%100
	var d:=n%10
	if n>=11 and n<=14: return "столов"
	if d==1: return "стол"
	if d>=2 and d<=4: return "стола"
	return "столов"

static func event_text(entry: Dictionary,dish_names: Dictionary)->String:
	var count: int=int(entry.get("count",1))
	var dish: String=str(entry.get("dish",""))
	var dish_name: String=str(dish_names.get(dish,dish))
	match str(entry.get("kind","")):
		"loss":
			return "%d %s ушли: %s · %s"%[count,guest_word(count),dish_name,reason_label(str(entry.get("reason","")))]
		"partial":
			if count==1: return "Гость получил %d из %d порций · %s · %s"%[int(entry.get("done",0)),int(entry.get("total",0)),dish_name,reason_label(str(entry.get("reason","")))]
			return "%d %s ушли частично обслуженными · %s · %s"%[count,guest_word(count),dish_name,reason_label(str(entry.get("reason","")))]
		"training":
			return "Мастер-класс «%s» освоили %d %s"%[str(entry.get("name","Запись")),count,table_word(count)]
		"installer":
			var tail: String=""
			var missing: int=int(entry.get("workers_missing",0))
			if missing>0: tail=" · %d %s нужны работники"%[missing,table_word(missing)]
			return ("Сборщик установил %d станцию" if count==1 else "Сборщики установили %d станций")%count+tail
		"masterclass":
			return "Начат мастер-класс · "+dish_name
		"group_training":
			return "Назначено обучение · %s · %d %s"%[dish_name,count,table_word(count)]
		"batch":
			return "Заказано %d %s комплектами"%[count,table_word(count)]
		_:
			return str(entry.get("text","Событие кафе"))

static func completion_percent(completed: int,arrived: int)->float:
	return 0.0 if arrived<=0 else float(completed)/float(arrived)*100.0

static func top_reason(data: Dictionary)->String:
	var best: String=""
	var count:=0
	for reason in data.losses:
		if int(data.losses[reason])>count:
			best=str(reason)
			count=int(data.losses[reason])
	return best
