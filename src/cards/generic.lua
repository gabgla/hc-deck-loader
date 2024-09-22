IDEAL_WIDTH = 2.19
IDEAL_HEIGHT = 4.04
TOLERANCE = 0.1

DRAWN_UI = false

local function drawUI()
    if DRAWN_UI then
        return
    end
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

function onProxyButton(_, pc, _)
    local data = self.getData()

    for _, deck in pairs(data.CustomDeck) do
        deck.FaceURL = PROXY_IMAGE_URL
		deck.NumWidth = 1
    end

    local scriptParts = {
        "PC=\"" .. pc .. "\"",
        "TEXT=\"" .. TEXT .. "\"",
        "OG=\"" .. self.getJSON(false):gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"",
        PROXY_SCRIPT
    }

    data.LuaScript = table.concat(scriptParts, " ")
    data.Transform.posZ = data.Transform.posZ + 3.5
    data.States = {}

    spawnObjectData({ data = data })
end

function onLoad()
	drawUI()
end
