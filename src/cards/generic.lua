IDEAL_WIDTH = 2.19
IDEAL_HEIGHT = 4.04
TOLERANCE = 0.1

DRAWN_UI = false
PROXY_COLORLESS = "https://i.imgur.com/QJpbImB.png"

local function check_bounds()
    local bounds = self.getBoundsNormalized()
    print(bounds.size.x, " ", bounds.size.y, " ", bounds.size.z)

    if (bounds.size.x > IDEAL_WIDTH + TOLERANCE or bounds.size.x < IDEAL_WIDTH - TOLERANCE)
    or (bounds.size.z > IDEAL_HEIGHT + TOLERANCE or bounds.size.z < IDEAL_HEIGHT - TOLERANCE) then
        print("not compliant")
    else
        print("compliant")
    end
end

local function drawUI()
    if DRAWN_UI then
        return
    end

    self.createButton({
        click_function = "onTestButton",
        function_owner = self,
        label          = "Test",
        position       = { 0, 0.5, 2.35 },
        rotation       = { 0, 0, 0 },
        width          = 850,
        height         = 160,
        font_size      = 80,
        color          = { 0.5, 0.5, 0.5 },
        font_color     = { r = 1, b = 1, g = 1 },
        tooltip        = "Test bounds"
    })

    check_bounds()

    local bounds = self.getBoundsNormalized()
    if (bounds.size.x > IDEAL_WIDTH + TOLERANCE or bounds.size.x < IDEAL_WIDTH - TOLERANCE)
    or (bounds.size.z > IDEAL_HEIGHT + TOLERANCE or bounds.size.z < IDEAL_HEIGHT - TOLERANCE) then
        self.createButton({
            click_function = "onProxyButton",
            function_owner = self,
            label          = "Proxy Me",
            position       = { 0, 0.5, 1.35 },
            rotation       = { 0, 0, 0 },
            width          = 850,
            height         = 160,
            font_size      = 80,
            color          = { 0.5, 0.5, 0.5 },
            font_color     = { r = 1, b = 1, g = 1 },
            tooltip        = "Click to create a proxy of this card"
        })
    end

    DRAWN_UI = true
end

function onTestButton(_, pc, _)
    check_bounds()
end

function onProxyButton(_, pc, _)
    local data = self.getData()
    print(data.CustomDeck)
    for _, deck in pairs(data.CustomDeck) do
        deck.FaceURL = PROXY_COLORLESS
		deck.NumWidth = 1
    end

    data.Transform.posZ = data.Transform.posZ + 3.5
    data.LuaScript = ""
    data.States = {}

    spawnObjectData({ data = data })
end

function onLoad()
	drawUI()
end
