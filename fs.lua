-- ================= CONFIG =================
-- TURN ON ALL API LIST
local WORLD = "THORFISH"
local POS_X = 40
local POS_Y = 33
local BAIT_ID = 3432
local JOIN_DELAY = 6000
local LOOP_DELAY = 1000
local BAIT_DELAY = 800
local BAIT_TIMEOUT = 100000

-- ==========================================

local pos = {POS_X, POS_Y}
local bait = BAIT_ID

local putlure = false
local isWaitingFish = false
local lastBaitTime = 0
local needBait = false

-- ================= INVENTORY =================

function inv(id)
    local inv = GetInventory()
    if not inv then return 0 end

    for _, item in pairs(inv) do
        if item.id == id then
            return item.amount
        end
    end
    return 0
end

function isEmpty(id)
    return inv(id) == 0
end

-- ================= POSITION CHECK =================

function isAtSpot()
    local me = GetLocal()
    if not me then return false end

    local x = math.floor(me.pos.x / 32)
    local y = math.floor(me.pos.y / 32)

    return x == pos[1] and y == pos[2]
end

-- ================= CORE =================

function placebait(x, y)
    --  hanya boleh pas di spot
    if not isAtSpot() then return end

    SendPacketRaw(false, {
        type = 3,
        value = bait,
        px = x,
        py = y,
        x = GetLocal().pos.x,
        y = GetLocal().pos.y
    })
end

function sellFish()
    SendPacket(2, "action|dialog_return\ndialog_name|Exchange_Npc\nbuttonClicked|SellAllFish")
end

function joinWorld()
    Sleep(JOIN_DELAY)
    SendPacket(3, "action|join_request\nname|"..WORLD.."\ninvitedWorld|0")
    Sleep(JOIN_DELAY)
end

function leaveWorld()
    SendPacket(3, "action|quit_to_exit")
end

function goFishingSpot()
    FindPath(pos[1], pos[2])
    Sleep(600)
end

-- ================= FIND DROPPED BAIT =================

function findDroppedBait()
    for _, obj in pairs(GetObjectList() or {}) do
        if obj.id == bait then
            return math.floor(obj.pos.x / 32), math.floor(obj.pos.y / 32)
        end
    end
    return nil
end

-- ================= HOOK =================

AddHook("onvariant", "auto_fish_fast", function(var, netid)

    --  extra safety: kalau bukan di spot, skip semua
    if not isAtSpot() then return end

    if var[0] == "OnConsoleMessage" then
        local msg = var[1]

        --  dapet ikan → bait dulu baru jual
        if msg:find("You caught") then
            placebait(pos[1] + 1, pos[2] + 1)
            sellFish()

            lastBaitTime = os.clock()
            isWaitingFish = true
            putlure = false
        end

        --  gagal → retry langsung
        if msg:find("There was nothing") 
        or msg:find("Sit still") then

            placebait(pos[1] + 1, pos[2] + 1)

            lastBaitTime = os.clock()
            isWaitingFish = true
            putlure = false
        end
    end

    --  splash trigger
    if var[0]:find("OnPlayPositioned")
    and var[1]:find("audio/splash.wav")
    and netid == GetLocal().netid then

        placebait(pos[1] + 1, pos[2] + 1)

        lastBaitTime = os.clock()
        isWaitingFish = true
        putlure = false
    end
end)

-- ================= LOOP =================

while true do 
    if GetWorld() and GetWorld().name == WORLD:upper() then
        
        --  pastikan selalu di spot
        if not isAtSpot() then
            LogToConsole("BALIK KE SPOT...")
            goFishingSpot()
            Sleep(300)
        end

        --  cek bait habis
        if isEmpty(bait) then
            needBait = true
            isWaitingFish = false
        end

        -- ================= AMBIL BAIT =================
        if needBait then
            local bx, by = findDroppedBait()

            if bx and by then
                LogToConsole("AMBIL BAIT...")

                FindPath(bx, by)
                Sleep(800)

                goFishingSpot()

                needBait = false
                putlure = true
            else
                LogToConsole("MENUNGGU BAIT DROP...")
            end

            Sleep(500)

        else
            -- mulai mancing
            if not isWaitingFish then
                placebait(pos[1] + 1, pos[2] + 1)

                lastBaitTime = os.clock()
                isWaitingFish = true
            end

            -- fallback
            if putlure and (os.clock() - lastBaitTime > (BAIT_DELAY / 1000)) then
                placebait(pos[1] + 1, pos[2] + 1)

                lastBaitTime = os.clock()
                putlure = false
                isWaitingFish = true
            end

            -- anti stuck
            if isWaitingFish and (os.clock() - lastBaitTime > (BAIT_TIMEOUT / 1000)) then
                LogToConsole("AUTO RESET: Stuck, rejoin world...")

                leaveWorld()
                Sleep(2000)

                isWaitingFish = false
                putlure = false
                lastBaitTime = 0
            end
        end

    else
        isWaitingFish = false
        putlure = false
        needBait = false

        joinWorld()
        Sleep(3000)
    end

    Sleep(LOOP_DELAY)
end
