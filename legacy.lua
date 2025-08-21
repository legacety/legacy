script_author('legacy.')
local samp = require('samp.events')
local imgui = require('mimgui')
local encoding = require('encoding')
encoding.default = 'CP1251'
u8 = encoding.UTF8

local renderWindow = imgui.new.bool(false)
local g = {
    items = { ORDERED_LIST = {} },  -- ������ ������� � ��������
    market = {
        CLEAR = 0, SLOTS = {}, CURRENT_CHECK = 0, RANGE_CHECK = 0, SHOP_OPEN = false, NEXT_PAGE_ID = 0
    }
}

local scanPending = false
local scanMessageShown = false
local copyPending = false

function main()
    while not isSampAvailable() do wait(0) end
    sampAddChatMessage('{B0E0E6}>> {87CEEB}Legacy Scripts {B0E0E6}<< {FFFFFF}��������! ���������: {FFD700}/legacy', -1)
    sampRegisterChatCommand('legacy', function()
        renderWindow[0] = not renderWindow[0]
    end)
    wait(-1)
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
end)

local function startScan()
    if not g.market.SHOP_OPEN then
        sampAddChatMessage('{FF6347}[������] {FFA07A}�������� ���� ������� � ����� ��� ������������!', -1)
        if not scanPending then
            scanPending = true
            scanMessageShown = false
            lua_thread.create(function()
                while scanPending do
                    wait(500)
                    if g.market.SHOP_OPEN then
                        scanPending = false
                        if not scanMessageShown then
                            sampAddChatMessage('{90EE90} ����� �������! ������� ������������ �������...', -1)
                            scanMessageShown = true
                        end
                        g.market.CURRENT_CHECK = 0
                        clickNextItem()
                        break
                    end
                end
            end)
        end
        return
    end

    -- ���� ����� ��� ������� - ���������� ����� � ��������� ����
    scanPending = false
    scanMessageShown = false
    g.market.CURRENT_CHECK = 0
    clickNextItem()
end

local function tryCopyList()
    local data = {}
    for _, item in ipairs(g.items.ORDERED_LIST) do
        local countText = item.amount > 1 and ('\n����������: ' .. item.amount) or ''
        table.insert(data, item.name .. countText)
    end
    setClipboardText(table.concat(data, '\n\n'))
    sampAddChatMessage('{87CEEB} ������ ������� ������� ���������� � ����� ������!', -1)
end

imgui.OnFrame(
    function() return renderWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 500
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Legacy and Tema a love you', renderWindow)

            if imgui.Button(u8('�����������'), imgui.ImVec2(-1)) then
                startScan()
            end

            if imgui.Button(u8('����������� ������'), imgui.ImVec2(-1)) then
                tryCopyList()
            end    

            if imgui.Button(u8('�������� ������'), imgui.ImVec2(-1)) then
                g.items.ORDERED_LIST = {}
                sampAddChatMessage('{FFA07A}������ ������� ������.', -1)
            end

            imgui.Separator()

            for _, item in ipairs(g.items.ORDERED_LIST) do
                imgui.Text(u8(item.name))
                if item.amount > 1 then
                    imgui.Text(u8('����������: ' .. item.amount))
                end
            end

        imgui.End()
    end
)

-- ��������� ����� � ������, �������� ����������
function addItemToList(item)
    for _, v in ipairs(g.items.ORDERED_LIST) do
        if v.name == item.name then
            v.amount = v.amount + item.amount
            return
        end
    end
    table.insert(g.items.ORDERED_LIST, item)
end

function samp.onServerMessage(_, text)
    if g.market.CURRENT_CHECK > 0 and text == '[������] {ffffff}����� �����' then
        clickNextItem()
        return false
    end
end

function samp.onShowDialog(id, _, title, _, _, text)
    if g.market.CURRENT_CHECK > 0 and title == '{BFBBBA}������ � �������' then
        local data = getDataCentralMarketDialog(text)
        sampSendDialogResponse(id, 0)
        clickNextItem()
        return false
    end
end

function samp.onShowTextDraw(id, data)
    if data.boxColor == -15066598 and data.text == 'usebox' and data.color == -1 and data.style == 0 and data.backgroundColor == -16777216 and data.flags == 19 then
        g.market.RANGE_CHECK = data.position.x
    end
    if data.text == 'ON_SALE' or data.text == 'HA_�PO�A�E' then g.market.SHOP_OPEN = true end
    if #g.market.SLOTS > 0 and g.market.CLEAR == id then g.market.SLOTS = {}; g.market.CLEAR = 0 end
    if data.text == 'LD_SPAC:white' and data.flags == 18 and data.color == 0 and data.position.x < g.market.RANGE_CHECK and g.market.SHOP_OPEN then
        if g.market.CLEAR == 0 then g.market.CLEAR = id end
        if data.letterColor == -1 then table.insert(g.market.SLOTS, id) end
    end
    -- ������ "�����"
    if math.abs(data.position.x - 264.12396240234) < 0.0001 and math.abs(data.position.y - 357.74285888672) < 0.0001 then
        g.market.NEXT_PAGE_ID = id
    end
end

function samp.onSendClickTextDraw(id)
    if id == 65535 then
        g.market.SLOTS = {}
        g.market.SHOP_OPEN = false
        g.market.CLEAR = 0
    end
end

function clickNextItem()
    g.market.CURRENT_CHECK = g.market.CURRENT_CHECK + 1
    if g.market.CURRENT_CHECK > #g.market.SLOTS then
        if g.market.NEXT_PAGE_ID > 0 then
            sampSendClickTextdraw(g.market.NEXT_PAGE_ID)
            sampAddChatMessage('{87CEEB} ������������� �� ��������� ��������...', -1)
            g.market.CURRENT_CHECK = 0
            g.market.SLOTS = {}
            g.market.NEXT_PAGE_ID = 0

            lua_thread.create(function()
                wait(1000)
                while #g.market.SLOTS == 0 do wait(100) end
                clickNextItem()
            end)
        else
            g.market.CURRENT_CHECK = 0
            sampAddChatMessage('{3CB371}[���������] ������������ ���� ������� ������� ���������!', -1)
        end
        return
    end
    sampSendClickTextdraw(g.market.SLOTS[g.market.CURRENT_CHECK])
end

function getDataCentralMarketDialog(text)
    local data = {}
    local name = text:match('^(.-)\n')
    name = (name:match('^%{[0-9a-fA-F]*%}$') and text:match('^.-\n(.-)\n') or name)
    name = tostring(name:match('{......}.-%s*{......}(.-)%s*{......}') or name:match('{......}(.+){......}')):gsub(' %(������%)$', '')

    local patch = {text:match('{FE9A2E}�������� ������� {ffffff}(%d+%-��) {FE9A2E}������ {ffffff}%(%+%d+ � (%S+)%){FE9A2E}%.')}
    local upgrade = text:match('���������: {FFC300}(%d+/%d+)')
    local property = text:match('���������: {FFC300}(%d+/%d+)')
    local amount = text:match('���-��: (%d+)')
    local cost = text:match('����: (%d+)')
    amount = tonumber(amount) or 1

    table.insert(data, {name = u8(name), amount = amount})

    addItemToList({name = u8(name), amount = amount})
    return data
end