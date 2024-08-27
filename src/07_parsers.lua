local function load_index()
	if INDEX then
		return
	end

	INDEX = {}

	for key, value in pairs(DATABASE) do
		INDEX[value.Name] = key
	end
end

local function get_card_by_name(name)
	return DATABASE[INDEX[name]]
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

		-- Fallback 1 - append (hc)
		if not found then
			found = get_card_by_name(card.name .. " (hc)")
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
	if not cmc then
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

local function build_card_objects(cards)
	local cardObjects = {}

	for index, card in ipairs(cards) do
		local cardObject = {
			title = card.Name,
			cmc = card.CMC,
			faces = {},
			input = card.input
		}

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

					if i <= #nameParts then
						name = nameParts[i]
						cardObject.faces[i] = {

							imageURI = card.Image,
							name = build_card_title(name, card.CMC, textFields),
							oracleText = build_oracle_text(textFields)
						}
					else
						-- Skip missing names for now
						name = card.Name
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