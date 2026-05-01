# CLAUDE.md — MrTheSteve_Patches_NoBandits

This repo is a parallel version of MrTheSteve_Patches for runs without the Bandits mod.
It contains all patches except those that depend on Bandits or Bandits Week One.

**For full context, rules, gotchas, decisions log, and tooling notes, read:**
`C:\Users\steve\dev\MrTheSteve_Patches\CLAUDE.md`

The notes below cover only what differs from the main repo.

---

## What's Excluded

Everything in the main repo's patch inventory that is Bandits-specific:

- `Bandits_Patch.lua` and `Bandits_Server_Patch.lua` (all Bandits fixes)
- Clan config changes (Assault AI removal)

---

## What's Included

All non-Bandits patches mirror the main repo exactly:

- BBHide (Workshop 3705453209) — all four fixes
- AZAS Frequency Conflict Patch (Workshop 3655362047 / 3656359964)
- Equipment UI (Workshop 2950902979)
- WarThunder Vehicle Library (Workshop 3399660368) — HeliSoundUpdate, MainHeliCore, MainPanerCore
- Lethal Stealth (Workshop 3531611692) — LTSProneGeneralHandler, LTSProneTimedAction, LTSPlayerProneStates, LTSCustomBuffs
- MoneyFromCreditCard (Workshop 3428650803)
- True MooZic (Workshop 3632610172) — TCTickCheckMusic
- True Music Radio (Workshop 3631572046)
- Lifestyle: Hobbies (Workshop 3403870858) — TVRADIOTraits_ISRadioInteractions
- Aquatsar Yacht Club (Workshop 3646414716) — WaterNWindPhysics
- Translation patch (spawn point name keys)

## When a new patch is added to the main repo, check its scope. If it has no Bandits dependency, apply it here too.

## Open Issues

- **TCTickCheckMusic.lua** (True MooZic, 3632610172): Our version predates an upstream rework that switched vehicle audio from `vehicle:getEmitter()` to free world emitters anchored to vehicle position. Our nil guards and indexed iteration are equivalent to upstream's `TCMusic_ForEachVehicle`. Not a crash risk but could cause vehicle radio audio issues. Re-sync if vehicle radio audio misbehaves.
