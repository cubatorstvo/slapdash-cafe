# Scene migration checklist

Цель: постепенно перенести постоянную 3D-геометрию и редактируемые визуальные объекты из программной сборки в отдельные Godot-сцены. Текущая программная генерация пока сохраняется как рабочая реализация; новые сцены добавляются параллельно и не подключаются вместо неё до отдельного этапа интеграции.

Правило работы: каждая законченная сцена коммитится отдельно. В том же коммите обновляется этот чек-лист.

## Персонажи
- [x] Player — `scenes/actors/player.tscn`
- [x] Customer / taster — `scenes/actors/customer.tscn`
- [x] Cook / clone avatar — `scenes/actors/cook_avatar.tscn`
- [x] Cook notebook + pencil — `scenes/props/cook_notebook.tscn`
- [x] Delivery installer — `scenes/actors/delivery_installer.tscn`
- [x] Growing clone / sprout variant — `scenes/actors/clone_sprout.tscn`
- [x] Remote multiplayer player visual — `scenes/actors/remote_player.tscn`
- [x] Cook lounge accessories: cup, paddle, snack — `scenes/props/cook_lounge_accessories.tscn`

## Производственные станции
- [x] Counter station — `scenes/stations/counter_station.tscn`
- [x] Meat & pasta station — `scenes/stations/meat_pasta_station.tscn`
- [x] Burger / grill station — `scenes/stations/burger_station.tscn`
- [x] Solyanka station — `scenes/stations/solyanka_station.tscn`
- [x] Service bell — `scenes/props/service_bell.tscn`
- [x] Sauce ramp upgrade — `scenes/props/sauce_ramp.tscn`
- [x] Counter storage / product shelf module — `scenes/props/counter_storage.tscn`

## Посуда и предметы первой стойки
- [x] Plate — `scenes/props/plate.tscn`
- [x] Serving tray — `scenes/props/serving_tray.tscn`
- [x] Wine jug — `scenes/props/wine_jug.tscn`
- [x] Wine cup — `scenes/props/wine_cup.tscn`
- [x] Rag — `scenes/props/rag.tscn`
- [x] Holed pan — `scenes/props/holed_pan.tscn`
- [x] Sauce bowl — `scenes/props/sauce_bowl.tscn`
- [x] Potato — `scenes/props/potato.tscn`
- [x] Sausage — `scenes/props/sausage.tscn`
- [x] Tomato — `scenes/props/tomato.tscn`

## Meat & pasta props
- [x] Steak — `scenes/props/steak.tscn`
- [x] Pot — `scenes/props/pasta_pot.tscn`
- [x] Water pitcher — `scenes/props/water_pitcher.tscn`
- [x] Pasta bag — `scenes/props/pasta_bag.tscn`
- [x] Salt shaker — `scenes/props/salt_shaker.tscn`
- [x] Meat spatula — `scenes/props/meat_spatula.tscn`
- [x] Pasta salt tool — `scenes/props/pasta_salt_tool.tscn`
- [x] Pasta spatula — `scenes/props/pasta_spatula.tscn`
- [x] Steak serving plate — `scenes/props/steak_serving_plate.tscn`
- [x] Pasta serving plate — `scenes/props/pasta_serving_plate.tscn`

## Burger props
- [x] Patty — `scenes/props/patty.tscn`
- [x] Patty spatula — `scenes/props/patty_spatula.tscn`
- [x] Seasoning — `scenes/props/burger_seasoning.tscn`
- [x] Bun — `scenes/props/burger_bun.tscn`
- [x] Cheese — `scenes/props/cheese.tscn`
- [x] Sauce bottle — `scenes/props/sauce_bottle.tscn`
- [x] Chili sauce bottle — `scenes/props/chili_sauce_bottle.tscn`
- [x] Burger assembly plate — `scenes/props/burger_assembly_plate.tscn`

## Solyanka props
- [x] Cauldron — `scenes/props/solyanka_cauldron.tscn`
- [x] Lighter — `scenes/props/solyanka_lighter.tscn`
- [x] Stirring paddle — `scenes/props/solyanka_paddle.tscn`
- [x] Solyanka salt — `scenes/props/solyanka_salt.tscn`
- [x] Mug — `scenes/props/solyanka_mug.tscn`
- [x] Potato — `scenes/props/solyanka_potato.tscn`
- [x] Onion — `scenes/props/solyanka_onion.tscn`
- [x] Tomato — `scenes/props/solyanka_tomato.tscn`
- [x] Carrot — `scenes/props/solyanka_carrot.tscn`
- [x] Garlic — `scenes/props/solyanka_garlic.tscn`
- [x] Cabbage — `scenes/props/solyanka_cabbage.tscn`
- [x] Cucumber — `scenes/props/solyanka_cucumber.tscn`
- [x] Beet — `scenes/props/solyanka_beet.tscn`
- [x] Pepper — `scenes/props/solyanka_pepper.tscn`
- [x] Zucchini — `scenes/props/solyanka_zucchini.tscn`
- [x] Pickle — `scenes/props/solyanka_pickle.tscn`
- [x] Lemon — `scenes/props/solyanka_lemon.tscn`
- [x] Sausage — `scenes/props/solyanka_sausage.tscn`
- [x] Mushroom — `scenes/props/solyanka_mushroom.tscn`
- [x] Eggplant — `scenes/props/solyanka_eggplant.tscn`
- [x] Boot — `scenes/props/solyanka_boot.tscn`
- [x] Bolt — `scenes/props/solyanka_bolt.tscn`

## Готовая еда / подача
- [x] Wine serving — `scenes/food/wine_serving.tscn`
- [x] Fried potato serving — `scenes/food/fried_potato_serving.tscn`
- [x] Sausage serving — `scenes/food/sausage_serving.tscn`
- [x] Steak & pasta serving — `scenes/food/steak_pasta_serving.tscn`
- [x] Burger serving — `scenes/food/burger_serving.tscn`
- [x] Cheeseburger serving — `scenes/food/cheeseburger_serving.tscn`
- [x] Spicy burger serving — `scenes/food/spicy_burger_serving.tscn`
- [x] Solyanka serving — `scenes/food/solyanka_serving.tscn`

## Основное кафе
- [x] Authored cafe world / stage roots — `scenes/cafe/cafe_world.tscn`
- [x] Stage 1 floor and shell — `scenes/cafe/stage1_shell.tscn`
- [x] Zone A — `scenes/cafe/zone_a.tscn`
- [x] Zone B — `scenes/cafe/zone_b.tscn`
- [x] Zone C — `scenes/cafe/zone_c.tscn`
- [x] Zone D — `scenes/cafe/zone_d.tscn`
- [x] Main entrance / exterior apron — `scenes/cafe/main_entrance.tscn`
- [x] Rear spine / annex transition — `scenes/cafe/rear_spine.tscn`
- [x] Expansion partition — `scenes/cafe/expansion_partition.tscn`
- [x] Automatic sliding door — `scenes/cafe/automatic_sliding_door.tscn`
- [x] Cafe signs / room signs / zone signs — `scenes/cafe/cafe_signs.tscn`

## Постоянный декор кафе
- [x] “Мы почти умеем” sign — `scenes/decor/almost_ready_sign.tscn`
- [x] Decorative cafe plant — `scenes/decor/cafe_plant.tscn`
- [x] Garland — `scenes/decor/garland.tscn`
- [x] “Моё кафе” board — `scenes/decor/my_cafe_board.tscn`
- [x] Market computer + desk — `scenes/decor/market_computer_desk.tscn`
- [x] Delivery truck — `scenes/decor/delivery_truck.tscn`
- [x] Delivery parcel box — `scenes/decor/delivery_parcel_box.tscn`
- [x] Garland reel — `scenes/decor/garland_reel.tscn`

## Комната отдыха
- [x] Staff lounge authored room — `scenes/lounge/staff_lounge.tscn`
- [x] Chef bed — `scenes/lounge/chef_bed.tscn`
- [x] Sofa — `scenes/lounge/sofa.tscn`
- [x] Coffee table — `scenes/lounge/coffee_table.tscn`
- [x] Television + cabinet — `scenes/lounge/television_cabinet.tscn`
- [x] Rocking chair — `scenes/lounge/rocking_chair.tscn`
- [x] Foosball — `scenes/lounge/foosball.tscn`
- [x] Arcade machine — `scenes/lounge/arcade_machine.tscn`
- [x] Table tennis — `scenes/lounge/table_tennis.tscn`
- [x] Board games — `scenes/lounge/board_games.tscn`
- [x] Bookcase — `scenes/lounge/bookcase.tscn`
- [x] Beanbag — `scenes/lounge/beanbag.tscn`
- [x] Tea station — `scenes/lounge/tea_station.tscn`
- [x] Jukebox — `scenes/lounge/jukebox.tscn`
- [x] Aquarium — `scenes/lounge/aquarium.tscn`
- [x] Lounge plant — `scenes/lounge/lounge_plant.tscn`
- [x] Floor lamp — `scenes/lounge/floor_lamp.tscn`
- [x] Snack fridge — `scenes/lounge/snack_fridge.tscn`
- [x] Stool — `scenes/lounge/stool.tscn`
- [x] Rug — `scenes/lounge/lounge_rug.tscn`
- [x] Lounge ceiling / decorative lights — `scenes/lounge/lounge_ceiling_lights.tscn`

## Лаборатория — помещение и базовая установка
- [ ] Laboratory authored room
- [x] Initial assembly bench — `scenes/lab/assembly_bench.tscn`
- [x] Initial lab module 1 — `scenes/lab/initial_module_1.tscn`
- [x] Initial lab module 2 — `scenes/lab/initial_module_2.tscn`
- [x] Initial lab module 3 — `scenes/lab/initial_module_3.tscn`
- [x] Initial switches / start button — `scenes/lab/initial_controls.tscn`
- [ ] Cable reel
- [ ] Formula stabilizer / research apparatus
- [ ] Sample holder
- [ ] Microscope
- [ ] Tool shelf
- [ ] Pot rack / grow shelf

## Лаборатория — выращивание
- [ ] Clone pot
- [ ] Grow lamp
- [ ] Auto feeder
- [ ] Irrigation tank
- [ ] Planter
- [ ] Extractor
- [ ] Nutrient dispenser
- [ ] Climate unit
- [ ] Production controller
- [ ] Extra rack section
- [ ] Soil scoop
- [ ] Formula/sample pipette
- [ ] Watering tool
- [ ] Fertilizer tool

## Лаборатория — формула и рекалибровка
- [ ] Formula power amplifier
- [ ] Formula turbo block
- [ ] Formula synthesizer
- [ ] Precision valve
- [ ] Damper
- [ ] Recalibration chair
- [ ] Focus synchronizer
- [ ] Slow-pulse module
- [ ] Auto recalibration module
- [ ] Chair speed module

## Мастер-классы / презентация
- [ ] Masterclass camera rig
- [ ] Physical cookbook
- [ ] Presentation accessory anchors

## UI scenes
- [ ] Cafe HUD
- [ ] Main / pause menu
- [ ] Cafe office
- [ ] Cookbook UI
- [ ] Training / course editor
- [ ] Shop panels
- [ ] Statistics panels
- [ ] Development panels
- [ ] Laboratory panels
- [ ] Staff lounge panels

## Остаётся программным
Динамические эффекты и служебная визуализация: струи и проливы жидкостей, брызги, огонь/частицы, target/grip rings, training bounds, placement ghost/beacon, маршруты, летящая еда при поедании, runtime-позы рук, прокладываемый игроком кабель, динамические Label3D и числовые индикаторы.
