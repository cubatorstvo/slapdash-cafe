# Observer HUD: итоговая запись клона

Ветка `cursor/observer-clone-record-hud` от `main` (`699a204`).  
Открыть PR: https://github.com/cubatorstvo/slapdash-cafe/compare/main...cursor/observer-clone-record-hud?expand=1

## Исходное задание

Полный текст — в описании PR (блок «Исходное задание»). Кратко: во время своего показа игрок смотрит в физическую книгу; правая верхняя карточка показывает итоговые grade и duration сохранённой записи работающего клона, не live `model.quality()`. World snapshot передаёт `order_dish`, `quality` и `duration`. PROTOCOL `slapdash-cafe-stations-8`.

## Результат

### Поведение HUD
- Ходьба: `recipe_panel` скрыт.
- Свой показ: панель скрыта. Закрытие книги не оставляет список требований. Контекстные подсказки остаются. Live-прогресс только в книге.
- Взгляд на готовящего клона: справа сверху блюдо, крупный grade, `Запись клона · N.N с`, итоговые компоненты принятой записи.
- Уход из фокуса скрывает панель.
- Перезапись рецепта меняет следующие grade/time.

### Файлы
- `scripts/cafe.gd`, `scripts/cafe_hud.gd`, `scripts/work_station.gd`, `scripts/coop_session.gd`, `scripts/steam_lobby.gd`
- `tests/test_observer_hud.gd`, `tests/capture_observer_hud.gd`
- `docs/STAGE_1_STATIONS.md`, `docs/STATION_FOOD_AND_QUALITY.md`

### Проверки
Godot 4.7.stable official. `test_observer_hud`, `test_cookbook`, `test_quality`, `test_steam` — exit 0. Один `run_online_cafe_test.py` — `host=0 guest=0 observer=0`.

### SHA
Тип этой ветки; см. последний коммит после пуша этого файла.
