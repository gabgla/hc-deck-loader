local function load_index()
	if INDEX then
		return
	end

	INDEX = {}

	local radixTree = new_radix_tree()

	for key, value in pairs(DATABASE) do
		INDEX[value.Name] = key
		INDEX[string.lower(value.Name)] = key
		radixTree.add(string.lower(value.Name))
	end

	RADIX_TREE = radixTree
end

local function get_card_by_name(name)
	return DATABASE[INDEX[name]]
end

local function get_card_by_pattern(name)
	local matches = RADIX_TREE.get_possible_matches({ startsWith = "", contains = name }, false)

	local candidate = nil

	if matches then		
		local current_distance = math.huge
		for path, _ in pairs(matches) do
			local distance = string_similarity(name, path)
			if distance < current_distance then
				current_distance = distance
				candidate = path
			end
		end
	end

	return get_card_by_name(candidate)
end


------ In Hellscube there are no rules
local function parseHCLine(line)
	-- Parse out card count if present
	local count, countIndex = string.match(line, "^%s*(%d+)[x%*]?%s+()")
	if count and countIndex then
		line = string.sub(line, countIndex)
	else
		count = 1
	end

	local name = line

	return name, count, nil, nil
end

local function parse_card_list(list)
	local cards = {}

	local i = 1
	local mode = "deck"

	for line in iterateLines(list) do
		if string.len(line) > 0 then
			if line == "Commander" then
				mode = "commander"
			elseif line == "Sideboard" then
				mode = "sideboard"
			elseif line == "Deck" then
				mode = "deck"
			else
				local name, count, setCode, collectorNum = parseHCLine(line)

				if name then
					cards[i] = {
						count = count,
						name = name,
						setCode = setCode,
						collectorNum = collectorNum,
						sideboard = (mode == "sideboard"),
						commander = (mode == "commander")
					}

					i = i + 1
				end
			end
		end
	end

	return cards
end

local function match_cards(cards)
	local matched = {}

	for index, card in ipairs(cards) do
		local found = get_card_by_name(card.name)

		-- Fallback 1 - case insensitive
		if not found then
			found = get_card_by_name(string.lower(card.name))
		end

		-- Fallback 2 - append (hc)
		if not found then
			found = get_card_by_name(string.lower(card.name) .. " (hc)")
		end

		-- Fallback 3 - use string search (partial match)
		if not found then
			found = get_card_by_pattern(string.lower(card.name))
		end

		-- Fallback 4 - as before, but for individual words
		if not found then
			found = get_card_by_pattern(string.lower(card.name))
		end

		if not found then
			found = {
				Name = card.name
			}
			printToAll(card.name .. " not found in database")
		end

		found.input = card
		table.insert(matched, found)
	end

	return matched
end

local function format_text_fields(card, side)
	local cost = ""
	local typeline = ""
	local pt = ""
	local loyalty = ""
	local text = ""
	local ft = ""
	local cmc = ""

	-- Generate Cost

	if side.Cost and #side.Cost > 0 then
		cost = side.Cost
	end

	-- Generate Typeline

	if side["Supertype(s)"] and #side["Supertype(s)"] > 0 then
		local parts = 0
		for type in side["Supertype(s)"]:gmatch("([^;]+)") do
			typeline = typeline .. (parts >= 1 and " " or "") .. type
			parts = parts + 1
		end
	end

	if side["Card Type(s)"] and #side["Card Type(s)"] > 0 then
		if #typeline > 0 then
			typeline = typeline .. " "
		end

		local parts = 0
		for type in side["Card Type(s)"]:gmatch("([^;]+)") do
			typeline = typeline .. (parts >= 1 and " " or "") .. type
			parts = parts + 1
		end
	end

	if side["Subtype(s)"] and #side["Subtype(s)"] > 0 then
		if #typeline > 0 then
			typeline = typeline .. " - "
		end

		local parts = 0
		for type in side["Subtype(s)"]:gmatch("([^;]+)") do
			typeline = typeline .. (parts >= 1 and " " or "") .. type
			parts = parts + 1
		end
	end

	-- Generate P/T

	if side.power and #side.power > 0 then
		pt = side.power .. "/"
	end

	if side.toughness and #side.toughness > 0 then
		if #pt > 0 then
			pt = pt .. side.toughness
		else
			pt = "?/" .. side.toughness
		end
	else
		if #pt > 0 then
			pt = pt .. "/?"
		end
	end

	if #pt > 0 then
		pt = "[b]" .. pt .. "[/b]"
	end

	-- Generate Loyalty

	if side.Loyalty and #side.Loyalty > 0 then
		loyalty = side.Loyalty
	end

	if #loyalty > 0 then
		loyalty = "[b]" .. loyalty .. "[/b]"
	end

	-- Generate Text

	if side["Text Box"] and #side["Text Box"] > 0 then
		text = side["Text Box"]:gsub("\\n", "\n")
	end

	-- Generate FT

	if side["Flavor Text"] and #side["Flavor Text"] > 0 then
		ft = string.format("---\n%s\n---", side["Flavor Text"]):gsub("\\n", "\n")
	end

	return {
		cost = cost,
		typeline = typeline,
		text = text,
		pt = pt,
		loyalty = loyalty,
		ft = ft
	}
end

local function build_card_title(name, cmc, textFields)
	if not cmc or #cmc == 0 then
		cmc = 0
	end

	local segments = {
		name,
		textFields.typeline,
		string.format("%s CMC", cmc)
	}
	local nonEmptySegments = {}

	for _, value in ipairs(segments) do
		if #value > 0 then
			table.insert(nonEmptySegments, value)
		end
	end

	return table.concat(nonEmptySegments, "\n")
end

local function build_oracle_text(textFields)
	local segments = {
		textFields.cost,
		textFields.typeline,
		textFields.text,
		textFields.pt,
		textFields.loyalty,
		textFields.ft
	}
	local nonEmptySegments = {}

	for _, value in ipairs(segments) do
		if #value > 0 then
			table.insert(nonEmptySegments, value)
		end
	end

	return table.concat(nonEmptySegments, "\n")
end

local function contains_sequence(inputStr, sequence)
	local cur = 1
	for i = 1, #inputStr do
		local char = inputStr:sub(i, i)
		if char == sequence:sub(cur, cur) then
			cur = cur + 1
		else
			cur = 1
		end
		if cur > #sequence then
			return true
		end
	end

	return false
end

local function get_proxy_face(card, side)
	local colors = {}
	if card["Color(s)"] and #card["Color(s)"] > 0 then
		for color in card["Color(s)"]:gmatch("([^;]+)") do
			table.insert(colors, color)
		end
	end

	if #colors == 0 then
		if string.find(side["Card Type(s)"], "Land") then
			return PROXY_LAND
		else
			return PROXY_COLORLESS
		end
	else
		if #colors >= 2 then
			return PROXY_GOLD
		end

		if colors[1] == "White" then
			return PROXY_WHITE
		end

		if colors[1] == "Blue" then
			return PROXY_BLUE
		end

		if colors[1] == "Black" then
			return PROXY_BLACK
		end

		if colors[1] == "Red" then
			return PROXY_RED
		end

		if colors[1] == "Green" then
			return PROXY_GREEN
		end
	end
end

local function build_card_objects(cards)
	local cardObjects = {}

	for index, card in ipairs(cards) do
		local cardObject = {
			title = card.Name,
			cmc = card.CMC,
			faces = {},
			input = card.input,
			proxy = false,
		}

		-- Process special layouts overrides
		local layout = LAYOUTS[card.Name]
		if layout ~= nil then
			cardObject.layout = layout

			if proxyNonStandardLayouts and cardObject.layout and cardObject.layout.aspect and cardObject.layout.aspect == "other" then
				cardObject.proxy = true
			end
		end

		local nameParts = {}

		-- TODO: Circumvent Moonsharp's pattern matching limitation
		-- Workaround is to avoid using the gmatch function
		if contains_sequence(card.Name, "//") then
			for word in card.Name:gmatch("([^//]+)") do
				local trimmed = word:gsub('^%s*(.-)%s*$', '%1')
				table.insert(nameParts, trimmed)
			end
		else
			table.insert(nameParts, card.Name)
		end

		if card.Sides then
			for i, type in ipairs(card.Sides) do
				if type then
					local textFields = format_text_fields(card, card.Sides[i])
					local name

					-- Use split names for DFCs, otherwise use full name
					if cardObject.layout and cardObject.layout.type == "mfc" and nameParts[i] then
						name = nameParts[i]
					else
						name = card.Name
					end

					cardObject.faces[i] = {
						imageURI = card.Image,
						name = build_card_title(name, card.CMC, textFields),
						oracleText = build_oracle_text(textFields)
					}

					if cardObject.proxy then
						cardObject.faces[i].proxyImageURI = get_proxy_face(card, card.Sides[i])
					end

					if improveAllCards then
						cardObject.faces[i] = {
							imageURI = "https://cards.scryfall.io/png/front/8/0/8059c52b-5d25-4052-b48a-e9e219a7a546.png",
							name = "Colossal Dreadmaw\nCreature - Dinosaur\n6 CMC",
							oracleText = "{4}{G}{G}\nCreature - Dinosaur\nTrample (This creature can deal excess combat damage to the player or planeswalker it’s attacking.)\n[b]6/6[/b]\n---\nIf you feel the ground quake, run. If you hear its bellow, flee. If you see its teeth, it’s too late.\n---",
							proxyImageURI = nil
						}
					end
				end
			end
		else
			printToAll("Failed to parse " .. card.Name)
		end

		table.insert(cardObjects, cardObject)
	end

	return cardObjects
end
