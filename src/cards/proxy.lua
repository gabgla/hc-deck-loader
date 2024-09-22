local function drawUI()
    self.UI.setXmlTable({
        {
            tag="HorizontalLayout",
            attributes={
                height=100,
                width=180,
                color="rgba(0,0,0,0.7)",
                position="15 -100 -80",
                scale="-1 -1 1",
                visibility=PC
            },
            children={
                {
                    tag="Text",
                    attributes={
                        fontSize=20,
                        color="white",
                        alignment="UpperLeft"
                    },
                    value=TEXT,
                },
            }
        }
    })

    self.createButton({
		click_function = "onSpawnOriginalButton",
		function_owner = self,
		label          = "Spawn Original",
		position       = { 0, 0.5, 1.35 },
		rotation       = { 0, 0, 0 },
		width          = 850,
		height         = 160,
		font_size      = 80,
		color          = { 0.5, 0.5, 0.5 },
		font_color     = { r = 1, b = 1, g = 1 },
		tooltip        = "Click to spawn the original card",
	})
end

function onSpawnOriginalButton(_, pc, _)
    local cardObject = JSON.decode(OG)
    local currentPos = self.positionToWorld({ 0, 0, 0 })
    local rotation = self.getRotation()

    cardObject.Transform.posX = currentPos.x
    cardObject.Transform.posY = currentPos.y + 100
    cardObject.Transform.posZ = currentPos.z + 3.5
    cardObject.Transform.rotX = rotation.x
    cardObject.Transform.rotY = rotation.y
    cardObject.Transform.rotZ = math.fmod(cardObject.Transform.rotZ + 180, 360)
	spawnObjectData({ data = cardObject })
end

function onLoad()
	drawUI()
end
