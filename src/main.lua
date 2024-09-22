------------------
--- DEV
------------------
if ENV == "dev" then
	local list = "tomato massacre" -- Add cards here

	print("Parsing list")
	local cards = parse_card_list(list)

	load_database(function()
		print("Creating index")
		load_index()

		print("Building card data")

		local matched = match_cards(cards)

		for key, value in pairs(matched) do
			print(value.Name)
		end

		local objects = build_card_objects(matched)

		local results = RADIX_TREE.get_possible_matches(
			{
				{
					expr = "contains",
					value = "tomato"
				},
				{
					expr = "contains",
					value = "massacre"
				}
			},
			false
		)

		print(results)
		if results then
			for index, value in pairs(results) do
				print(index)
			end
		end
	end)
end

------------------
--- TTS
------------------
if ENV ~= "tts" then
	return
end

------ CARD SPAWNING
local function jsonForCardFace(face, position, flipped, count, index, card, useProxy)
	local rotation = self.getRotation()

	local rotZ = rotation.z
	if flipped then
		rotZ = math.fmod(rotZ + 180, 360)
	end
	if not count or count <= 0 then
		count = 1
	end

	local json = {
		Name = "Card",
		Transform = {
			posX = position.x,
			posY = position.y,
			posZ = position.z,
			rotX = rotation.x,
			rotY = rotation.y,
			rotZ = rotZ,
			scaleX = 1,
			scaleY = 1,
			scaleZ = 1
		},
		Nickname = face.name,
		Description = face.oracleText,
		Locked = false,
		Grid = true,
		Snap = true,
		IgnoreFoW = false,
		MeasureMovement = false,
		DragSelectable = true,
		Autoraise = true,
		Sticky = true,
		Tooltip = true,
		GridProjection = false,
		HideWhenFaceDown = true,
		Hands = true,
		CardID = 2440000 + index,
		SidewaysCard = false,
		CustomDeck = {},
		LuaScript = nil,
		LuaScriptState = "",
	}

	json.CustomDeck["24400"] = {
		FaceURL = face.imageURI,
		BackURL = get_card_back(),
		NumWidth = count,
		NumHeight = 1,
		BackIsHidden = true,
		UniqueBack = false,
		Type = 0,
		Sideways = false
	}

	-- Use layout overrides to position images correctly
	if card.layout then
		local layout = card.layout

		if card.proxy and useProxy and face.proxyImageURI then
			local ogFace = jsonencode(jsonForCardFace(face, position, flipped, count, index, card, false))

			local scriptParts = {
				"PC=\"" .. playerColor .. "\"",
				"TEXT=\"" .. card.title .. "\"",
				"OG=\"" .. ogFace:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"",
				PROXY_SCRIPT
			}

			json.CustomDeck["24400"].FaceURL = face.proxyImageURI
			json.LuaScript = table.concat(scriptParts, " ")
		elseif layout.grid then
			json.CustomDeck["24400"].NumWidth = layout.grid.x
			json.CustomDeck["24400"].NumHeight = layout.grid.y
		end

	end

	if not json.LuaScript then
		local scriptParts = {
			"PC=\"" .. playerColor .. "\"",
			"TEXT=\"" .. card.title .. "\"",
			CARD_SCRIPT
		}

		json.LuaScript = table.concat(scriptParts, " ")
	end

	if enableTokenButtons and face.tokenData and face.tokenData[1] and face.tokenData[1].name and string.len(face.tokenData[1].name) > 0 then
		printErr("Token buttons not implemented.")
	end

	return json
end

-- Spawns the given card [faces] at [position].
-- Card will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnCard(card, position, flipped, useProxy, onFullySpawned)
	local faces = card.faces
	if not faces or not faces[1] then
		faces = { {
			name = card.title,
			oracleText = "Card not found",
			imageURI = NOT_FOUND_FACE,
		} }
	end

	-- Force flipped if the user asked for everything to be spawned face-down
	if spawnEverythingFaceDown then
		flipped = true
	end

	-- Apply layout overrides
	local maxSides = #faces
	if card.layout and card.layout.sides then
		maxSides = card.layout.sides
	end

	if noSplitCards then
		maxSides = 1
	end

	while maxSides < #faces do
		local previous_face = faces[#faces - 1]
		local current_face = faces[#faces]

		previous_face.oracleText = previous_face.oracleText .. "\n//\n" .. current_face.oracleText

		table.remove(faces, #faces)
	end

	if card.layout and not noSplitCards then
		for i = #faces, card.layout.sides - 1 do
			local new_face = {
				name = "",
				oracleText = "",
				imageURI = faces[1].imageURI
			}

			table.insert(faces, new_face)
		end
	end

	local jsonFace1 = jsonForCardFace(faces[1], position, flipped, #faces, 0, card, useProxy)

	if #faces > 1 then
		jsonFace1.States = {}
		for i = 2, (#(faces)) do
			local jsonFaceI = jsonForCardFace(faces[i], position, flipped, #faces, i - 1, card, useProxy)

			jsonFace1.States[tostring(i)] = jsonFaceI
		end
	end

	spawnObjectData({
		data = jsonFace1,
		callback_function = function(cardObj)
			onFullySpawned(cardObj)
		end
	})
end

-- Spawns a deck named [name] containing the given [cards] at [position].
-- Deck will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnDeck(cards, name, position, flipped, useProxy, onFullySpawned, onError)
	local cardObjects = {}

	local sem = 0
	local function incSem() sem = sem + 1 end
	local function decSem() sem = sem - 1 end

	for _, card in ipairs(cards) do
		for i = 1, (card.input.count or 1) do
			if not card.faces or not card.faces[1] then
				card.faces = { {
					name = card.title,
					oracleText = "Card not found",
					imageURI = NOT_FOUND_FACE
				} }
			end

			incSem()
			spawnCard(card, position, flipped, useProxy, function(obj)
				table.insert(cardObjects, obj)
				decSem()
			end)
		end
	end

	Wait.condition(
		function()
			local deckObject

			if cardObjects[1] and cardObjects[2] then
				deckObject = cardObjects[1].putObject(cardObjects[2])
				if success and deckObject then
					deckObject.setPosition(position)
					deckObject.setName(name)
				else
					deckObject = cardObjects[1]
				end
			else
				deckObject = cardObjects[1]
			end

			onFullySpawned(deckObject)
		end,
		function() return (sem == 0) end,
		5,
		function() onError("Error collating deck... timed out.") end
	)
end

-- Queries for the given card IDs, collates deck, and spawns objects.
local function loadDeck(cardObjects, deckName, onComplete, onError)
	local maindeckPosition = self.positionToWorld(MAINDECK_POSITION_OFFSET)
	local sideboardPosition = self.positionToWorld(SIDEBOARD_POSITION_OFFSET)
	local maybeboardPosition = self.positionToWorld(MAYBEBOARD_POSITION_OFFSET)
	local commanderPosition = self.positionToWorld(COMMANDER_POSITION_OFFSET)
	local tokensPosition = self.positionToWorld(TOKENS_POSITION_OFFSET)

	local maindeck = {}
	local sideboard = {}
	local maybeboard = {}
	local commander = {}
	local tokens = {}
	local extras = {}

	for _, card in ipairs(cardObjects) do
		if card.input.maybeboard then
			table.insert(maybeboard, card)
		elseif card.input.sideboard then
			table.insert(sideboard, card)
		elseif card.input.commander then
			table.insert(commander, card)
		else
			table.insert(maindeck, card)
			if card.proxy then
				table.insert(extras, card)
			end
		end
	end

	printInfo("Spawning deck...")

	local sem = 0
	local function decSem() sem = sem - 1 end

	local tasks = {}

	if #maindeck > 0 then
		table.insert(tasks, function()
			spawnDeck(maindeck, deckName, maindeckPosition, true,
				function() -- onSuccess
					decSem()
				end,
				function(e) -- onError
					printErr(e)
					decSem()
				end
			)
		end)
	end

	if #sideboard > 0 then
		table.insert(tasks, function()
			spawnDeck(sideboard, deckName .. " - sideboard", sideboardPosition, true, true,
				function() -- onSuccess
					decSem()
				end,
				function(e) -- onError
					printErr(e)
					decSem()
				end
			)
		end)
	end

	if #maybeboard > 0 then
		table.insert(tasks, function()
			spawnDeck(maybeboard, deckName .. " - maybeboard", maybeboardPosition, true, true,
				function() -- onSuccess
					decSem()
				end,
				function(e) -- onError
					printErr(e)
					decSem()
				end
			)
		end)
	end

	if #commander > 0 then
		table.insert(tasks, function()
			spawnDeck(commander, deckName .. " - commanders", commanderPosition, false, true,
				function() -- onSuccess
					decSem()
				end,
				function(e) -- onError
					printErr(e)
					decSem()
				end
			)
		end)
	end

	if #tokens > 0 then
		table.insert(tasks, function()
			spawnDeck(tokens, deckName .. " - tokens", tokensPosition, true, true,
				function() -- onSuccess
					decSem()
				end,
				function(e) -- onError
					printErr(e)
					decSem()
				end
			)
		end)
	end

	if #extras > 0 then
		table.insert(tasks, function ()
			spawnDeck(extras, deckName .. " - extras", tokensPosition, true, false,
				function() -- onSuccess
					decSem()
				end,
				function(e) -- onError
					printErr(e)
					decSem()
				end
			)
		end)
	end

	sem = #tasks
	for _, f in ipairs(tasks) do
		f()
	end

	Wait.condition(
		function() onComplete() end,
		function() return (sem == 0) end,
		10,
		function() onError("Error spawning deck objects... timed out.") end
	)
end

local function readNotebookForColor(playerColor)
	for i, tab in ipairs(Notes.getNotebookTabs()) do
		if tab.title == playerColor and tab.color == playerColor then
			return tab.body
		end
	end

	return nil
end


local function queryDeckNotebook(_, onSuccess, onError)
	local bookContents = readNotebookForColor(playerColor)

	if bookContents == nil then
		onError("Notebook not found: " .. playerColor)
		return
	elseif string.len(bookContents) == 0 then
		onError("Notebook is empty. Please paste your decklist into your notebook (" .. playerColor .. ").")
		return
	end

	local cards = parse_card_list(bookContents)

	load_database(function()
		load_index()

		local matched = match_cards(cards)
		local objects = build_card_objects(matched)

		onSuccess(objects, "")
	end)
end


function importDeck()
	if lock then
		log("Error: Deck import started while importer locked.")
	end

	lock = true
	printToAll("Starting deck import...")

	local function onError(e)
		printErr(e)
		printToAll("Deck import failed.")
		lock = false
	end

	queryDeckNotebook(nil,
		function(cardObjects, deckName)
			loadDeck(cardObjects, deckName,
				function()
					printToAll("Deck import complete!")
					lock = false
				end,
				onError
			)
		end,
		onError
	)

	return 1
end

-- UI

local function drawUI()
	local _inputs = self.getInputs()
	local deckURL = ""

	if _inputs ~= nil then
		for i, input in pairs(self.getInputs()) do
			if input.label == "Enter deck URL, or load from Notebook." then
				deckURL = input.value
			end
		end
	end
	self.clearInputs()
	self.clearButtons()

	self.createButton({
		click_function = "onLoadDeckNotebookButton",
		function_owner = self,
		label          = "Load Deck (Notebook)",
		position       = { 1, 0.1, 1.15 },
		rotation       = { 0, 0, 0 },
		width          = 850,
		height         = 160,
		font_size      = 80,
		color          = { 0.5, 0.5, 0.5 },
		font_color     = { r = 1, b = 1, g = 1 },
		tooltip        = "Click to load deck from notebook",
	})

	self.createButton({
		click_function = "onToggleAdvancedButton",
		function_owner = self,
		label          = "...",
		position       = { 2.25, 0.1, 1.15 },
		rotation       = { 0, 0, 0 },
		width          = 160,
		height         = 160,
		font_size      = 100,
		color          = { 0.5, 0.5, 0.5 },
		font_color     = { r = 1, b = 1, g = 1 },
		tooltip        = "Click to open advanced menu",
	})

	if advanced then
		self.UI.show("MTGDeckLoaderAdvancedPanel")
	else
		self.UI.hide("MTGDeckLoaderAdvancedPanel")
	end
end

function onLoadDeckNotebookButton(_, pc, _)
	if lock then
		printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
		return
	end

	playerColor = pc
	print(playerColor)
	deckSource = DECK_SOURCE_NOTEBOOK

	startLuaCoroutine(self, "importDeck")
end

function onToggleAdvancedButton(_, _, _)
	advanced = not advanced
	drawUI()
end

function mtgdl__onCardBackInput(_, value, _)
	cardBackInput = value
end

function getLanguageCode()
	if not languageInput or string.len(languageInput) == 0 then
		return DEFAULT_LANGUAGE
	else
		local code = LANGUAGES[string.lower(trim(languageInput))]

		return (code or DEFAULT_LANGUAGE)
	end
end

function mtgdl__onProxyNonStandardLayoutsInput(_, value, _)
	proxyNonStandardLayouts = stringToBool(value)
end

function mtgdl__onTokenButtonsInput(_, value, _)
	enableTokenButtons = stringToBool(value)
end

function mtgdl__onFaceDownInput(_, value, _)
	spawnEverythingFaceDown = stringToBool(value)
end

function mtgdl__onNoSplitInput(_, value, _)
	noSplitCards = stringToBool(value)
end

function mtgdl__onUseOGCardBacksInput(_, value, _)
	useOGCardBacks = stringToBool(value)
end

function mtgdl__onImproveAllCardsInput(_, value, _)
	improveAllCards = stringToBool(value)
end

------ TTS CALLBACKS
function onLoad()
	self.setName("HC Deck Loader")

	self.setDescription(
		[[
Paste your decklist in MTG Arena format into your color's notebook, then click Load Deck button.
]])

	drawUI()
end
