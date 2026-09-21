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
- [ ] Service bell
- [ ] Sauce ramp upgrade
- [ ] Counter storage / product shelf module

## Посуда и предметы первой стойки
- [ ] Plate
- [ ] Serving tray
- [ ] Wine jug
- [ ] Wine cup
- [ ] Rag
- [ ] Holed pan
- [ ] Sauce bowl
- [ ] Potato
- [ ] Sausage
- [ ] Tomato

## Meat & pasta props
- [ ] Steak
- [ ] Pot
- [ ] Water pitcher
- [ ] Pasta bag
- [ ] Salt shaker
- [ ] Meat spatula
- [ ] Pasta salt tool
- [ ] Pasta spatula
- [ ] Steak serving plate
- [ ] Pasta serving plate

## Burger props
- [ ] Patty
- [ ] Patty spatula
- [ ] Seasoning
- [ ] Bun
- [ ] Cheese
- [ ] Sauce bottle
- [ ] Chili sauce bottle
- [ ] Burger assembly plate

## Solyanka props
- [ ] Cauldron
- [ ] Lighter
- [ ] Stirring paddle
- [ ] Solyanka salt
- [ ] Mug
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
