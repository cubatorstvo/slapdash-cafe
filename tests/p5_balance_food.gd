extends RefCounted
## Physical completion fixtures only. Prices, rewards, unlocks and skills stay in production code.

static func prepare(model, dish: String, grade := "B", order: Dictionary = {}) -> void:
	model.reset(dish)
	var full := grade == "S"
	if dish in ["sausage", "potato", "wine"]:
		model.chef_order = order.duplicate(true)
		var request: Dictionary = preload("res://scripts/chef_orders.gd").standard(dish) if order.is_empty() else order
		var tray: Vector2 = model.Layout.TRAY
		var height: float = model.Layout.TRAY_Y - model.BASE_Y
		if dish == "wine":
			model.cup = tray; model.elevations.cup = height
			model.filled = (float(request.min_ml) + float(request.max_ml)) / 2.0 if full else float(request.min_ml) * 0.25
			model.wine = 1000.0 - model.filled
		else:
			for index in range(int(request.portions)):
				model._load_food(dish, index)
				model.plates[index].point = tray + Vector2(index * 0.3, 0)
				model.elevations["plate_%d" % index] = height
				model.set(dish, model.plates[index].point)
				model.set(dish + "_state", "plate_%d" % index)
				model.elevations[dish] = height + 0.035
				if dish == "sausage": model.sausage_coating = (float(request.coat_min) + float(request.coat_max)) / 2.0 if full else float(request.coat_min) * 0.6
				else:
					var faces: int = int(request.faces) if full else ceili(float(request.faces) * 0.5)
					model.potato_heat = []
					for face in range(6): model.potato_heat.append(1.0 if face < faces else 0.0)
				model._store_food(dish)
	elif dish == "meal":
		model.meat_state = "plate"; model.meat_sides = [1.0, 1.0]
		model.meat_salt = 1.0 if full else 0.0
		model.served_pasta = 100.0; model.served_cooked = 1.0
		model.served_stirred = 1.0 if full else 0.0; model.served_salt = 1.0 if full else 0.0
	elif dish in ["burger", "cheeseburger", "spicy_burger"]:
		model.patty_sides = [1.0, 1.0]; model.patty_season = 1.0 if full else 0.0
		model.patty_state = "assembly"; model.positions.patty = model.ASSEMBLY; model.positions.bun = model.ASSEMBLY
		model.bun_toast = 1.0; model.sauce_amount = 1.0 if full else 0.0
		model.cheese_applied = dish == "cheeseburger"; model.chili_amount = 1.0 if dish == "spicy_burger" else 0.0
	else:
		model.fire_started = true; model.stir_progress = 1.0 if full else 0.0; model.salt_amount = 1.0 if full else 0.0
		for item in ["potato", "onion", "tomato", "carrot", "garlic", "cabbage", "cucumber", "beet", "pepper", "zucchini", "pickle", "lemon", "sausage"]: model.dumped[item] = true
