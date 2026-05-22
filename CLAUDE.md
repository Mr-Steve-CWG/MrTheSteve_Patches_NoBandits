# [CLAUDE.md](http://CLAUDE.md) — MrTheSteve_Patches Session Context

Read this file at the start of every session. Update it at the end of any session that changes the patch inventory, resolves open issues, or establishes new decisions.

---

## Project Purpose

Private patch mod for Project Zomboid Build 42. Goal: fix demonstrably broken behavior in workshop mods without altering mod author intent. If something looks like a design choice rather than a bug, flag it and confirm with Steve before touching it.

Two parallel repos:

- `MrTheSteve_Patches` — full patch set including Bandits-specific fixes
- `MrTheSteve_Patches_NoBandits` — identical minus anything that depends on the Bandits mod

Unless a patch is explicitly Bandits-specific, it goes in both repos.

---

## Key Paths

PurposePathWorkshop content root`C:\Steam\steamapps\workshop\content\108600\`Bandits mod`...\3268487204\mods\Bandits\`Bandits Week One`...\3403180543\mods\BanditsWeekOne\`Local mods dir`C:\Users\steve\Zomboid\mods\`Main patch repo`C:\Users\steve\dev\MrTheSteve_Patches`NoBandits repo`C:\Users\steve\dev\MrTheSteve_Patches_NoBandits`Bandits AI behaviors`...\3268487204\mods\Bandits\42.16\media\lua\shared\ZombiePrograms\`Bandits clan configs`...\3268487204\mods\Bandits\common\bandits\clans.txt`Git remote`https://github.com/Mr-Steve-CWG/MrTheSteve_Patches.git`PZ JVM config`C:\Steam\steamapps\common\ProjectZomboid\ProjectZomboid64.json`

Repos use symlinks into the local mods directory — changes are live immediately. Patch file structure mirrors PZ layout: `42\media\lua\client\`, `shared\`, `server\`

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

Files: `42\media\lua\shared\Bandits_Patch.lua`, `42\media\lua\server\Bandits_Server_Patch.lua`Scope: Main repo only (Bandits-specific).

FixWhat it fixesStatusFix #1`spawnPoint` typo (should be `spawnPoints`) in `Spawner.Individual` — nil index crashActiveFix #3`ApplyVisuals` throttle — performance fix, our addition, not an upstream bugActiveFix #4`ManageCollisions` — `getBarricadeOnOppositeSquare` return unguarded, nil coord accessActiveFix #5`ans ==` typo in `BanditUpdate.lua` (should be `asn ==`)ActiveFix #2nil return from `generateSpawnPointUniform`Retired — fixed upstream (42.16.x)Fix #6`BanditServerCommands` `sendObjectChange('state')` B42 API crashRetired — fixed upstreamFix #7`BanditBasePlacements` window patch / `BanditServerSpawner` sendObjectChangeRetired — fixed upstream

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

Files: `42\media\lua\client\BBHide\`, `42\media\lua\shared\BBHide\`Scope: Both repos.

FixWhat it fixesFix #1`distanceBetween` missing `math.abs` wrapperFix #2`Cold` effectType referenceFix #3Nil texture guard in `DrawHideCanvas` before first hideFix #4Stray `return TimeAction` at end of `BB_Hide_ISTimedAction.lua`

Committed as `82ae07f`.

---

### AZAS Frequency Conflict Patch (Workshop ID 3655362047 / 3656359964)

File: `42\media\lua\shared\AZAS_FrequencyConflict_Patch.lua`Scope: Both repos.

Pre-seeds `AZAS_FrequencyIndex.mapping` before `FI.apply()` runs to resolve collisions between AZAS Frequency Index stations from different sub-mods of workshop ID 3656359964.

StationOriginalPatchedSURVIVOR RADIO (Just Music)8800087800Gallatin Underground8800087600KM-FM All Country (Just Music)8820087400Classical for the Dead140000140200

NMR Legacy (88000), Echo Station (88200), and Reverend Dan (140000) keep originals. Fails gracefully if any of these mods are not active — missing AZAS_STATIONS entries are harmless no-ops. `loadModAfter=AZASFrequencyIndex_RefactorTest` added to both [mod.info](http://mod.info) files.

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

Files: `42\media\lua\client\LTSProneGeneralHandler.lua`, `42\media\lua\shared\LTSProneTimedAction.lua`, `42\media\lua\shared\LTSPlayerProneStates.lua`, `42\media\lua\shared\LTSBuffs\LTSCustomBuffs.lua`Scope: Both repos. Method: Whole-file copies with inline fix markers.

FixFileWhat it fixesFix #1LTSProneTimedAction.lua`getDuration` instant-action branch — `baseTime` was unconditionally overwritten on the next line, making the cheat-speed branch dead codeFix #2LTSProneGeneralHandler.lua / LTSCustomBuffs.luaRemoved debug `print()` calls — fired on every prone toggle and every buff removal respectivelyFix #3LTSPlayerProneStates.luaCopy-paste bug in `isPlayerProneInFrontVehicle` — second condition was `isGettingUpFromPronePosition` twice; corrected to `isGettingDownForPronePosition`Fix #4LTSProneGeneralHandler.luaRemoved `getSquareDelta()` — dead code that referenced undefined global `PLAYER_SQR`

---

### MoneyFromCreditCard (Workshop ID 3428650803)

File: `42\media\lua\shared\MFCC_Patch.lua`Scope: Both repos.

FixWhat it fixesFix #1`CheckBankTile`: `getAdjacentSquare()` nil crash on unloaded squares; `getSprite()` nil crash on tile objectsFix #2`DepositOnCreditCard`: `getAllKeepInputItems():get(0)` nil crashFix #3`GetMoneyFromCard`: `getAllInputItems():get(0)` nil crash

---

### True MooZic (Workshop ID 3632610172)

Files: `42\media\lua\client\TCTickCheckMusic.lua`, `42\media\lua\client\Context\WorldObject\worldContextJukeboxLSBridge.lua`
Scope: Both repos. Method: Whole-file copies.

FixFileWhat it fixesFix #1TCTickCheckMusic.luaWhole-file copy predating upstream `TCMusic_ForEachVehicle` rework; needs re-diff on next audio bug reportFix #2worldContextJukeboxLSBridge.luaUTF-8 BOM (U+FEFF) at byte 0 before `--[[` — caused Kahlua `ArrayIndexOutOfBoundsException` lexer crash on startup; stripped BOM, content otherwise identical to workshop source

---

### True Music Radio (Workshop ID 3631572046)

File: `42\media\lua\client\TrueMusicRadio_Patch.lua`Scope: Both repos.

FixWhat it fixesFix #1`TMRadio.prettyName` nil crash — `getItemNameFromFullType()` returns null when content pack doesn't declare `module Tsarcraft`; nil then passed to `gsub()`

---

### Lifestyle: Hobbies (Workshop ID 3403870858)

File: `42\media\lua\client\RadioCom\TVRADIOTraits_ISRadioInteractions.lua`Scope: Both repos. Method: Whole-file copy.

FixWhat it fixesFix #1`_interactCodes:len()` called before nil check — Java null radio objects pass `== nil` but crash on method calls

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

File: `42\media\lua\server\PSC_Patch.lua`
Scope: Both repos.

| Fix | What it fixes |
|-----|---------------|
| Fix #1 | `Vehicles.CheckEngine.Engine` hard-sets engine condition to 0 for any vehicle whose PSC engine container has not been initialised yet (no `EnginePartInitMarker`). Requires 5 `EngineCritical`-tagged parts; finding fewer than 5 sets `minCondition = 0` and returns `false` (stall). Wrapper bails to vanilla `part:getCondition() > 0` if marker is absent. |
| Fix #2 | `Vehicles.Update.Battery` computes `GetPartCondition("EngineAlternator")` = 0 on uninitialised vehicles, so `alternatorAmps = 0` and the battery drains continuously with nothing to offset it. Wrapper skips the entire function (no-op) until the marker is present. |

Both conditions resolve permanently once the player enters the vehicle for the first time (PSC's `EngineSetupEnterVehicle` hook populates the container and stamps the marker). Safe without PSC: wrappers check that `Vehicles.CheckEngine.Engine` and `Vehicles.Update.Battery` are non-nil before installing; if PSC is not loaded the slots are never set and the wrappers are never registered.

---

### Guns of Marz (Workshop ID 3722134990)

File: `42\media\lua\client\GoM_VanillaConverter_Patch.lua`
Scope: Both repos. Soft dependency — only engages when `GunsOfMarz` is in the active mod list.

| Fix | What it fixes |
|-----|---------------|
| Fix #1 | Right-click context menu on vanilla weapons, ammo, attachments, and magazines to convert them to GoM equivalents. GoM strips vanilla guns/ammo from loot tables at load time, but runtime injection (airdrops, military mods, zone mods) can still produce them. Client-side `OnFillInventoryObjectContextMenu` hook. Single-option ammo converts directly; multi-option calibers (5.56, .308, 12ga) use a submenu. Gun conversions transfer condition proportionally and produce the appropriate mount; blocked with a chat message if magazine is loaded or attachments are mounted. Random attachment picks (scopes, lasers, lights) resolved at click time. |

**Vanilla item name notes:** 9mm/45/38/357/44 loose rounds use `Bullets9mm` / `Bullets45` etc. prefix (not `9mmBullets`). Shotgun box/carton are `ShotgunShellsBox` / `ShotgunShellsCarton`.

---

## B42 Gotchas

- `sendObjectChange('state')` crashes in B42 — use `IsoObjectChange.STATE`
- Java collections use `:size()` / `:get(i)` with 0-based indexing, not Lua `#` / `[]`
- `isServer()` and `isClient()` are mutually exclusive; neither is true in singleplayer
- `OnPlayerUpdate` fires for all players including remote — guard with `player:isLocal()`or `getSpecificPlayer()`
- `SandboxVars` fields can be nil if the option was never set — always provide a fallback
- Upstream mod updates appear in Steam patch notes before files actually download — always verify workshop files have refreshed before auditing
- UI null pointer crashes in the Bandits Creator avatar preview are visual-only (invalid B42 body location slot names) — do not affect gameplay or saved configs

---

## Decisions Log

Things explicitly decided against — do not relitigate without new information.

- **No hash-based change detection.** Maintenance overhead too high; stale hashes are worse than no hashes. Check workshop file dates or re-read source when upstream changes are suspected.
- **No full directory listing baked into this file.** Listings go stale. Run fresh on demand when needed.
- **No permanent function map in this file.** Generate on demand via PowerShell scan if load order or conflict investigation requires it.
- **NoBandits [CLAUDE.md](http://CLAUDE.md) contains delta notes only.** Canonical context lives here.
- **Use Python for all file manipulation scripts, not PowerShell.** PowerShell has consistent encoding and escaping issues with Unicode, string replacement, and multi-line heredocs that cause silent failures. Python handles all of these reliably. Deliver scripts as downloadable .py files; run with `python script.py` from PowerShell.
- **Use Python for all file manipulation scripts, not PowerShell.** PowerShell has consistent encoding and escaping issues with Unicode, string replacement, and multi-line heredocs that cause silent failures. Python handles all of these reliably. Deliver scripts as downloadable .py files; run with `python script.py` from PowerShell.
- **Retire patches when the upstream author fixes what we fixed.** Even if their approach differs from ours, if the crash or bug is addressed upstream, remove our patch and let them maintain it. If something new breaks, address it fresh. Carrying diverged whole-file copies against an actively maintained mod creates ongoing burden with no benefit.

---

## Tooling Notes

- Desktop Commander for file ops and process execution
- Filesystem MCP (`read_multiple_files`) for bulk workshop reads
- `edit_block` for targeted replacements; fall back to `write_file` for large rewrites where `edit_block` stalls silently
- `read_file` with `offset` and `length` is more reliable than `start_search` context lines for verifying exact call signatures
- Prefer asking Steve to run PowerShell for log parsing, directory listings, file searches — saves context tokens
- **Git is not on PATH by default in Desktop Commander PowerShell sessions.** Full path: `C:\Program Files\Git\bin\git.exe`. Use `$git = "C:\Program Files\Git\bin\git.exe"; & $git ...` pattern, or ask Steve to add it permanently: `[System.Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";C:\Program Files\Git\bin", [System.EnvironmentVariableTarget]::User)`
- **Python is at `C:\Python314\python.exe`.** Not on PATH in Desktop Commander sessions. Use full path: `& "C:\Python314\python.exe" script.py`

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

- **BanditUpdate_Patch.lua** (Bandits, 3268487204): Upstream Apr 26 update ("some 42.17 improvements") changed the IsoProperties API from `:Is()`/`:Val()` to `:has()`/`:get()` throughout BanditUpdate.lua. Our patch still uses the old API — fine on 42.16.3, likely broken on 42.17+. ManageCollisions, escape/retreat logic, and `becomeCorpse()` were also reworked. Full re-sync required before running Bandits on 42.17+; Fixes #4 and #5 must be carried forward into the new code.

---

## End of Session Checklist

1. Update Active Patch Inventory if any fixes were added, modified, or retired
2. Update Open Issues
3. Add anything new to Decisions Log or Gotchas
4. Commit and push [CLAUDE.md](http://CLAUDE.md) as part of the session's final commit



