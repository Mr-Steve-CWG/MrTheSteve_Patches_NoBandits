# MrTheSteve Patches (No Bandits)

A collection of small fixes, translation patches, and tweaks for Project Zomboid Build 42.

**This is the NoBandits track.** It is incompatible with Bandits2, BanditsWeekOne, and Bandits Improved AI. Use MrTheSteve_Patches instead for runs with those mods active.

## Two-Track Maintenance Convention

This project is maintained as two parallel mods:

- **MrTheSteve_Patches** — for runs with Bandits + Week One active
- **MrTheSteve_Patches_NoBandits** (this repo) — for runs without Bandits/BWO

**Rules:**
- Patches for non-Bandits mods go into **both** repos
- Patches for Bandits/BWO go into MrTheSteve_Patches only
- Never add Bandits/BWO patches to this repo

When adding a new patch, update both repos if it is mod-agnostic, or MrTheSteve_Patches only if it is Bandits/BWO-specific.

## Contents

- **MFCC_Patch** — Nil-guards for MoneyFromCreditCard (Workshop: 3428650803)
- **TrueSmoking_Patch** — Fix for True Smoking (Workshop: 3423984426)
- **TrueMusicRadio_Patch** — Fix for True Music Radio (Workshop: 3631572046)
- **TVRADIOTraits patch** — Nil-guard fix for Lifestyle radio interactions
- **LTS Prone files** — Patches and overrides for LTS Prone mod
- **BBHide files** — Patches for BB Hide mod
- **Translation files** — Spawn point display name fixes and vanilla string corrections
- **NoHolesExtended** — Script tweaks

## Notes

All third-party mod fixes live here rather than in Workshop files, so patches survive upstream mod updates.
