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
- BBHide fixes (all four)
- Translation patch (spawn point name keys)

When a new patch is added to the main repo, check its scope. If it has no Bandits
dependency, apply it here too.

---

## Open Issues

None.
