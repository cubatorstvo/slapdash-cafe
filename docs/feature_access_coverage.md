# Feature access coverage

Every ordinary UI/content entry below resolves through the centralized feature catalogs. Temporary domain constraints remain in the owning system and are returned to `FeatureAccess` as action state; they do not define visibility.

## Office/navigation

| Entry | Rule |
|---|---|
| Cafe | `cafe_core` |
| Shop | `shop_basic` |
| Development | `stars` |
| Staff | `staff_roster` |
| Training | `video_recording` |
| Cafe / Statistics | `cafe_statistics` |
| Development / Laboratory | `clone_lab` |
| Development / Rest | `rest_basics` |
| Training / Library | `video_recording` |
| Training / Assignments | `video_training` |
| Training / Groups | `group_training` |
| Settings/save button | `cafe_core`, auxiliary root action |

## Shop categories

| Category | Visibility |
|---|---|
| Equipment | `shop_basic` |
| Tables | any introduced production/late-kitchen child |
| Rooms | any introduced kitchen/lab/rest expansion child |
| Laboratory | any introduced lab/research/growth/recalibration/automation child |
| Lounge | any introduced television/rest child |
| Decor | `decor_basic` |

A category with no introduced child is hidden. Money, ownership and pending delivery affect the product button, not category/product introduction.

## Products

| Product family | Feature |
|---|---|
| `cup`, `jug` | `dish_wine` |
| `pan` | `dish_potato` |
| `sauce` | `dish_sausage` |
| `plates` | `shop_basic` |
| `counter` | `production_tables` |
| `sauce_ramp` | `production_tables` + `content.sauce_ramp` |
| `lab_0..2` | `clone_lab` |
| `meat_kit`, `pasta_kit`, `kitchen`, `expansion` | `kitchen_pair` |
| `grill_kit`, `assembly_kit`, `grill_kitchen`, `specialty_expansion` | `kitchen_specialty` |
| `fire_kit`, `stir_kit`, `salt_kit`, `solyanka_kitchen`, `orchestration_expansion` | `kitchen_orchestration` |
| `sign`, `plants`, `lights` | `decor_basic` |
| formula lab upgrades | `formula_upgrades` |
| manual calibration chair/focus/slow | `recalibration` |
| feeder/irrigation/lamps/nutrients/racks | `lab_growth_upgrades` |
| planter/extractor/production/climate | `lab_automation` |
| automatic calibration/speed | `lab_automation` + recalibration domain dependency |
| basic lounge furniture | `rest_basics` |
| television | `video_training` |
| tier-1 lounge goods | `rest_extended` |
| tier-2 lounge goods | `rest_large` |
| lounge item upgrades | same feature as base item + base-item domain prerequisite |
| lab/lounge room expansion tiers | technical `content.*` tier feature |

## Cookbook

| Recipe | Feature |
|---|---|
| sausage | `dish_sausage` |
| potato | `dish_potato` |
| wine | `dish_wine` |
| meal | `kitchen_pair` |
| burger / cheeseburger / spicy_burger | `kitchen_specialty` |
| solyanka | `kitchen_orchestration` |

An active order or an already accepted station method keeps its recipe readable during migration/compatibility even if the normal feature route is not yet reconstructed.

## Commands

| Command family | Rule |
|---|---|
| single buy | selected item's full feature list + current domain state |
| bundle buy | every selected item + host/funds/current domain state |
| multi-station batch | every selected item; `group_training` when two or more normalized target stations |
| masterclass start/rename/delete | `video_recording` |
| video watch/assignment | `video_training` |
| group training/course with >=2 targets | `video_training` + `group_training` |
| group create/dissolve/rename/active | `group_training` |
| clone create | `clone_growth` |
| formula research | `formula_research` |
| formula upgrade | `formula_upgrades` |
| recalibration | `recalibration` |
| lab automation | `lab_automation` |
| inspection/banquet | `stars` + existing inspection domain requirements |
| parcel take/drop/install | accepted parcel/session domain state; an existing delivery remains serviceable after migration |
| manual service, sleep/wake, save | base process/domain rules |

Unknown commands fail closed. Client-provided `allowed`, stars, price or host flags are not authoritative; RPC/domain entry points rebuild access from host state.
