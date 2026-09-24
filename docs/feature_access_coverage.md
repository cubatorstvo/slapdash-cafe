# Feature access coverage

`FeatureAccess` is the only progression-facing availability evaluator. Presentation asks whether a feature is `visible`; commands ask whether it is `enabled`. Temporary state such as money, ownership, pending delivery, shift state, or host authority never erases an already introduced feature.

## Feature definitions

| Feature | Introduced by | Minimum chapter / star | Depends on | Main surfaces |
| --- | --- | ---: | --- | --- |
| `shop_basic` | new cafe | 0 | — | PC Shop, base equipment, purchase |
| `stars` | first guest | 0 | — | Development, inspections, decor, basic new tables |
| `clone_lab` | first guest | 0 | `shop_basic` | Development/Lab, starter lab goods |
| `clone_growth` | first clone | 1 | `clone_lab` | clone growth, advanced lab goods |
| `live_training` | first clone | 1 | `clone_growth` | personal/live training |
| `staff_roster` | first clone | 1 | `clone_growth` | PC Staff |
| `rest_basics` | first clone | 1 | `staff_roster` | Development/Rest, lounge shop goods |
| `video_recording` | first star | 1 | `stars` | masterclass recording, sauce ramp |
| `video_training` | first saved recording | 2 | recording + staff | PC Training/video library |
| `group_training` | accepted personal lesson | 1 | `live_training` | group actions / training details |
| `recalibration` | first clone | 1 | `clone_growth` | calibration lab branch |
| `lab_automation` | first automatic feed/service fact | 3 | `recalibration` | automated growing lab devices |
| `kitchen_pair` | second star | 2 | `clone_growth` | pair kitchen, meal recipe/equipment |
| `kitchen_grill` | third star | 3 | pair kitchen | burger kitchen/recipes/equipment |
| `kitchen_solyanka` | fourth star | 4 | grill kitchen | solyanka kitchen/recipe/equipment |

## Entry points

| Entry point | Feature source / behavior |
| --- | --- |
| PC top navigation | Stable order: Cafe, Shop, Development; Staff appears after `staff_roster`; Training appears after `video_training`. Settings/save is a compact permanent top button. |
| PC hidden deep link | `nearest_visible_page()` walks to the declared parent instead of opening hidden content. |
| Cafe analytics | Nested under Cafe overview; no separate top-level navigation section. |
| Development | Always present. Before `stars`, it shows only the first-evaluation promise and nearest step. After introduction it links to introduced Lab/Rest pages and exposes at most one `Soon` teaser. |
| Shop categories | Each category maps through `SHOP_CATEGORY_FEATURES`; unintroduced categories are hidden, introduced categories remain visible. |
| Shop product row | Every item has `feature`; hidden only before introduction. Money/host/pending/owned conditions become disabled reasons. |
| Shop batch type chooser | Uses each station product's feature; future kitchen types are hidden. |
| Purchase command | `CafeService.purchase()` re-evaluates the same item/feature access on the authoritative service before delegating to the shop. |
| Masterclass command | `CafeService.request_masterclass()` checks `video_recording` before existing dish/time/equipment validation. |
| Clone creation | `CafeService.create_clone()` checks `clone_lab`; a successful creation records `first_clone_created`. |
| Star inspection | `CafeService.start_banquet()` checks `stars` before existing inspection requirements. |
| Cookbook | Starter recipes use `shop_basic`; meal/burgers/solyanka follow their kitchen feature. Hidden direct page requests fall back to the index. |
| Physical late devices | Their catalogue item cannot be introduced/purchased before its feature; existing physical-action validation remains authoritative for ownership, distance, phase and busy state. |
| Staff links | Staff points to introduced lab/rest problems; hidden problem links fall back through page access. |
| Notifications / overview problem links | All PC routing passes through `navigate/open_shop/open_problem_*`, which resolves hidden pages/categories first. |
| Save/load | Cafe feature facts and per-player hint facts are serialized in `feature_access`; old saves reconstruct monotonic facts from existing progression data. |
| Reactive UI | Feature revision participates in the PC live stamp; rebuild preserves same-page scroll, selections live outside rebuilt controls, and focus is restored by nav/text signature. |

## Shop product coverage

All concrete products are required by regression test to contain a valid `feature` ID.

| Product family | Feature |
| --- | --- |
| `sauce`, `plates`, `cup`, `pan`, `jug` | `shop_basic` |
| `sauce_ramp` | `video_recording` |
| `counter` | `stars` |
| `kitchen`, `meat_kit`, `pasta_kit` | `kitchen_pair` |
| `grill_kitchen`, `grill_kit`, `assembly_kit` | `kitchen_grill` |
| `solyanka_kitchen`, `fire_kit`, `stir_kit`, `salt_kit` | `kitchen_solyanka` |
| `lab_0..2` | `clone_lab` |
| formula/general growth laboratory upgrades | `clone_growth` |
| calibration laboratory upgrades | `recalibration` |
| automatic feeder/irrigation/planter/extractor/production controller | `lab_automation` |
| all lounge furniture/upgrades | `rest_basics` |
| sign/plants/lights decor | `stars` |

## Acceptance state sequence

| State | Cafe | Shop | Development | Staff | Training | Important newly visible systems |
| --- | --- | --- | --- | --- | --- | --- |
| New cafe | visible | visible | promise only | hidden | hidden | base shop / starter recipes |
| First guest | visible | visible | star + lab introduction | hidden | hidden | stars, clone lab, table/decor categories |
| 1★ before clone | visible | visible | visible | hidden | hidden | recording/masterclass |
| First clone | visible | visible | visible | visible | hidden | staff, rest, live training, recalibration |
| Personal lesson accepted | visible | visible | visible | visible | hidden | group training detail |
| 2★ + first recording | visible | visible | visible | visible | visible | video library/training, pair kitchen |
| Mature cafe | visible | visible | visible | visible | visible | later kitchens and late lab systems as introduced |

Regression coverage lives in `tests/test_feature_access.gd`: chronological visibility, hidden deep-link fallback, low-money visibility, host-only disabled state, monotonic clone knowledge, recording/training transition, later kitchens, snapshot persistence, and complete catalogue feature IDs.
