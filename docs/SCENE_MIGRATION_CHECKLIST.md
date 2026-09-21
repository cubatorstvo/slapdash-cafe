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
- [ ] Potato
- [ ] Onion
- [ ] Tomato
- [ ] Carrot
- [ ] Garlic
- [ ] Cabbage
- [ ] Cucumber
- [ ] Beet
- [ ] Pepper
- [ ] Zucchini
- [ ] Pickle
- [ ] Lemon
- [ ] Sausage
- [ ] Mushroom
- [ ] Eggplant
- [ ] Boot
- [ ] Bolt

## Готовая еда / подача
- [ ] Wine serving
- [ ] Fried potato serving
- [ ] Sausage serving
- [ ] Steak & pasta serving
- [ ] Burger serving
- [ ] Cheeseburger serving
- [ ] Spicy burger serving
- [ ] Solyanka serving

## Основное кафе
- [ ] Authored cafe world / stage roots
- [ ] Stage 1 floor and shell
- [ ] Zone A
- [ ] Zone B
- [ ] Zone C
- [ ] Zone D
- [ ] Main entrance / exterior apron
- [ ] Rear spine / annex transition
- [ ] Expansion partition
- [ ] Automatic sliding door
- [ ] Cafe signs / room signs / zone signs

## Постоянный декор кафе
- [ ] “Мы почти умеем” sign
- [ ] Decorative cafe plant
- [ ] Garland
- [ ] “Моё кафе” board
- [ ] Market computer + desk
- [ ] Delivery truck
- [ ] Delivery parcel box
- [ ] Garland reel

## Комната отдыха
- [ ] Staff lounge authored room
- [ ] Chef bed
- [ ] Sofa
- [ ] Coffee table
- [ ] Television + cabinet
- [ ] Rocking chair
- [ ] Foosball
- [ ] Arcade machine
- [ ] Table tennis
- [ ] Board games
- [ ] Bookcase
- [ ] Beanbag
- [ ] Tea station
- [ ] Jukebox
- [ ] Aquarium
- [ ] Lounge plant
- [ ] Floor lamp
- [ ] Snack fridge
- [ ] Stool
- [ ] Rug
- [ ] Lounge ceiling / decorative lights

## Лаборатория — помещение и базовая установка
- [ ] Laboratory authored room
- [ ] Initial assembly bench
- [ ] Initial lab module 1
- [ ] Initial lab module 2
- [ ] Initial lab module 3
- [ ] Initial switches / start button
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
