# Feature Access

`FeatureAccess` is the single read-only access layer for Slapdash Cafe UI and commands. The active implementation follows the first-PR progression path; the future live-training/standard-formula table is intentionally not selectable at runtime.

## Runtime modules

- `scripts/progression/feature_catalog.gd` — stable feature IDs, dependencies, milestones, product and recipe ownership.
- `scripts/progression/progression_director.gd` — host-owned monotonic milestones/unlocks, migration and `feature_progress` snapshot.
- `scripts/progression/feature_access.gd` — `feature_state`, `ui_state`, `check_action`, item/recipe access, route fallback and next-unlock preview.
- `scripts/progression/access_reasons.gd` — stable reason codes and Russian player-facing text.
- `scripts/progression/ui_entry_catalog.gd` — stable office routes, legacy aliases and command-to-feature requirements.

The legacy `scripts/feature_access.gd` and `scripts/feature_definition.gd` files are compatibility facades only; they do not own a second rule set.

## Public API

```gdscript
service.feature_access.feature_state(feature_id)
service.feature_access.ui_state(entry_id, context)
service.feature_access.check_action(action_id, context)
service.feature_access.visible_entries(container_id, context)
service.feature_access.next_unlock_preview()
service.feature_access.item_access(item_id, spec, context)
service.feature_access.recipe_access(dish_id, context)
```

`introduced` is the UI synonym of a persisted unlock. It is not a separate progression flag. `visible` answers presentation visibility; `enabled` answers whether the current action can execute. Money, host ownership, pending delivery, busy state and similar temporary constraints never remove a previously introduced feature.

## Active progression table

| Feature | Unlock |
|---|---|
| `cafe_core`, `shop_basic`, `stars` | new cafe |
| `dish_sausage`, `dish_potato`, `dish_wine` | new cafe |
| `cafe_statistics` | first manual serve |
| `clone_lab` | all three base dishes served |
| `formula_research` | laboratory assembled |
| `clone_growth` | 1★ + first formula |
| `staff_roster`, `production_tables` | first clone created |
| `video_recording` | 1★ + first clone |
| `video_training` | first saved masterclass |
| `group_training` | first completed video training + two compatible stations |
| `rest_basics`, `decor_basic` | first automatic serve |
| `formula_upgrades` | 1★ + first automatic serve |
| `kitchen_pair` | 2★ |
| `lab_growth_upgrades` | 2★ + first automatic serve |
| `recalibration` | 2★ + first automatic serve + relevant formula improvement |
| `lab_automation` | 2★ + `lab_growth_upgrades` |
| `rest_extended` | 2★ + first completed staff rest |
| `kitchen_specialty` | 3★ |
| `rest_large` | 3★ + `rest_extended` |
| `kitchen_orchestration` | 4★ |

Technical item/tier features such as `content.sauce_ramp` and room-expansion tiers are non-announcing and are persisted in the same monotonic unlock list.

`live_training` is not an active first-PR feature. The target progression table from the product contract is switched on only together with the actual live lesson and standard formula systems.

## Office routes

Stable routes are `office.cafe`, `office.shop`, `office.development`, `office.staff`, `office.training`, nested statistics/laboratory/rest/library/assignments/groups, plus the auxiliary `office.settings` button. The root order never changes: Cafe → Shop → Development → Staff → Training. Closed deep links walk to the nearest visible parent, ending at `office.cafe`.

Legacy aliases remain supported while the UI scene still uses old page IDs: `overview`, `stations`, `star`, `stats`, `laboratory`, `lounge`, `videos`, `groups`, `settings`.

## Action validation

Commands do not trust UI previews. Host-side domain entry points re-run `FeatureAccess` immediately before mutation. Purchase entry points cover single items, bundles and multi-station batches; training/group commands and masterclass operations are similarly guarded in `CafeService`.

Reason priority is represented by stable codes from `AccessReasons`, including `FEATURE_LOCKED`, `HOST_ONLY`, `TARGET_MISSING`, `ALREADY_OWNED`, `DELIVERY_PENDING`, busy/capacity/equipment reasons and `INSUFFICIENT_FUNDS`. A guest can browse introduced goods but receives `HOST_ONLY` on purchase.

## Save, migration and co-op

`CafeProgression.snapshot()` persists:

```gdscript
feature_progress = {
    "schema_version": 1,
    "cafe_id": "...",
    "revision": 0,
    "milestones": {},
    "unlocked_features": [],
    "announced_features": []
}
```

`world_epoch` is separate from `feature_progress` and is regenerated for every created/loaded world. The existing reliable cafe snapshot transports both to co-op clients. A client accepts a newer revision inside the same `(world_epoch, cafe_id)` or the first snapshot of a changed epoch/cafe, so loading an older save of the same cafe remains valid.

Old saves are migrated from authoritative domain evidence: served dishes, lab state/formula, workers, production stations, masterclasses/method sources, television, upgrades, lounge state, deliveries and existing late-kitchen expansions. Where history cannot prove a milestone, migration restores only the compatibility unlock required to keep existing content usable.

Local tutorial/"seen" state is stored in `user://ui_progress.cfg` keyed by `cafe_id`; it does not change cafe permissions or another player's UI state.

## Early journey integration

The 1★ path is intentionally ordered as: create/grow first clone → prepare first production table and assign worker → record a compatible masterclass → order/install television → complete video training → first automatic serve. This preserves the current lab-before-1★ route while avoiding a masterclass prompt before a clone has somewhere to work.
