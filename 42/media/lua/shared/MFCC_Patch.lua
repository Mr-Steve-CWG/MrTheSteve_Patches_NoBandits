-- MFCC_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: MoneyFromCreditCard (Workshop: 3428650803, Mod ID: MoneyFromCreditCard)
-- Patched against: MFCC_functions_42.lua, 7636 bytes, modified 2026-03-11
--
-- ISSUES FIXED:
--   1. CheckBankTile: getAdjacentSquare() returns nil for unloaded squares,
--      crashing on square:getObjects():size(). Also getSprite() can be nil
--      on some tile objects, crashing on getName(). Both nil-guarded.
--   2. DepositOnCreditCard: getAllKeepInputItems():get(0) can return nil,
--      causing CardHasMoney() to crash on card:getName().
--   3. GetMoneyFromCard: getAllInputItems():get(0) can return nil,
--      causing crashes on item:getType() and item:getName().
--
-- STALENESS CHECK:
--   OnGameBoot compares source file byte size to the known value at patch time.
--   If it differs, a prominent warning is printed to the log. Check the
--   updated MFCC source and re-evaluate whether this patch is still needed,
--   still correct, or can be retired.
--
-- POLICY: All third-party mod fixes belong in MrTheSteve_Patches, not in the
--   Workshop files themselves, so patches survive upstream mod updates.

-- ============================================================
-- STALENESS CHECK
-- ============================================================

-- NOTE: Staleness check removed — luajava file I/O is unavailable in B42.16 Lua.
-- Patched against MFCC_functions_42.lua, 7636 bytes, 2026-03-11 (Workshop 3428650803).
-- If MoneyFromCreditCard updates, manually verify this patch is still correct.

-- ============================================================
-- GUARD 1: CheckBankTile
-- Original: crashes when adjacent squares are nil (unloaded cell edge)
--           and when tile objects have no sprite (nil getSprite()).
-- ============================================================

if MoneyFromCreditCard and MoneyFromCreditCard.OnTest then
    MoneyFromCreditCard.OnTest.CheckBankTile = function(sourceItem, result)
        if SandboxVars.MoneyFromCreditCard.Bank == false then
            return true
        end

        local playerSquare = getPlayer():getCurrentSquare()
        if not playerSquare then return false end

        local squares = {
            playerSquare,
            playerSquare:getAdjacentSquare(IsoDirections.N),
            playerSquare:getAdjacentSquare(IsoDirections.NW),
            playerSquare:getAdjacentSquare(IsoDirections.W),
            playerSquare:getAdjacentSquare(IsoDirections.SW),
            playerSquare:getAdjacentSquare(IsoDirections.S),
            playerSquare:getAdjacentSquare(IsoDirections.SE),
            playerSquare:getAdjacentSquare(IsoDirections.E),
            playerSquare:getAdjacentSquare(IsoDirections.NE),
        }

        for _, square in pairs(squares) do
            if square then
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local obj    = objects:get(i)
                    local sprite = obj and obj:getSprite()
                    local name   = sprite and sprite:getName()
                    if name and string.find(name, "bank") then
                        return true
                    end
                end
            end
        end

        return false
    end
end


-- ============================================================
-- GUARD 2: DepositOnCreditCard
-- Original: getAllKeepInputItems():get(0) can return nil if recipe
--           data has no keep-input item; CardHasMoney() then crashes
--           calling getName() on nil.
-- ============================================================

if MoneyFromCreditCard and MoneyFromCreditCard.OnCreate then
    local _origDeposit = MoneyFromCreditCard.OnCreate.DepositOnCreditCard
    if _origDeposit then
        MoneyFromCreditCard.OnCreate.DepositOnCreditCard = function(data, player)
            local card = data:getAllKeepInputItems():get(0)
            if not card then return end
            _origDeposit(data, player)
        end
    end

-- ============================================================
-- GUARD 3: GetMoneyFromCard
-- Original: getAllInputItems():get(0) can return nil; item:getType()
--           and item:getName() then crash.
-- ============================================================

    local _origGetMoney = MoneyFromCreditCard.OnCreate.GetMoneyFromCard
    if _origGetMoney then
        MoneyFromCreditCard.OnCreate.GetMoneyFromCard = function(data, player)
            local item = data:getAllInputItems():get(0)
            if not item then return end
            _origGetMoney(data, player)
        end
    end
end
