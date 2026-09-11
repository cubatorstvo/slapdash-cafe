# Sol playtest: физическая поварская книга

Ветка `cursor/finish-cookbook-bell-and-cooking-polish-fee5`, PR https://github.com/cubatorstvo/slapdash-cafe/pull/1  
Модель: `cursor-grok-4.6-high`. Godot **4.7.stable official** (`5b4e0cb0f`).

## Исходная цель

Подготовить физическую поварскую книгу к технической проверке GPT-5.6 Sol и визуальному плейтесту владельцем. После реализации самостоятельно проверить, исправить найденные проблемы, закоммитить и запушить в эту ветку, оставить PR открытым. Владелец принимает результат сам.

<details>
<summary>Полный текст полученного задания</summary>

Продолжи в cubatorstvo/slapdash-cafe, ветка cursor/finish-cookbook-bell-and-cooking-polish-fee5, PR #1, base main. Последний проверенный коммит a4567c2b37bd840c63003e77a2ab0c2b64f85965. Получи актуальную ветку и учти последующие изменения.

ЦЕЛЬ ЗАДАЧИ: подготовить физическую поварскую книгу к технической проверке GPT-5.6 Sol и визуальному плейтесту владельцем. Работай на Godot 4.7. После реализации самостоятельно проверь, исправь найденные проблемы, закоммить и запушь в эту ветку, оставь PR открытым. Владелец дальше принимает результат сам; Astra завершения не ожидает.

1. Исправить нестабильность сетевого теста.
tests/run_online_cafe_test.py запускает хост, гостя и позднего наблюдателя. При приёмке хост и гость PASS, наблюдатель FAIL: observer Timeout at stage 1. Повторный запуск всех трёх PASS. Гипотеза: tests/test_online_cafe.gd ожидает у наблюдателя kitchen.training.phase == recording, но хост и гость могут завершить этап раньше, чем наблюдатель увидит его.
Сделай тест с явными подтверждениями: хост начинает запись; наблюдатель получает реплицированное состояние и проверяет станцию, фазу и участников; отправляет подтверждение с идентификатором этапа; хост разрешает завершение после подтверждения; наблюдатель проверяет завершённое состояние. Служебные барьеры размести в тестовом сценарии. Тайм-аут сохраняется как защита от зависания и сообщает роль, ожидаемый этап, текущую фазу и подтверждения. Сохрани строгие проверки ошибок, кодов завершения и результатов всех процессов. Если причина в игровой синхронизации, исправь её с регрессионной проверкой конкретного нарушения.

2. Проверить соответствие книги требованиям.
Книга — большой трёхмерный предмет в руках: игрок читает реальные страницы. Общая реализация для игрока, сетевых участников и клонов. Комично большой размер, примерно 1.7 от исходного. Открытие доступно где угодно и при обучении. Вне готовки открывается оглавление, при обучении — выбранный рецепт. Открытие и перелистывание воспроизводятся клонами из записи и видны по сети. Навигация нажатием на страницы, области клика совпадают с видимыми верхними и нижними кнопками. Требования сгруппированы по компонентам; одинаковые названия в книге и живом прогрессе. Обжарка сторон и варка — проценты; соль и перемешивание — ✓/×. Рецепт описывает результат, игрок придумывает способ. Управление через короткое обучение и контекстные подсказки, у звонка (E) Завершить. Пояснения критериев при наведении. Убери сохранившиеся фразы «Выбери блюдо справа», «Способ приготовления за тобой» и постоянные текстовые списки кнопок, если встретятся.

3. Проверки Godot 4.7.
tests/test_cookbook.gd с verbose, tests/test_quality.gd, tests/test_input.gd. После исправления сетевого теста tests/run_online_cafe_test.py пять раз подряд. Сохрани полные логи и exit codes. В cookbook сохраняются проверки соответствия кликов реальным UV меша, верхних/нижних кнопок, исчезновения hover-подсказки, совместимости записей, освобождения аудио. Исправляй причины неудач и повторяй затронутые проверки. Итоговый отчёт включает обнаруженные сбои и исправления.

4. Визуальные материалы реальной сцены.
Скриншоты: оглавление от первого лица; каждый из четырёх рецептов; живой частичный прогресс стейка с макаронами; игрок с книгой глазами другого участника; клон воспроизводит открытие; контекстная подсказка звонка. Оглавление и самый насыщенный рецепт покажи в 1280x800 и 1920x1080. Короткое видео или последовательность кадров: открыть, выбрать рецепт, закрыть, открыть во время обучения, завершить звонком. Сохрани доступными артефактами и размести ссылки в PR.

5. Передача и обязательная документация PR.
Пользователь хочет видеть в PR исходную цель, полный текст задания И результат. В описании PR помести исходную цель и полный текст ЭТОГО полученного задания в раскрывающийся блок «Исходное задание». Отдельный раздел «Результат». Если лимит описания не вмещает текст, полный текст сохрани в markdown-файле в репозитории и дай прямую ссылку в PR. Закоммить и запушь всё в текущую ветку. PR остаётся открытым для Sol и владельца.

</details>

## Результат

### Изменения для игрока

Физическая книга в руках (не оверлей): B открывает её где угодно. Вне показа — оглавление, во время записи — текущий рецепт. Страницы настоящие (SubViewport на меше), клики по видимым кнопкам «Содержание» / «Закрыть» / названиям блюд. Требования сгруппированы по компонентам; те же подписи в живой карточке. Стороны и варка — проценты, соль и перемешивание — ✓/×. У звонка подсказка `(E) Завершить показ`. Фраз «Выбери блюдо справа», «Способ приготовления за тобой» и постоянного списка кнопок в UI нет.

### Сетевой сбой и исправление

Причина — **расписание теста**, не игровая репликация. Наблюдатель ждал `kitchen.training.phase == recording`. Хост и гость могли закрыть проход (гость выходит → хост отменяет запись участника) до того, как наблюдатель увидит короткое окно.

Исправление только в тестовом сценарии. Handshake двухфазный:

1. Хост открывает кухню `meal` с двумя живыми ролями и **держит** `recording`.
2. Наблюдатель проверяет блюдо, фазу, `live_roles` и участников, затем шлёт `kitchen-live`.
3. Хост, всё ещё в `recording`, отвечает `kitchen-release`.
4. Гость выходит только после `kitchen-release` от peer `1`.
5. Наблюдатель сначала видит host release, затем `idle`.
6. Таймаут: `role=… stage=… expected=… kitchen=… station1/2=… acks=… members=…`.
7. Обёртка по-прежнему валит прогон на `SCRIPT ERROR` / `ERROR:` / `FAIL:` / отсутствие `PASS:` / ненулевой код любого процесса.

Последовательность: `observer kitchen-live ACK → host kitchen-release → guest leaves → observer sees idle`.

Барьер: `tests/online_barrier.gd` (дочерний узел `Session/OnlineBarrier`, одинаковый путь у всех пиров).

### Обнаруженные сбои при самопроверке

| Сбой | Причина | Исправление |
|---|---|---|
| Observer `Timeout at stage 1` (флейк) | Тест ждал фазу, которую могли закрыть раньше | Явный ack `kitchen-live`, затем host `kitchen-release` |
| Живой прогресс макарон `0%` / `0/100 г` / соль `×` на скрине | `start_pass([1, 0])` оставляет зону макарон неактивной; `_restore_inactive` обнуляет её каждый тик | Для кадра и регрессии обе роли живые `[1, 2]`; `test_cookbook.gd` проверяет `40/100 г` и `Соль [✓]` после тика |
| На живом кадре книги поверх страницы `[E] Тарелка стойка` | Physics выключен для заморозки прогресса, HUD не чистился | Capture гасит prompt и label стойки |

Игровая синхронизация кухни не менялась: пустая неактивная зона по-прежнему реплеится из пустого снимка — так и задумано для одиночной записи роли стейка.

### Изменённые файлы

| Файл | Назначение |
|---|---|
| `tests/online_barrier.gd` | Тестовый RPC-барьер подтверждений этапа |
| `tests/test_online_cafe.gd` | Сценарий host/guest/observer: `kitchen-live` → `kitchen-release` → idle |
| `tests/run_online_cafe_test.py` | Каталог логов и строка `CODES: host=… guest=… observer=…` |
| `tests/test_cookbook.gd` | Регрессия: две живые роли кухни сохраняют массу и соль макарон |
| `tests/capture_cookbook.gd` | Скриншоты и кадры последовательности для Sol/владельца |
| `docs/PR1_SOL_PLAYTEST.md` | Этот отчёт |
| `docs/verification/sol-playtest/` | Полные логи unit и пяти сетевых прогонов |

### Команды и результаты

Godot: `/tmp/godot/godot` → `4.7.stable.official.5b4e0cb0f`.

| Команда | Exit | Итог |
|---|---|---|
| `godot --headless --verbose --path . --script tests/test_cookbook.gd` | **0** | `PASS: cookbook, recording compatibility, presence and bell`. Нет `ObjectDB` / `resources still in use` / `ERROR:` / `FAIL:` |
| `godot --headless --path . --script tests/test_quality.gd` | **0** | `PASS: live grading, partial recipes, independent stock and conserved pouring` |
| `godot --headless --path . --script tests/test_input.gd` | **0** | `PASS: item input, prank replay and FPS zones` |
| `python3 tests/run_online_cafe_test.py /tmp/godot/godot <dir>` ×5 | **0,0,0,0,0** | Каждый прогон `CODES: host=0 guest=0 observer=0`, все три `PASS:` |
| `python3 tests/run_online_cafe_test.py /tmp/godot/godot …/online-release-1` | **0** | Двухфазный handshake: host получает observer ACK до `kitchen-release`; guest и observer получают host release до leave/`idle`. `CODES: host=0 guest=0 observer=0` |

Полные логи:

- [test_cookbook.log](https://github.com/cubatorstvo/slapdash-cafe/blob/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/test_cookbook.log)
- [test_quality.log](https://github.com/cubatorstvo/slapdash-cafe/blob/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/test_quality.log)
- [test_input.log](https://github.com/cubatorstvo/slapdash-cafe/blob/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/test_input.log)
- [online_five_summary.txt](https://github.com/cubatorstvo/slapdash-cafe/blob/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/online_five_summary.txt)
- [online-run-1](https://github.com/cubatorstvo/slapdash-cafe/tree/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/online-run-1) … [online-run-5](https://github.com/cubatorstvo/slapdash-cafe/tree/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/online-run-5)
- [online-release-1](https://github.com/cubatorstvo/slapdash-cafe/tree/cursor/finish-cookbook-bell-and-cooking-polish-fee5/docs/verification/sol-playtest/online-release-1) — двухфазный `kitchen-live` / `kitchen-release`

Cookbook по-прежнему проверяет UV меша (`UV.y = local.z/PAGE.y+0.5`), клик верхней кнопки оглавления и нижней «Закрыть»/«Содержание», сброс hover-подсказки, совместимость старых кадров без `presentation`, остановку аудио перед `free()`.

### Скриншоты и видео

Артефакты агента (рендер реальной сцены, Xvfb + Godot 4.7):

| Кадр | Ссылка |
|---|---|
| Оглавление 1280×800 | [sol_index_fp_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_index_fp_1280.png) |
| Вино | [sol_recipe_wine_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_recipe_wine_1280.png) |
| Картофель | [sol_recipe_potato_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_recipe_potato_1280.png) |
| Сосиска | [sol_recipe_sausage_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_recipe_sausage_1280.png) |
| Стейк с макаронами 1280×800 | [sol_recipe_meal_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_recipe_meal_1280.png) |
| Живой частичный прогресс | [sol_live_meal_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_live_meal_1280.png) |
| Книга глазами другого участника | [sol_peer_book_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_peer_book_1280.png) |
| Клон с открытой книгой | [sol_clone_replay_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_clone_replay_1280.png) |
| Звонок `(E) Завершить показ` | [sol_bell_prompt_1280.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_bell_prompt_1280.png) |
| Оглавление 1920×1080 | [sol_index_fp_1920.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_index_fp_1920.png) |
| Стейк с макаронами 1920×1080 | [sol_recipe_meal_1920.png](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fsol_recipe_meal_1920.png) |
| Видео: открыть → рецепт → закрыть → урок → звонок | [sol_playtest_open_select_close_lesson_bell.mp4](https://cursor.com/agents/bc-e9fe381d-b645-4c58-9d35-c67f64f6116b/artifacts?path=%2Fopt%2Fcursor%2Fartifacts%2Fvideos%2Fsol_playtest_open_select_close_lesson_bell.mp4) |

Живой пример на странице и в HUD:  
`Обжарить с 2 сторон [100% / 15%]`, `Соль [×]`, `Сварить [0%]`, `Соль [✓]`, `Перемешать [×]`, `Порция — 100 г [40/100 г]`.

### Краткий ручной плейтест (рендер, не headless)

- Все четыре рецепта читаются на 1280×800: текст не обрезан, руки держат корешок/край обложки, кнопки «Содержание» и «Закрыть» видны.
- Самый плотный рецепт (стейк с макаронами) помещается вместе с зоной hover-пояснения.
- Оглавление и этот рецепт читаются и на 1920×1080.
- Во время показа книга открывается сразу на «Стейк с макаронами» с живыми значениями.
- Клон/пир держит ту же 3D-книгу с открытыми страницами.
- При прицеливании в звонок — `(E) Завершить показ`.

### Оставшиеся ограничения

- Проверки Steam между двумя аккаунтами в этой среде нет: только ENet localhost (три процесса) и headless/Xvfb. Настоящий лобби-плейтест владелец делает сам.
- Кадр «книга закрыта» смотрит через зал: 3D-подписи станций и вывеска кафе накладываются друг на друга. Это подписи мира, не страница книги.
- Capture без звуковой карты даёт ALSA `ERR_CANT_OPEN` и dummy driver; на результат кадров не влияет. Headless-тесты это не валит (другой процесс).
- Одиночная запись только роли стейка по-прежнему показывает макароны как пустую неактивную зону (`0%` / `×`) — корректный реплей, не баг книги.

### SHA

Тип этой ветки после публикации отчёта; точный хеш — в разделе «Результат» описания PR.
