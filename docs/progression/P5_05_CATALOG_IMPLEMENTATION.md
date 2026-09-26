# P5.05 — каталоги лаборатории и комнаты отдыха

Исходный `main`: `154ea5db26e6e7ac97be6f7e5d7d80990da45bff`.

Проверенный код до этого отчёта: `6ed9deb6743187cad6d2266fe5cc0c8a92459c8a`.

Спецификация `docs/progression/P5_CATALOG_RULES.json` не менялась: технические имена в ней уже совпадают с магазином. `removed_ids` пуст. Цены всех 52 строк оставлены (`preserve_current`).

## Куда легла спецификация

JSON не исполняется. Принятые группы, предметы и расширения записаны в `scripts/progression/catalog_bindings.gd`. Проверка доступности — в `scripts/progression/catalog_purchase.gd` и в существующем `FeatureAccess`.

| Строка спецификации | Запись | Кто решает показ и покупку |
|---|---|---|
| 16 групп `groups[]` | `CatalogBindings.GROUPS` | `FeatureCatalog.definition` накладывает `min_stars`, `requires_features`, `requires_milestones`, заголовок, пользу и причину закрытия |
| Новые возможности `rest_comfort`, `recalibration_tuning`, `rest_games`, `recalibration_automation`, `lab_automation_large`, `recalibration_automation_large`, `rest_atmosphere` | те же группы, `sort_order = group.sort_order + 300` | `FeatureCatalog.ordered_ids` добавляет их к старому списку |
| 4 расширения комнат | `CatalogBindings.EXPANSIONS` и звёзды `Laboratory.STAGES` / `Lounge.STAGES` | `FeatureAccess.access` в `purchase`, повторно `Laboratory.expand` / `Lounge.expand` |
| 52 товара | `CatalogBindings.ITEMS` | `FeatureCatalog.item_features` возвращает одну возможность; `FeatureAccess.item_access` — и для витрины, и для команды хоста |
| Базовые детали `lab_0/1/2` | контекст `base_lab` | видна текущая и уже установленные; будущая деталь скрыта, пока `lab_stage` не дошёл до неё |
| Улучшения мебели `rest_upgrade_*` | та же возможность, что у базового `rest_<lounge_id>` | скрыты, пока базовый `lounge_id` не установлен |
| Вехи `staff_6_seen`, `staff_9_seen`, `lounge_expansion_1_completed`, `lounge_expansion_2_completed` | `ProgressionDirector.migrate_from_game_state` | штат — уникальные положительные id из `clone_options()`; расширения комнаты — из фактического `lounge_tier`. Факт не снимается |

Мини-игра `formula_research` остаётся отдельной возможностью (2★, веха `first_group_training_completed`, родитель `clone_lab`). Магазинная группа «Формула быстрее 100%» пишет в `formula_upgrades` и не подменяет мини-игру.

Старые звёздные пороги в каталоге и в `CafeShop.order` для видов `lab`, `lab_upgrade` и `lounge` больше не добавляют второй замок. Кухня, оборудование и декор сохраняют свои звёзды.

## Имена

| В игре | Техническое имя |
|---|---|
| Диван, уже стоит в новой комнате | сохранение `lounge_items` содержит `sofa`; карточка магазина `rest_sofa` |
| Телевизор | `rest_television`, возможность только `video_training` |
| Растения комнаты отдыха | `rest_plants`, возможность `rest_comfort` |
| Уличные растения двора | `plants` в `cafe_catalogue.gd`, возможность `decor_basic`, это не `rest_plants` |
| Улучшение мебели | `rest_upgrade_<lounge_id>`, 12 штук там, где у товара `quality > 0` |
| Почва, жидкость, вода, удобрение | инструменты выращивания, не новые товары |
| Тряпка | оборудование стойки, не товар лаборатории или комнаты |

Переименований условий нет. Пустой `removed_ids` сохранён.

## Показ

Группа появляется только после своей возможности. Нет денег, посылка в пути, занятая проверка и уже установленный предмет оставляют карточку на месте и меняют её состояние. Будущая группа не рисуется серой карточкой. Пустые разделы «Лаборатория» и «Комната отдыха» скрываются; если открыт скрытый раздел, витрина переходит к доступному родителю, а затем к оборудованию. Обновление страницы не сбрасывает прокрутку, если вкладка та же.

Прямой `purchase` / `order` вызывает тот же `item_access` или `access`, что и кнопка. `expand` дополнительно требует открытую возможность расширения, свободную проверку и деньги.

## Проверки

Godot `4.7.2` локально, `C:\Godot\Godot_v4.7.2-stable_win64.exe`, отдельный каталог пользователя. GitHub Actions не запускался.

| Скрипт | Результат |
|---|---|
| `tests/test_p5_catalog_rules.gd` | `PASS: P5.05 catalogue rules` |
| `tests/test_p5_catalog_contract.gd` | `PASS: P5.04 catalogue contract: 52 items, exact prices, resolved dependencies and acyclic room graph` |
| `tests/test_feature_access.gd` | `PASS: unified feature access contract` |
| `tests/test_feature_access_authority.gd` | `PASS: feature access authority` |
| `tests/test_p5_graph.gd` | `PASS: P5.04 graph event boundaries` |

`tests/test_clone_laboratory.gd` по-прежнему падает раньше новой проверки расширения: после `_refresh_progression` базовая лаборатория на 2★ уже записывает стандартную формулу 100%, а `lab.action` для образца требует возможность `formula_research` (веха группового обучения). Оба правила были на `main` до этого этапа. Утверждение `Policy.expand` обновлено: на 2★ без вех каталога расширение лаборатории отклоняется.

Физические мини-игры заново не прогонялись. Цены, награды, миграции старых сохранений, финал 5★, личное обучение, готовка и расчёт эффектов лаборатории не менялись.
