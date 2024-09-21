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
end

function onLoad()
	drawUI()
end
