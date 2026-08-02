# 宠物战斗陪伴与视觉协议

## Server event contract

`perform_pet_pve_assist(player, target)` remains the only combat authority. On a
valid trigger, assign an immutable `/tmp/wanling/recent_assist` mapping with:

- `id`: physical character ID + event time + session sequence + random suffix
- `event_at`: server epoch seconds
- `pet_id`, `species`, `name`, `icon`, `family`, `role`, `skill`
- `type`: `damage`, `heal`, or `mofa`
- `amount`: actual applied value after caps, full-resource checks, and debuffs
- `target_name`, `cooldown`, `ready_at`

Generate an event even when actual amount is zero because HP/MP is already full,
but never display a fabricated positive value. Do not generate or replace the
event for PVP or any rejected target.

`query_pet_battle_presence(player)` returns `active: 0` for no companion. For an
active companion, return catalog identity, cooldown, remaining seconds,
readiness, and a copied `recent_event` only while it is at most 10 seconds old.
This function must not lock or load the account record.

Expose the result as `player.pet_assist` from `query_player_state()`. The existing
one-second `/api/battle_status` poll carries it; do not add a pet polling loop.

## Vue state machine

Keep these responsibilities separate:

- `battlePet`: normalized current presence and cooldown
- `petAssistEffect`: current short visual burst
- `lastPetAssistEventId`: immediate polling duplicate guard
- `petAssistEventHistory`: bounded cross-character-switch duplicate guard
- `petAssistEffectTimer`: one owned cleanup timer

Always update `battlePet` before event de-duplication. For a new event, record it
in the battle log even if animations are disabled. If effects are enabled, map
role/element to an existing skill animation, show the custom pet burst, add a
damage/heal number only for positive actual amount, and clear it after the
bounded duration.

Clear presence/effect/timers at battle end, pet removal, logout, component
unmount, and character-session invalidation. Preserve the short seen-event map
across sibling character selection so switching away and back cannot replay an
old 10-second server event. Clear that history on full logout/unmount and prune
entries older than two minutes when processing new events.

## Visual hierarchy

1. Mini dock: compact pet avatar, name, skill, readiness text, progress line.
2. Collapsed dock: small pet badge remains visible beside the combat icon.
3. Full battle view: larger companion card inside the player combatant.
4. Trigger burst: pet leap, element-colored comet/glow, skill title, actual
   result, existing skill animation, and battle-log entry.

Keep the layer `pointer-events: none`; it must never block attack, skill, escape,
or dock controls. Reserve enough bottom content space through
`--battle-dock-height`. Hide secondary skill text on very narrow phones rather
than shrinking controls below usable size.

Use element classes only from a fixed mapping (`fire`, `water`, `wood`, `earth`,
`metal`, `lightning`, `wind`, `spirit`, `mystic`) so server strings never become
arbitrary CSS. Vue interpolation must escape names and target text.

## Accessibility and testing

- Use `role="progressbar"` with 0–100 values for cooldown readiness.
- Keep the result available in the battle log and textual MUD output.
- Honor the effect toggle and `prefers-reduced-motion`.
- Format combat values with `formatCompactNumber()`.
- Test the Vue template compile, normal trigger, exact cooldown percentage,
  zero-value message, repeated poll, reset plus repeated event, missing enemy,
  battle end, and generated CSS/template contracts.
- Run the real Pike test to prove the event contains the applied amount, PVP
  cannot replace it, and full HP creates only a zero-value companionship event.
