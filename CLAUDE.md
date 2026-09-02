# [CLAUDE.md](http://CLAUDE.md) — MrTheSteve_Patches Session Context

Read this file at the start of every session. Update it at the end of any session that changes the patch inventory, resolves open issues, or establishes new decisions.

---

## This is the active repo (as of 2026-08-31)

`MrTheSteve_Patches` (the Bandits-inclusive repo) is now **unmaintained** — Steve isn't running Bandits, BanditsWeekOne, or BanditsImprovedAI, and has no plans to unless those mods get a substantial rewrite. All new patches, `loadModAfter` edits, and git operations happen here only. Don't mirror changes into the Bandits repo by default; check in with Steve first if that ever needs to change.

## NoBandits repo also shelved as of 2026-09-01 (temporary — not retired)

Steve is playing this modlist **patch-free** for now. Not a permanent retirement like the Bandits repo above — this is a pause while an unresolved crash gets sorted out, and the plan is to rebuild the active set slowly, one confirmed-necessary patch at a time, rather than redeploy everything at once.

**Why:** with the full patch mod active, every load attempt (existing save or new game) crashes to desktop immediately after clicking Start. Confirmed via `hs_err_pid*.log`: a native (off-heap) JVM memory allocation failure, not a Lua/script error — Java heap itself was nowhere near its `-Xmx` ceiling when it died. Without the patch mod active, the game loads and runs fine on the same save and same workshop mod list.

**Ruled out this session:**
- The `Duplicate Prop2` recipe-load crash from redefining GoM's `OpenBoxOf50Bullets` — real bug, fixed (new `OpenBoxOf50Bullets_556` recipe + `ammobox50_556` tag, scoped only to 5.56, doesn't touch GoM's native recipes or other calibers). This fix got the game *past* Start into the OOM crash, so it's confirmed working, just insufficient on its own.
- `GoM_556x45_Box50_Restore.txt` as the OOM cause — pulled from the active folder and tested in isolation; same OOM crash still happened without it.
- Recent `mod.info`/`loadModAfter` edits and the various retired-patch archive moves from the 08-31 session — none of these add native memory pressure, and the crash reproduces with or without them.

**Not yet isolated:** which of the remaining active Lua patches (or their cumulative weight) is driving the native allocation failure. Next cheapest bisection step, if picked back up: disable `OnSpawnVehicleAdditionalFeatures.lua` (More Car Features) and `zombieThump.lua`/`serverCommands.lua` (Z-Proof) first, since those do the heaviest work at world-init/spawn — but this hasn't been tried yet.

**Current plan:** play vanilla + workshop mods only, no private patches. When a specific bug is hit in play, diagnose and write a single targeted patch for it (following the usual root-cause workflow), rather than re-enabling the whole inventory. Re-introduce the confirmed crash-preventers first if their underlying bugs resurface — **More Car Features** (`OnSpawnVehicleAdditionalFeatures.lua`, prevents a world-load NPE crash), **Z-Proof Doors & Windows** (`zombieThump.lua` + `serverCommands.lua`, three nil-crash fixes), and **RVInterior_SwitchSeat_Patch** (vehicle interior transition crash + stuck-player loop) are the highest-value patches in the inventory below if things start breaking again.

---

## Project Purpose

Private patch mod for Project Zomboid Build 42. Goal: fix demonstrably broken behavior in workshop mods without altering mod author intent. If something looks like a design choice rather than a bug, flag it and confirm with Steve before touching it.

Two parallel repos:

- `MrTheSteve_Patches` — full patch set including Bandits-specific fixes. **Unmaintained as of 2026-08-31**, see note above.
- `MrTheSteve_Patches_NoBandits` — identical minus anything that depends on the Bandits mod. **This is the actively maintained repo.**

Unless a patch is explicitly Bandits-specific, it goes in both repos.

---

## Key Paths

PurposePathWorkshop content root`C:\Steam\steamapps\workshop\content\108600\`Bandits mod`...\3268487204\mods\Bandits\`Bandits Week One`...\3403180543\mods\BanditsWeekOne\`Local mods dir`C:\Users\steve\Zomboid\mods\`Main patch repo`C:\Users\steve\dev\MrTheSteve_Patches`NoBandits repo`C:\Users\steve\dev\MrTheSteve_Patches_NoBandits`Bandits AI behaviors`...\3268487204\mods\Bandits\42.16\media\lua\shared\ZombiePrograms\`Bandits clan configs`...\3268487204\mods\Bandits\common\bandits\clans.txt`Git remote`https://github.com/Mr-Steve-CWG/MrTheSteve_Patches.git`PZ JVM config`C:\Steam\steamapps\common\ProjectZomboid\ProjectZomboid64.json`

Repos use symlinks into the local mods directory — changes are live immediately. Patch file structure mirrors PZ layout: `42\media\lua\client\`, `shared\`, `server\`

**Note (2026-08-02):** The NoBandits repo's link into `C:\Users\steve\Zomboid\mods\` was recreated as a directory junction (`mklink /J`), not a true symlink (`mklink /D`) — Desktop Commander's shell session didn't have the elevated privilege `/D` needs. Functionally equivalent for PZ's mod loader and for live-editing purposes. If a true symlink is ever needed, run `mklink /D` from an elevated prompt instead.

---

## Session Log — 2026-08-02: 42.20 fresh solo restart, NoBandits redeploy

Steve moved to a fresh solo playthrough on PZ 42.20 (full stable, launched 2026-07-29). No saves carried over, mod list has changed significantly, and Bandits/BanditsWeekOne are fully unsubscribed (workshop folders no longer exist on disk). Confirmed this is genuinely a NoBandits situation, not just a load-order gap.

Rather than trust the stale `mod_audit.json` (last regenerated June 19, pre-restart), pulled the actual active mod list straight from the live save's `mods.txt` (`Saves\Apocalypse\2026-08-02_17-22-57\mods.txt`) and cross-referenced every patch in this repo's inventory against it plus the current workshop folders on disk. Results:

- **Retired and archived to `_archive\`** (mod fully unsubscribed, workshop folder gone): BBHide, AZAS Frequency Conflict, Lethal Stealth, MoneyFromCreditCard, True Music Radio, Project Summer Car. Moved rather than deleted per Steve's preference — restorable if any of these mods come back. Corresponding stale `loadModAfter` entries stripped from `mod.info`.
- **Still subscribed, currently inactive** (not retired, just not in the current save's mod list): Lifestyle: Hobbies, Neat Rocco (also capped `versionMax=42.19` in its own `mod.info` — likely why it's not running on 42.20).
- **Confirmed still active and relevant**: Military Tool Kit, Z-Proof (Doors & Windows), Zombies Drop Ammo Boxes, True MooZic, Guns of Marz + SWMG framework, AnruisiTown x GoM Compatibility.
- Repo relinked into `C:\Users\steve\Zomboid\mods\` (see junction note above).

**Loose ends spotted, not part of this session's scope, flagging for Steve:**
- `client\AuthenticZ_Zones.lua` isn't in the Active Patch Inventory above despite being in the repo. Content is mostly custom `getWorld():registerZone(...)` calls for immersion (movie-referenced zombie zone names across the map) plus an `RWMVolume:verifyItem` radio-headphone check and a bag-color-transfer craft helper — none of it documented as a fix for a specific mod bug. Steve mentioned switching from full Authentic Z to the Backpacks+-only variant; the headphone check references `AuthenticZClothing.Authentic_Headphones`/`_Headphones2`, which live under the full mod's item module, not `AuthenticZBackpacksPlus`. With only Backpacks+ active, that check is now inert (harmless, just won't match) rather than broken. Not touched — needs Steve's call on whether to keep, prune, or fold into documented inventory.
- `client\Chainsaw\ChainsawMain.lua` and `shared\Chainsaw\ChainsawAPI.lua` also aren't in the inventory. Not reviewed this session.
- `client\LSEffects\LSPerTick.lua` also undocumented. Not reviewed this session.

---

## Core Rules

**Never edit workshop files.** They get overwritten on every update. All fixes go into the patch repo.

**Patching approach:**

- Prefer monkey patching (wrapping functions, re-registering event handlers) when the target is a named global or event handler
- When the target is a local function unreachable from outside, copy the whole file into the patch repo and make surgical edits
- Always copy from clean workshop source first, then apply edits — never rewrite from scratch
- Always diff the patch file against workshop source before committing to confirm only intended changes are present

**Before fixing anything:**

- Read all relevant Lua files before drawing conclusions
- Double-check every suspected bug by re-reading the code before reporting it
- Confirm each bug is real — no false alarms, no speculative fixes

**Translation fix workflow:**

Before appending keys to any existing `Translate\EN\*.json` patch file, always scan that file first for PT/non-English contamination:

```powershell
Select-String -Path "<file>" -Pattern "Munição|Esteira|Blindagem|Assento|Antena|Galão|Pneu|Molde|Ferramenta|Chapa|Sapata|NÃO"
```

Then scan for duplicate keys before and after any edits:

```powershell
Select-String -Path "<file>" -Pattern '"Base\.' | ForEach-Object { ($_ -split '"')[1] } | Group-Object | Where-Object { $_.Count -gt 1 }
```

A duplicate key in any EN JSON file is a hard crash at menu load — the translator throws a JSONException and the UI never initializes. This bit us twice with the Military Tool Kit PT leak (April and May 2026): the April fix appended correct English keys without first removing the existing PT duplicates already in the file.

---

## Git Workflow

Use PowerShell for all git commands (cmd mangles commit messages).

```powershell
cd 'C:\Users\steve\dev\MrTheSteve_Patches'
git add <specific files only>
git commit -m 'Short descriptive message'
git push
```

Stage only the specific files that changed. Commit after every meaningful change. Push after every commit. Git operations can be chained with semicolons in one call.

---

## Active Patch Inventory

### Bandits (Workshop ID 3268487204)

Files: `42\media\lua\shared\Bandits_Patch.lua`, `42\media\lua\server\Bandits_Server_Patch.lua`, `42\media\lua\client\BanditUpdate_Patch.lua`
Scope: Main repo only (Bandits-specific).

FixWhat it fixesStatusFix #1`spawnPoint` typo (should be `spawnPoints`) in `Spawner.Individual` — nil index crashActiveFix #3`ApplyVisuals` throttle — performance fix, our addition, not an upstream bugActiveFix #4`ManageCollisions` — `getBarricadeOnOppositeSquare` return unguarded, nil coord access — door **and** window pathsActiveFix #5`ans ==` typo in `BanditUpdate.lua` (should be `asn ==`)ActiveFix (ManageEndurance)`getSpecificPlayer(0)` returns nil during early singleplayer startup; calling `:getX()` on nil crashes. Added nil guard with early return `{}`.ActiveFix #2nil return from `generateSpawnPointUniform`Retired — fixed upstream (42.16.x)Fix #6`BanditServerCommands` `sendObjectChange('state')` B42 API crashRetired — fixed upstreamFix #7`BanditBasePlacements` window patch / `BanditServerSpawner` sendObjectChangeRetired — fixed upstream

Fixes #4, #5, and ManageEndurance implemented as a whole-file copy `BanditUpdate_Patch.lua` synced against 42.18 upstream. Bandits_Patch.lua handles monkey patches only (Fixes #1, #3).

Fixes #2, #6, #7 retired at commit `05dd628`.

**Zombie target spotting / muzzle flash (Java-level bugs):** The Bandits author released a Java fix mod (separate Steam item) on 2026-05-01 covering two issues that cannot be fixed from Lua: zombies incorrectly detecting player location during bandit combat, and bandit guns not emitting muzzle flash. These were known unpatched issues. Steve is subscribed but not currently running Bandits. When Bandits is re-enabled, install the Java fix mod per its readme instead of attempting a Lua workaround.

**Clan config change (gameplay preference, not a bug fix)**:All Bandits clan configs modified to remove Assault AI, switched to Wanderer where applicable. Assault AI units with Recon/Tracker expertise have dramatically extended hearing ranges (13 and 55 tiles vs default 5), producing aggressive sweeper behavior Steve wanted eliminated.

---

### Bandits Week One (Workshop ID 3403180543)

File: `42\media\sound\Broadcasts\BWORadio\OutputFilesoundtable.lua`
Scope: Main repo only (Bandits-specific).

FixWhat it fixesFix #1`OutputFilesoundtable.lua` saved as UTF-16 LE — Kahlua lexer crashes on the BOM bytes before any valid Lua is parsed; re-encoded to UTF-8, content identical

---

### BBHide (Workshop ID 3705453209)

~~Files: `42\media\lua\client\BBHide\`, `42\media\lua\shared\BBHide\`~~
Scope: Both repos.
Status: **Retired 2026-08-02.** Mod fully unsubscribed (workshop folder no longer exists on disk) as of the 42.20 fresh solo restart. Moved to `_archive\BBHide_client\` and `_archive\BBHide_shared\` in this repo rather than deleted, per Steve's call — restorable if the mod comes back.

---

### AZAS Frequency Conflict Patch (Workshop ID 3655362047 / 3656359964)

~~File: `42\media\lua\shared\AZAS_FrequencyConflict_Patch.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-02.** Mod fully unsubscribed as of the 42.20 fresh solo restart. Moved to `_archive\AZAS_FrequencyConflict_Patch.lua`. `loadModAfter=AZASFrequencyIndex_RefactorTest` stripped from `mod.info`.

---

### BanditsImprovedAI (Workshop ID 3630494926)

File: `42\media\lua\shared\BanditsImprovedAI_Patch.lua`Scope: Main repo only (Bandits-dependent).

FixWhat it fixesFix #1`BanditCompatibility.InstanceItem` re-wrapped post-load to strip Base.Pistol fallback — addon hook causes any missing item to become a pistol in bandit inventories and death loot

Accepted risk documented in file: raw global `instanceItem` is also hooked by the addon; not patched due to fragile wrapper chain risk. `LockSurrenderedAI` full-zombie-list iteration on every `OnTick` frame also noted but not patchable without removing a local handler reference.

---

### Equipment UI (Workshop ID 2950902979)

~~File: `42\media\lua\client\EquipmentUI_Patch.lua`~~
Scope: Both repos.
Status: **Retired 2026-05-09.** Mod dropped from modlist. Patch deleted from both repos.

---

### WarThunder Vehicle Library / UH-1 Huey (Workshop IDs 3399660368 / Huey mods)

~~Files: `42\media\lua\client\HeliSoundUpdate.lua`, `42\media\lua\client\MainHeliCore.lua`, `42\media\lua\client\MainPanerCore.lua`~~
Scope: Both repos.
Status: **Retired 2026-05-09.** Mods dropped from modlist; not yet compatible with 42.17. Patch files deleted from both repos. Note: the `BetterFPS` function patched in Fix #2 was embedded inside `MainHeliCore.lua` -- there was never a separate Better FPS patch file.

---

### Lethal Stealth (Workshop ID 3531611692)

~~Files: `42\media\lua\client\LTSProneGeneralHandler.lua`, `42\media\lua\shared\LTSProneTimedAction.lua`, `42\media\lua\shared\LTSPlayerProneStates.lua`, `42\media\lua\shared\LTSBuffs\LTSCustomBuffs.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-02.** Mod fully unsubscribed as of the 42.20 fresh solo restart. Moved to `_archive\LethalStealth\`.

---

### MoneyFromCreditCard (Workshop ID 3428650803)

~~File: `42\media\lua\shared\MFCC_Patch.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-02.** Mod fully unsubscribed as of the 42.20 fresh solo restart. Moved to `_archive\MFCC_Patch.lua`. `loadModAfter=MoneyFromCreditCards` stripped from `mod.info`.

---

### True MooZic (Workshop ID 3632610172)

~~Files: `42\media\lua\client\TCTickCheckMusic.lua`, `42\media\lua\client\Context\WorldObject\worldContextJukeboxLSBridge.lua`~~
Scope: Both repos.
Status: **Fully retired 2026-08-31.** `TCTickCheckMusic.lua` was already retired 2026-04-30 (upstream fixed the vehicle audio iterator). `worldContextJukeboxLSBridge.lua` was found, on re-check, to already be entirely wrapped in a `--[[ ... JUKEBOX LIFESTYLES INTEGRATION DISABLED --]]` block comment — someone had already fully disabled it at some undocumented point (not just the BOM-strip Fix #2 this section previously described; no session record of when or why the full disable happened). Its target file no longer exists anywhere in current source either — the mod's jukebox code was restructured into `TMJukeboxTick.lua`, `TMJukeboxContext.lua`, `TMJukeboxDefs.lua`, `TMJukeboxServer.lua`, `TMJukeboxServerCommands.lua`, `TMJukeboxWindow.lua`. Moved to `_archive\worldContextJukeboxLSBridge.lua`. `loadModAfter=TrueMoozic` stripped from `mod.info` — True MooZic has zero active patches remaining.

---

### True Music Radio (Workshop ID 3631572046)

~~File: `42\media\lua\client\TrueMusicRadio_Patch.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-02.** Mod fully unsubscribed as of the 42.20 fresh solo restart. Moved to `_archive\TrueMusicRadio_Patch.lua`. `loadModAfter=TrueMusicRadio42` stripped from `mod.info`.

---

### Lifestyle: Hobbies (Workshop ID 3403870858)

File: `42\media\lua\client\RadioCom\TVRADIOTraits_ISRadioInteractions.lua`Scope: Both repos. Method: Whole-file copy.

FixWhat it fixesFix #1`_interactCodes:len()` called before nil check — Java null radio objects pass `== nil` but crash on method calls

**Status note (2026-08-31):** Re-added to the active mod list. Re-verified against current source: upstream added an `_interactCodes == nil` guard since our patch was written, but that only catches genuine Lua `nil` — the original diagnosis (Java-null radio objects that pass `== nil` but crash on method calls) is a different failure mode their guard doesn't cover. Our `tostring()`-based check still does the real work. `loadModAfter=LifestyleHobbies` unchanged.

---

### Aquatsar Yacht Club (Workshop ID 3646414716)

~~File: `42\media\lua\client\WaterNWindPhysics.lua`~~
Scope: Both repos.
Status: **Retired 2026-04-30.** Apr 9 upstream update (v1.30) fixed the collision crash
that our patch addressed, using an iterator pattern. Our fix is redundant; removed per
standing rule on upstream-fixed patches.

---

### Military Tool Kit (Workshop ID 2705406713)

File: `42\media\lua\shared\Translate\EN\ItemName.json`
Scope: Both repos.

FixWhat it fixes
Fix #1`42.17\media\lua\Shared\Translate\EN\ItemName_PTBR.txt` declares table `ItemName_EN = {}` instead of `ItemName_PTBR = {}`. PZ loads all `.txt` files in the `EN\` folder for the English locale; files sort alphabetically so `ItemName_PTBR.txt` loads after `ItemName_EN.txt` and overwrites every item name with Portuguese. Fixed by appending all affected `Base.*` item names to the patch repo's `ItemName.json`, which loads after the workshop mod and restores the English strings.

**Known unresolved:** Multiple Lua files under `42\media\lua\Client\` contain Portuguese comments with non-ASCII characters that cause a non-fatal Kahlua lexer error on load (`ErrorMagnifier: ArrayIndexOutOfBoundsException: Index 65022`). Whole-file copies with ASCII substitutions are ineffective because PZ loads workshop originals regardless. Bug reported to mod author. No action until upstream fix.

**Re-verified 2026-08-31:** The mod now ships a dedicated `42.20\` version folder with a single, clean `ItemName.json` — no `_PTBR` counterpart file, so the original alphabetical-collision leak can't happen anymore for players on 42.20. Our added `Base.*` entries are now redundant but harmless: JSON translations merge per-key across all active mods, so ours just re-asserts the same correct string rather than conflicting with anything. Not removed since there's no cost to leaving them.

**Scope note:** this shared `ItemName.json` file also carries entries for other mods entirely unrelated to Military Tool Kit (e.g. `AuthenticZClothing.*`), from some earlier session not documented under this heading. That's expected and safe given how JSON translation merging works (any mod can contribute keys to any `ItemName.json`-named file and they all merge), but worth knowing this file's real scope is broader than "Military Tool Kit fix" — it's become a general English-translation-restoration file.

---

### Translation Patch

File: `42\media\lua\shared\SpawnPoints_Translation_Patch.lua`Scope: Both repos.

Adds missing EN spawn point name translation keys for map mods that define custom spawn regions without providing translation entries. Covers SerellanCustomSpawn, SafeharborGarrison, SafeWayHamlet, DWAP locations, and others identified during audit.

Status: Active, ongoing. Additional missing keys are found in-game from time to time and added as targeted fixes when reported.

---

### Z-Proof Doors & Windows (Workshop ID 3684834906)

Files: `42\media\lua\client\zombieThump.lua`, `42\media\lua\server\ZPWD\serverCommands.lua`
Scope: Both repos. Method: Whole-file copies.

| Fix | File | What it fixes |
|-----|------|---------------|
| Fix #1 | zombieThump.lua | `doesWindowBreak` called `window:getBarricadeForCharacter()` without guarding the result of `getWindow()` for nil. Window may be smashed or removed after phantom was created; door branch already had a nil check but window branch did not. |
| Fix #2 | serverCommands.lua | `addPhantom` called `square:getObjects()` without guarding `getGridSquare()` for nil. At vehicle speed the square can unload between the client sending the command and the server processing it. |
| Fix #3 | zombieThump.lua | `setSandboxVals` read all six `SandboxVars.CloudyZPWD.*` fields without fallback defaults. Nil flows into `ZombRand()` numeric comparisons in `didZombieGetBored` and throws on saves where sandbox options were never explicitly configured. |

Bug report posted to Steam workshop page.

---

### Project Summer Car (Workshop ID 3564950449)

~~File: `42\media\lua\server\PSC_Patch.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-02.** Mod fully unsubscribed as of the 42.20 fresh solo restart. Moved to `_archive\PSC_Patch.lua`.

| Fix | What it fixes |
|-----|---------------|
| Fix #1 | `Vehicles.CheckEngine.Engine` hard-sets engine condition to 0 for any vehicle whose PSC engine container has not been initialised yet (no `EnginePartInitMarker`). Requires 5 `EngineCritical`-tagged parts; finding fewer than 5 sets `minCondition = 0` and returns `false` (stall). Wrapper bails to vanilla `part:getCondition() > 0` if marker is absent. |
| Fix #2 | `Vehicles.Update.Battery` computes `GetPartCondition("EngineAlternator")` = 0 on uninitialised vehicles, so `alternatorAmps = 0` and the battery drains continuously with nothing to offset it. Wrapper skips the entire function (no-op) until the marker is present. |
| Fix #3 | `isEngineInitialised` originally called `container:containsTag("EnginePartInitMarker")` with a raw string. `ItemContainer:containsTag()` is a Java method that requires an `ItemTag` object, not a string — threw `expected argument of type ItemTag, got String`. Fixed to use `ProjectSummerCar_Tags.EnginePartInitMarker` (the registered `ItemTag` object from PSC's `registries.lua`). Added nil guard on `ProjectSummerCar_Tags` itself as a secondary safety net. |

Both conditions resolve permanently once the player enters the vehicle for the first time (PSC's `EngineSetupEnterVehicle` hook populates the container and stamps the marker). Safe without PSC: wrappers check that `Vehicles.CheckEngine.Engine` and `Vehicles.Update.Battery` are non-nil before installing; if PSC is not loaded the slots are never set and the wrappers are never registered.

---

### Zombies Drop Ammo Boxes (Workshop ID 3700723031)

~~File: `42\media\lua\server\AmmoLootDropBox.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-31.** File on disk had drifted far beyond the documented Fix #1 (a one-line `tostring()` guard) into a 302-line reimplementation — dynamic item scanner, hardcoded fallback item list, custom drop-rate formula, and a `pcall`-based `safe()` wrapper that violates the house no-`pcall` rule. No session record of when/why the rewrite happened. Also discovered the file's relative path never matched the real mod's path (missing `Items/` subfolder — real file is at `server/Items/AmmoLootDropBox.Lua`), so this override had never actually taken effect regardless of content. Steve confirmed he hasn't relied on it and elected to drop it rather than validate or rewrite. Moved to `_archive\AmmoLootDropBox.lua`. `loadModAfter=AmmoLootDropBox` stripped from `mod.info`.

---

### More Car Features + Spawn Zones Expansion (Workshop ID 3520758551)

File: `42\media\lua\server\Vehicles\OnSpawnVehicleAdditionalFeatures.lua`
Scope: Both repos. Method: Whole-file copy.

| Fix | What it fixes |
|-----|---------------|
| Fix #1 | `fillEventVehiclesTable` (on `OnLoadedMapZones`) buckets every loaded vehicle script into `ReplacementVehicles[mechanicType]`, where `mechanicType` is read raw and unvalidated from each vehicle script's own file (`Integer.parseInt`, no bounds check). `ReplacementVehicles` only defines keys `"0"`-`"3"` plus named zone keys. Some active vehicle script declares a `mechanicType` outside that range, so `table.insert` on a nil table throws an NPE and crashes world load (`IsoWorld.init`). Guarded with a nil check before insert, plus a `print("MCF Warning: ...")` naming the offending vehicle script and its mechanicType so the actual culprit mod can be identified and reported, rather than silently dropping it. |

**Root-cause note:** initial fix (`WayMoreCars` mod ID) was missing from `loadModAfter` in both repos, so this override was silently losing the load-order race back to the original workshop file — same crash signature persisted post-patch until this was caught via a missing `MCF Warning:` print in the log combined with a `mod "WayMoreCars" overrides ...` log line showing the workshop copy winning. Confirmed via `console.txt` before trusting the fix.

---

### Guns of Marz (Workshop ID 3722134990)

File: `42\media\lua\client\GoM_VanillaConverter_Patch.lua`
Scope: Both repos. Soft dependency — only engages when `GunsOfMarz` is in the active mod list.

| Fix | What it fixes |
|-----|---------------|
| Fix #1 | Right-click context menu on vanilla weapons, ammo, attachments, and magazines to convert them to GoM equivalents. GoM strips vanilla guns/ammo from loot tables at load time, but runtime injection (airdrops, military mods, zone mods) can still produce them. Client-side `OnFillInventoryObjectContextMenu` hook. Single-option ammo converts directly; multi-option calibers (5.56, .308, 12ga) use a submenu. Gun conversions transfer condition proportionally and produce the appropriate mount; blocked with a chat message if magazine is loaded or attachments are mounted. Random attachment picks (scopes, lasers, lights) resolved at click time. |
| Fix #2 | Gun loop used `goto continue` / `::continue::` (Lua 5.2 syntax) to skip entries where the item object couldn't be found. Kahlua parses `goto` as a variable name and throws a syntax error on load, preventing the entire file from compiling. Replaced with `if vanItem ~= nil then ... end` block. |

**Vanilla item name notes:** 9mm/45/38/357/44 loose rounds use `Bullets9mm` / `Bullets45` etc. prefix (not `9mmBullets`). Shotgun box/carton are `ShotgunShellsBox` / `ShotgunShellsCarton`.

**`loadModAfter` correction (2026-08-31):** `MarzGuns` in `mod.info` was stale — GoM's own `mod.info` lists `MarzGuns` under `incompatible=`, it's the dead legacy ID, not what's active. Replaced with `GunsOfMarz,SWMG` (GoM's real current ID plus its required Gunworks framework dependency, workshop 3722064198). Also added `loadModAfter` entries for `SimpleOverhaulTraitsAndOccupations`, `[J&G] Umbrella Corp Uniform`, `PROJECTRVInterior42`, and `B42FRUsedCarsAnimAlpha` covering the HellDrinx-derived patches below that monkeypatch those mods' own functions — none of these had `loadModAfter` entries previously, so load order relative to those mods was never guaranteed.

**5.56x45 box count (50→20):** confirmed intentional GoM-side rebalance (pulls 5.56 down to match the 20-round standard other rifle calibers already used), not a bug. Steve wants it reverted anyway.

**5.56x45 box/carton/crate 50-round restore (2026-08-31):** `42\media\scripts\GoM_556x45_Box50_Restore.txt` — script-only override (no Lua), two module blocks matching GoM's own structure exactly (`module MarzGuns` for items, `module Base` for the recipe). Restores all 15 item variants (5 each of Box/Carton/Crate × base/HollowPoint/ArmorPiercing/Subsonic/Overpressured) to their pre-nerf weights and `marzguns:ammobox50` tag, and overrides `OpenBoxOf50Bullets` to add the 5.56 bullet-type mappings (that recipe currently only knows 9x19/.45/.38/.357 — carries those 4 forward verbatim plus adds 5 new 5.56 entries, since PZ replaces the whole recipe block rather than merging).

Weights confirmed via the still-installed `GunsOfMarzPreviousVersion` (id `MarzGuns`, workshop 3722134990) for the box (0.383, was `OpenBoxOf50Bullets`/`marzguns:ammobox50` pre-nerf). Carton and crate weights aren't directly attested pre-nerf (old version didn't have a Carton/Crate tier at 50 rounds to compare) — derived from the current build's own internal packing-efficiency ratio, confirmed consistent at both tiers: `carton_weight / (12 × box_weight) = 0.800` and `crate_weight / (4 × carton_weight) = 0.800` hold exactly at the current 20-round weights, so the same 0.800 factor was applied scaling up from the restored box weight: carton = 12 × 0.383 × 0.8 = 3.677, crate = 4 × 3.677 × 0.8 = 11.766.

Script-only overrides merge by `module` + item/recipe name across all active mods, not by matching file path like Lua overrides — this file's own path under `42\media\scripts\` doesn't need to mirror GoM's folder structure, only the module and name have to match. Load order is what decides which definition wins, which is why this depends on `loadModAfter=GunsOfMarz,SWMG` already being correct (see above) — this override would silently lose the same way the MCF fix originally did if that entry were ever removed or reordered.

**Maintenance note:** this is a genuine design reversal, not a bug fix — sits outside the normal root-cause-fix pattern and needs a deliberate re-check (not just a "did it still load" check) on every GoM update, since `OpenBoxOf50Bullets`'s mapper list is a hardcoded snapshot that silently goes stale if GoM adds/renames calibers on that recipe.

---

### Neat Rocco (Workshop ID 3723726293)

~~File: `42\media\lua\client\NeatRocco\NR_CharInfo\NR_CharInfoPanel.lua`~~
Scope: Both repos.
Status: **Retired 2026-08-31, and risky as-was.** Mod is back in the active rotation and got a substantial 42.20 rewrite — new `42.20\` version folder, own mod ID `Neat_Rocco` (note: not `NeatRocco`), a new `require=\NeatUI_Framework` dependency, and its own near-identical width-change gate (`oldW`/`actualW` comparison around `calculateLayout`, same "hosted vanilla sub-panels call setWidth every frame" reasoning as our original fix). Our patch file was a 601-line whole-file copy predating that rewrite (current upstream is 658 lines, restructured around the new NeatUI Framework hooks) — if it had ever won the load-order race, it would have silently rolled back the entire NeatUI Framework integration, not just re-introduced the performance issue. Moved to `_archive\NR_CharInfoPanel.lua`. Mod ID `Neat_Rocco` was never in `loadModAfter`, so no entry to strip.

---

### AnruisiTown x Guns of Marz Compatibility

File: `42\media\lua\server\AnruisiTown_MarzCompat.lua`
Scope: Both repos.

Root cause: Marz's `Distribution.Insert` / `RemoveMany` (in `Gunworks_gang_framework`, workshop ID 3722064198) iterates only one level into each loot table, checking `data.items` directly. AnruisiTown's `SuburbsDistributions` rooms use a nested structure (`room -> container_type -> items`), so Marz never sees them. Zero stripping, zero injection -- all AnruisiTown gun/ammo rooms remained vanilla.

This mod runs on `OnPostDistributionMerge` and handles substitution directly for AnruisiTown's weapon/ammo/attachment rooms. For each vanilla item found, GoM equivalents are inserted at `vanilla_weight * marz_chance`, mirroring Marz's own behaviour. Sandbox flags respected via the same `Enable_<WeaponName>` check Marz uses.

Rooms covered: `GUNxxx`, `A625GUNXXX`, `A625GUNXXX2`, `AM16GUNXXX`, `A12GUNXXX`, `GUNKK`, `armyBarracks`, `dabaokkk`, `SSS`, `qiangxiepeijia`.

Companion patch: `42\media\lua\client\GoM_VanillaConverter_Patch.lua` (documented separately under "Guns of Marz") provides the right-click inventory conversion tool for vanilla items that slip past both this patch and GoM's own load-time stripping (airdrops, runtime injection). The two patches are complementary, not duplicates: this one substitutes at distribution-build time for AnruisiTown specifically; the converter handles anything that still shows up vanilla in a player's hands afterward.

**Known gap, partially resolved 2026-08-02**: The large warehouse on the south edge of the map — `GUNxxx` in `AnruisiTownDistributions.lua`, described in-file as the "ammo warehouse (all calibres, carton format)" — is the room this patch already treats as `ammoOnlySubs()`. Steve confirmed in a prior session that this warehouse's shelves do show GoM ammo/attachments in place of vanilla stock in-game, which matches `GUNxxx` being covered. Still not 100% confirmed that `GUNxxx` is the exact room name for *that specific* warehouse (vs. a different room serving the same shelves) — if anything still looks vanilla there, re-check with `/lua print(getCell():getGridSquare(...):getRoom():getName())` on the ammo floor.

Re-verified 2026-08-02 against current 42.20 source: all ten covered room names still exist unchanged in `AnruisiTownDistributions.lua` (workshop 3659676359). Also re-verified a sample of `MarzGuns.*` item names referenced in both this patch and the vanilla converter (M4A1, DEAGLE, P226, M92FS, M1911, W1887, Picatinny_Rail, 9x19_Bullet/_Box/_Crate) against current GoM 42.16 source (`3722134990\mods\GunsOfMarz\42.16\media\scripts\MarzWeapons\items\`) — all present, unchanged. Both patches should still be structurally sound.

Unrelated note: a separate workshop mod, AnruisiTownGGSCompat (3677782030), also injects loot into AnruisiTown but for "Gael's Gun Store," not Guns of Marz. Steve subscribed to it only to let me inspect it for ideas; it's not going to be used and is not in the active mod list. No overlap with this patch.

---

### HellDrinx-derived fixes (author semi-retiring, carried over 2026-08-02)

Workshop 3667630656 bundles four mods by author Reegold: HellDrinxEssentials, HellDrinxBugFixes, HellDrinxTranslations, and a bonus TACDeltaPatched. The author is semi-retiring and won't be updating any of them further. None of the three core HellDrinx mods are in the current 42.20 active mod list (TACDeltaPatched is active but its `require=HellDrinxEssentials,HellDrinxBugFixes` isn't satisfied -- Steve confirmed it's working anyway; addressing separately, not through this repo).

Reviewed every fix in HellDrinxBugFixes. Skipped anything targeting Bandits/BWO (not applicable, NoBandits), anything targeting mods not in the active list (Storylines), the two dedicated-MP-only diagnostics (HP forensics, phantom vehicle detector -- don't apply to solo play), and the ukr_melee_42 spawn-rate multiplier (Steve confirmed the mod's own 42.20 update already adjusted loot rates with proper sandbox settings, this patch is redundant now).

Before porting each of the following, re-confirmed the underlying bug still exists by reading the *current* version of the target mod/vanilla file on disk -- not just trusting HellDrinx's original writeup:

#### FR_RequirePaths_Patch.lua (client)
Patches Filibuster Rhymes' Used Cars (Workshop 3683878228, `B42FRUsedCarsAnimAlpha`). Confirmed all four broken require() paths are still wrong in the current mod source (verified against actual vanilla file locations): `Vehicle/ISVehiclePartMenu`, `ISUI/ISVehicleMechanics`, `Vehicles/ISUI/ISVehicleTrailerUtils`, `ISUnlockVehicleDoor`. Re-applies FR's own patches manually on `OnGameBoot` since the require() failures silently skip them at load time.

#### SOTO_TransferValue_Patch.lua (client)
Patches Simple Overhaul: Traits and Occupations (Workshop 2840805724). Confirmed `SOTOISInventoryTransferAction.lua` (42.15 folder, currently active version) still does raw arithmetic on `DisorganizedTransferredValue`/`AllThumbsTransferredValue` ModData fields with no init guard. Wraps `perform()`/`update()` to zero-init both fields first.

#### JG_UmbrellaCorp_BodyLocation_Patch.lua (shared) — RETIRED 2026-08-31
~~Patched `[J&G] Umbrella Corp Uniform` (Workshop 3675741487).~~ Confirmed both winter jacket items *previously* declared bare `JacketHat` (no namespace) across every version folder on disk as of 2026-08-02. Re-checked 2026-08-31: the author fixed this properly upstream, switching the item's `BodyLocation` to `base:jackethat` — confirmed `jackethat` is a real, pre-existing vanilla body location (used by `Jacket_Padded`, hooded ponchos, etc. in `generated\items\clothing.txt`), so this now resolves correctly without any patch. Our old fix registered an unrelated `JG:JacketHat` location that nothing references anymore — inert, not risky, but pointless. Moved to `_archive\JG_UmbrellaCorp_BodyLocation_Patch.lua`. `loadModAfter=[J&G] Umbrella Corp Uniform` stripped from `mod.info`.

#### ISWearClothing_NilItem_Patch.lua (shared)
Patches vanilla `ISWearClothing.lua`. Confirmed current 42.20 vanilla source still calls `self:isAlreadyEquipped(self.item)` right after a nil-capable inventory re-fetch, with no guard inside `isAlreadyEquipped` before `self.item:hasTag(...)`. Race is triggered by mods that chain-patch `ISInventoryTransferAction:perform` -- SOTO and ETW both do, and are both active. Adds the nil guard.

#### MapSpawnSelectScroll_Patch.lua (client)
Patches vanilla `MapSpawnSelect` (character creation map/spawn picker). Not mod-specific -- relevant purely because of how many map mods are installed here. Fixes the listbox never enabling scroll because height and scrollHeight end up equal.

#### RVInterior_SwitchSeat_Patch.lua (client)
Patches PROJECT RV Interior (Workshop 3543229299) and vanilla `ISVehicleDashboard`. Confirmed current vanilla `ISVehicleDashboard.lua` still calls `vehicle:isDriver(character)` with no nil check right after `getVehicle()` -- crash during the interior/vehicle transition. Also confirmed current `RVClientSP.lua`'s `ReturnPlayerToSeat` still searches only a 1-tile radius with no attempt cap, causing an infinite retry loop and a stuck player on large RVs. Fix widens the search to radius 4, adds a 300-tick timeout, and verifies the found vehicle is a registered RV type. Note: the original HellDrinx fix also covered Project Summer Car's dashboard replacer for the same crash; omitted here since PSC's patch is retired -- re-add if PSC ever comes back.

**Re-verified 2026-08-31:** both bugs still unchanged in current source — the mod's Aug 25 update didn't touch either.

**Archived, not deployed:** `_archive\LifestyleHobbies_pending42.20\` holds `HD_Fix_LFH_ToiletMenu.lua` and `HD_Fix_Lifestyle_NilModData.lua`, both targeting Lifestyle: Hobbies (3403870858). Written when that mod wasn't yet updated for 42.20 — **it now is, and is back in the active mod list as of 2026-08-31** (see the Lifestyle: Hobbies entry above). Not re-checked against current Lifestyle source this session; flagging for a follow-up pass to confirm whether these two fixes are still needed, already fixed upstream, or safe to leave archived. `HD_Fix_Lifestyle_NilModData.lua` uses `pcall` in one spot -- flagged in-file as needing replacement with explicit guards before ever actually deploying it, per house rule.

---

- `goto` / `::label::` are Lua 5.2 syntax -- Kahlua (PZ's VM) does not support them. The parser treats `goto` as a variable name and throws `'=' expected near 'continue'`. Replace with `if condition then ... end` blocks.
- `sendObjectChange('state')` crashes in B42 — use `IsoObjectChange.STATE`
- Java collections use `:size()` / `:get(i)` with 0-based indexing, not Lua `#` / `[]`
- `isServer()` and `isClient()` are mutually exclusive; neither is true in singleplayer
- `OnPlayerUpdate` fires for all players including remote — guard with `player:isLocal()`or `getSpecificPlayer()`
- `SandboxVars` fields can be nil if the option was never set — always provide a fallback
- Upstream mod updates appear in Steam patch notes before files actually download — always verify workshop files have refreshed before auditing
- UI null pointer crashes in the Bandits Creator avatar preview are visual-only (invalid B42 body location slot names) — do not affect gameplay or saved configs
- `getCell()` can return nil transiently in B42 in `OnTick`, `OnPlayerUpdate`, and `EveryOneMinute` callbacks. Nil guards on `getCell()` in these contexts are correct behavior, not error suppression -- the polling loop safely skips a frame.
- Never use `pcall` in B42 Lua patches. Kahlua does not reliably expose it as a global. Use explicit nil and method-existence guards instead: `foo and foo.bar ~= nil`.
- `next()` has the same problem as `pcall` -- not reliably available as a Lua global in every B42 execution context. Confirmed via a `type(next)` diagnostic print inside an `OnPlayerUpdate` handler (returned `"nil"`), tracked down as the cause of a real crash (Wess Quartermaster's `rebuildTick`, fixed upstream in v1.5.1 by switching to `pairs()`). `pairs()` was confirmed present in that same context and is not currently known to be unreliable, unlike `pcall` and `next`. Don't test table emptiness with `next(t) == nil` in B42 patches -- use `local empty = true; for _ in pairs(t) do empty = false; break end` instead, or maintain a counter.
- When a crash traces to a bare call on a variable/global that looks like it should obviously exist (a base library function, a closed-over local), don't assume the static read of the code is wrong or stale -- add a one-line `type(x)` diagnostic print right before the suspect call and get a live answer before spending more time reasoning about it from source alone. This resolved the `next()` case above in one round-trip instead of several rounds of speculation on plausible-looking code that all turned out fine when actually inspected via `type()`. Diagnostic prints can go directly in the workshop file for a quick check (never for a real fix) when Steve says it's fine to touch it for that purpose -- otherwise route through the patch repo as usual.

---

## 42.20 Engine Audit (CFR decompile, July 2026)

Build 42.20 is the full B42 Stable launch (map doubled, town rebuilds, lighting overhaul, animal husbandry, deeper crafting). Confirmed via targeted CFR decompile of `projectzomboid.jar` (git revision `a2947723ca`) that this was a content/art overhaul, not an engine rework -- all previously documented B42 gotchas and patch assumptions below were checked directly against 42.20 source and hold unchanged unless noted otherwise.

**Confirmed unchanged in 42.20 (verified against decompiled source, not just inference):**
- `LootRespawn.respawnInChunk` still gates on exact string match against `TownZone`/`TownZones`/`TrailerPark` only (`zombie.LootRespawn`). AnruisiTown loot respawn gap analysis is still fully valid.
- `Events.OnAddItemToInventory` still does not exist (checked full `zombie.Lua.LuaEventManager.AddEvents()` list).
- `pcall` is not registered as a Lua global anywhere in `zombie.Lua.LuaManager`. All internal `pcall` usage is Java-side (`LuaCaller.pcall`), never exposed to mod scripts.
- `ActiveMods.isModActive()` (backing `getActivatedMods():contains()`) is still a plain exact-string `.contains()` check, trimmed but not normalized. No change here, though moot now that the HDX server is shut down.
- `SandboxVars.ModID.Option` can still be nil if the mod's custom sandbox option was never explicitly set, regardless of registration format.

**New in 42.20, not previously documented:**
- New Lua events: `OnClickedAnimalForContext`, `OnAnimalTracks` (animal husbandry hooks), `OnWeaponHitThumpable`, `OnPlayerGetDamage`, `OnDeadBodySpawn`, `OnSleepingTick`, plus a set of pre-registration events (`preAddItemDefs`, `preAddSkillDefs`, `preAddZoneDefs`, `preAddCatDefs`, `preAddForageDefs`) that may be cleaner extension points than monkey patching for future compat work.
- Full animal genetics/breeding simulation under `zombie.characters.animals` (`AnimalAllele`, `AnimalGene`, `AnimalGenomeDefinitions`, population/migration managers). Not decoration -- a real simulation layer. Relevant if any future mod touches animals or livestock.
- Mod-defined sandbox options can now be registered via a `media/sandbox-options.txt` file (parsed by `zombie.sandbox.CustomSandboxOptions`) alongside the older Lua-table style. Doesn't change the nil-fallback gotcha above.
- `zombie.buildingRooms` is the in-game Building Rooms Editor dev tool, not the runtime loot/room distribution system -- a dead end for room-name investigation, don't go looking there again.

**Open question needing verification (not yet confirmed against actual patch file):**
- `Item.getTags()` returns `Set<ItemTag>`, and `Item.hasTag(ItemTag)` does a plain `.contains()` against it. Because of Java generic erasure, calling `getTags():add("SomeString")` from Lua compiles and silently inserts a raw String into the set -- it will never satisfy `hasTag(ItemTag.X)` anywhere in vanilla or other mods' Java-side checks, since a String never equals an ItemTag instance. `PickAramidThread` is confirmed as a real, natively-registered vanilla `ItemTag` (`ItemTag.registerBase("PickAramidThread")` in `zombie.scripting.objects.ItemTag`), not a custom tag we invented. If `PickAramidThread_ModCompat.lua` adds the tag as a raw string rather than via `ItemTag.get(ResourceLocation.get("PickAramidThread"))`, it may not interoperate with anything checking the real vanilla tag. Needs a direct read of that patch file to confirm which form it uses before concluding anything is actually broken.

---

## Decisions Log

Things explicitly decided against — do not relitigate without new information.

- **No hash-based change detection.** Maintenance overhead too high; stale hashes are worse than no hashes. Check workshop file dates or re-read source when upstream changes are suspected.
- **No full directory listing baked into this file.** Listings go stale. Run fresh on demand when needed.
- **No permanent function map in this file.** Generate on demand via PowerShell scan if load order or conflict investigation requires it.
- **NoBandits CLAUDE.md is a near-full copy of the main repo CLAUDE.md, minus Bandits-specific entries.** Keep both in sync when adding gotchas, decisions, or tooling notes.
- **Use Python for all file manipulation scripts, not PowerShell.** PowerShell has consistent encoding and escaping issues with Unicode, string replacement, and multi-line heredocs that cause silent failures. Python handles all of these reliably. Deliver scripts as downloadable .py files; run with `python script.py` from PowerShell.
- **Retire patches when the upstream author fixes what we fixed.** Even if their approach differs from ours, if the crash or bug is addressed upstream, remove our patch and let them maintain it. If something new breaks, address it fresh. Carrying diverged whole-file copies against an actively maintained mod creates ongoing burden with no benefit.

---

## Tooling Notes

- Desktop Commander for file ops and process execution
- Filesystem MCP (`read_multiple_files`) for bulk workshop reads
- `edit_block` for targeted replacements; fall back to `write_file` for large rewrites where `edit_block` stalls silently
- `read_file` with `offset` and `length` is more reliable than `start_search` context lines for verifying exact call signatures
- Prefer asking Steve to run PowerShell for log parsing, directory listings, file searches — saves context tokens
- **Git is not on PATH by default in Desktop Commander PowerShell sessions.** Full path: `C:\Program Files\Git\bin\git.exe`. Use bat files (cmd.exe /c) for git ops and output capture.
- **Python is at `C:\Python314\python.exe`.** Not on PATH in Desktop Commander sessions. Use full path.
- **When giving Steve raw PowerShell commands**, always prefix executable paths with `&` — e.g. `& "C:\Program Files\Git\bin\git.exe" add ...`. Without `&`, PowerShell throws `UnexpectedToken` on the arguments.

---

## Known Console Noise

Errors and warnings identified and reported to mod authors. When reviewing a new console log, skip these unless they've changed character or significantly increased in frequency.

### `SpecialLootSpawns.OnCreateGasMask` / `OnCreateRespirator` / `OnCreateRecipeMagazine` / `OnCreateRandomColor`
`ERROR: General > LuaManager.getFunctionObject > no such function "SpecialLootSpawns.OnCreate*"`
Called by Authentic Z (2335368829) item scripts and copied by a dozen other mods (J&G uniform packs, VCE, H.E.C.U., zReArmorPack, etc.). The function is never defined anywhere in any mod. Reported to Authentic Z asking who's supposed to provide it. Fires on every gas mask / respirator spawn.

### `Hardwood_OnCreateMaglight`
`ERROR: General > LuaManager.getFunctionObject > no such function "Hardwood_OnCreateMaglight"`
Referenced in Hardwood's Police Pack (3687353319) `Copweapons.txt` line 46 as an `OnCreate` callback for the Maglite item. Never defined anywhere. Reported to Hardwood.

### `TodoCaserito.EsenciaVainilla*` missing items
`ERROR: ItemContainer.AddItem: can't find TodoCaserito.EsenciaVainilla[Variant]`
TodoCaserito (3600616323) loot distributions reference food-specific EsenciaVainilla variant items (EmpanadaJyQ, Mondongo, PizzaNapo, etc.) that are never defined in any script file. Reported to TodoCaserito.

### `VFX.CannedCherryPieFillingBox` / `VFX.CannedPepperSteakStewBox` missing items
`ERROR: ItemContainer.AddItem: can't find VFX.Canned*`
Vanilla Foods Expanded (3577903007) distribution tables reference these two items across all version folders (42.12, 42.13, 42.15) but neither is defined in any script file. Reported to VFE.

### `ClimbOverFenceState` NullPointerException
`ERROR: Multiplayer > StateMachine.stateEnter > Exception thrown: NullPointerException ... getBodyDamage() is null at ClimbOverFenceState.shouldFallAfterVaultOver`
Fires when DTV2 NPCs vault fences. DTV2 NPCs are IsoZombie instances that appear to skip normal BodyDamage initialization. State machine catches and swallows it -- no crash. Reported to DTV2.

### `SpriteConfig.initObjectInfo > Invalid SpriteConfig object! scripted object = Wooden_Windows`
`WARN: General > SpriteConfig.initObjectInfo > Invalid SpriteConfig object! scripted object = Wooden_Windows`
Neat Building (3536052310) entity script references `BuildRecipeCode.windowGlass.OnCreate` in the SpriteConfig component but that function is never defined in any Lua file. Fires when entering areas with wooden windows. Reported to Neat Building.

### `[Pen] raw ammoType = nil`
Zombie Penetration (3683154388) debug print in `getProfileForWeapon` fires unconditionally before the nil guard, logging on every melee hit including zombie-on-zombie. Hundreds of entries per combat session. Reported to Zombie Penetration.

### `ItemPickInfo -> cannot get ID for container: inventoryfemale`
Base game log, not a mod issue. Fires occasionally when the inventory UI encounters a female character container. Not actionable.

### `[DTV2/NPC/Warn] Unregister ignored zombie with no authoritative UUID`
DTV2 expected behavior when an NPC dies or despawns before DTV2 records a UUID for it. Not actionable.

---

## Open Issues

- **Military Tool Kit non-ASCII Lua comments**: Multiple Lua files under `42\media\lua\Client\` contain Portuguese comments with non-ASCII characters causing a non-fatal Kahlua lexer error on load (`ErrorMagnifier: ArrayIndexOutOfBoundsException: Index 65022`). Whole-file copies with ASCII substitutions are ineffective because PZ loads workshop originals regardless. Bug reported to mod author. No action until upstream fix.

---

## End of Session Checklist

1. Update Active Patch Inventory if any fixes were added, modified, or retired
2. Update Open Issues
3. Add anything new to Decisions Log or Gotchas
4. Commit and push [CLAUDE.md](http://CLAUDE.md) as part of the session's final commit



