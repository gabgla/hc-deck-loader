ENV = self and "tts" or "dev"

if ENV == "dev" then
	-- Implement TTS WebRequest
	local req_timeout = 10

	WebRequest = {}
	function WebRequest.get(url, callback)
		local request = require("http.request")
		local req = request.new_from_uri(url)
		req.headers:upsert(":method", "GET")

		local webReturn = {
			is_error = false,
			error = nil,
			text = nil
		}

		local headers, stream = req:go(req_timeout)
		if headers == nil then
			webReturn["is_error"] = true
			webReturn["error"] = tostring(stream)
		end

		local body, err = stream:get_body_as_string()
		if err then
			webReturn["is_error"] = true
			webReturn["error"] = tostring(err)
		end

		if body then
			webReturn["text"] = body
		end

		callback(webReturn)
	end

	-- Mock implementations
	function onError(msg)
		io.stderr:write(msg, "\n")
	end

	function printToColor(msg)
		print(msg)
	end

	function printToAll(msg)
		print(msg)
	end

	function log(msg)
		print(msg)
	end
end

------ CONSTANTS
DATABASE_URL = "https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json"

DATABASE = nil
INDEX = nil

DECK_SOURCE_URL = "url"
DECK_SOURCE_NOTEBOOK = "notebook"

MAINDECK_POSITION_OFFSET = { 0.0, 0.2, 0.1286 }
MAYBEBOARD_POSITION_OFFSET = { 1.47, 0.2, 0.1286 }
SIDEBOARD_POSITION_OFFSET = { -1.47, 0.2, 0.1286 }
COMMANDER_POSITION_OFFSET = { 0.7286, 0.2, -0.8257 }
TOKENS_POSITION_OFFSET = { -0.7286, 0.2, -0.8257 }

DEFAULT_CARDBACK = "https://i.imgur.com/ovmRjIz.jpeg"
DEFAULT_LANGUAGE = "en"

LANGUAGES = {
	["en"] = "en"
}

------ UI IDs
UI_ADVANCED_PANEL = "MTGDeckLoaderAdvancedPanel"
UI_CARD_BACK_INPUT = "MTGDeckLoaderCardBackInput"
UI_LANGUAGE_INPUT = "MTGDeckLoaderLanguageInput"
UI_FORCE_LANGUAGE_TOGGLE = "MTGDeckLoaderForceLanguageToggleID"

------ GLOBAL STATE
lock = false
playerColor = nil
deckSource = nil
advanced = false
cardBackInput = ""
languageInput = ""
forceLanguage = false
enableTokenButtons = false
blowCache = false
pngGraphics = true
spawnEverythingFaceDown = false

local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
	["\\"] = "\\",
	["\""] = "\"",
	["\b"] = "b",
	["\f"] = "f",
	["\n"] = "n",
	["\r"] = "r",
	["\t"] = "t",
}

local escape_char_map_inv = { ["/"] = "/" }
for k, v in pairs(escape_char_map) do
	escape_char_map_inv[v] = k
end


local function escape_char(c)
	return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
	return "null"
end


local function encode_table(val, stack)
	local res = {}
	stack = stack or {}

	-- Circular reference?
	if stack[val] then error("circular reference") end

	stack[val] = true

	if rawget(val, 1) ~= nil or next(val) == nil then
		-- Treat as array -- check keys are valid and it is not sparse
		local n = 0
		for k in pairs(val) do
			if type(k) ~= "number" then
				error("invalid table: mixed or invalid key types")
			end
			n = n + 1
		end
		if n ~= #val then
			error("invalid table: sparse array")
		end
		-- Encode
		for i, v in ipairs(val) do
			table.insert(res, encode(v, stack))
		end
		stack[val] = nil
		return "[" .. table.concat(res, ",") .. "]"
	else
		-- Treat as an object
		for k, v in pairs(val) do
			if type(k) ~= "string" then
				error("invalid table: mixed or invalid key types")
			end
			table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
		end
		stack[val] = nil
		return "{" .. table.concat(res, ",") .. "}"
	end
end


-- -*- coding: utf-8 -*-
--
-- Simple JSON encoding and decoding in pure Lua.
--
-- Copyright 2010-2017 Jeffrey Friedl
-- http://regex.info/blog/
-- Latest version: http://regex.info/blog/lua/json
--
-- This code is released under a Creative Commons CC-BY "Attribution" License:
-- http://creativecommons.org/licenses/by/3.0/deed.en_US
--
-- It can be used for any purpose so long as:
--    1) the copyright notice above is maintained
--    2) the web-page links above are maintained
--    3) the 'AUTHOR_NOTE' string below is maintained
--
-- local VERSION = '20170927.26' -- version history at end of file
-- local AUTHOR_NOTE = "-[ JSON.lua package by Jeffrey Friedl (http://regex.info/blog/lua/json) version 20170927.26 ]-"

--
-- The 'AUTHOR_NOTE' variable exists so that information about the source
-- of the package is maintained even in compiled versions. It's also
-- included in OBJDEF below mostly to quiet warnings about unused variables.
--
-- local OBJDEF = {
--    VERSION      = VERSION,
--    AUTHOR_NOTE  = AUTHOR_NOTE,
-- }

local function object_or_array(T)
	--
	-- We need to inspect all the keys... if there are any strings, we'll convert to a JSON
	-- object. If there are only numbers, it's a JSON array.
	--
	-- If we'll be converting to a JSON object, we'll want to sort the keys so that the
	-- end result is deterministic.
	--
	local string_keys = {}
	local number_keys = {}
	local number_keys_must_be_strings = false
	local maximum_number_key

	for key in pairs(T) do
		if type(key) == 'string' then
			table.insert(string_keys, key)
		elseif type(key) == 'number' then
			table.insert(number_keys, key)
			if key <= 0 or key >= math.huge then
				number_keys_must_be_strings = true
			elseif not maximum_number_key or key > maximum_number_key then
				maximum_number_key = key
			end
		elseif type(key) == 'boolean' then
			table.insert(string_keys, tostring(key))
		else
			error("can't encode table with a key of type " .. type(key))
		end
	end

	if #string_keys == 0 and not number_keys_must_be_strings then
		--
		-- An empty table, or a numeric-only array
		--
		if #number_keys > 0 then
			return nil, maximum_number_key -- an array
		elseif tostring(T) == "JSON array" then
			return nil
		elseif tostring(T) == "JSON object" then
			return {}
		else
			-- have to guess, so we'll pick array, since empty arrays are likely more common than empty objects
			return nil
		end
	end

	local map
	if #number_keys > 0 then
		--
		-- Have to make a shallow copy of the source table so we can remap the numeric keys to be strings
		--
		map = {}
		for key, val in pairs(T) do
			map[key] = val
		end

		--
		-- Throw numeric keys in there as strings
		--
		for _, number_key in ipairs(number_keys) do
			local string_key = tostring(number_key)
			if map[string_key] == nil then
				table.insert(string_keys, string_key)
				map[string_key] = T[number_key]
			else
				error("conflict converting table with mixed-type keys into a JSON object: key " ..
					number_key .. " exists both as a string and a number.")
			end
		end
	end

	return string_keys, nil, map
end


local function new_encode_table(val, stack)
	local res = {}
	stack = stack or {}

	local object_keys, maximum_number_key, map = object_or_array(val)
	if maximum_number_key then
		-- An array
		local ITEMS = {}
		for i = 1, maximum_number_key do
			table.insert(res, encode(val[i], stack))
		end
		stack[val] = nil
		return "[" .. table.concat(res, ",") .. "]"
	elseif object_keys then
		-- An object
		local TT = map or val
		local PARTS = {}
		for _, key in ipairs(object_keys) do
			table.insert(res, encode(key, stack) .. ":" .. encode(TT[key], stack))
		end
		stack[val] = nil
		return "{" .. table.concat(res, ",") .. "}"
	else
		-- An empty array/object... we'll treat it as an array, though it should really be an option
		stack[val] = nil
		return "[]"
	end
end


local function encode_string(val)
	return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
	-- Check for NaN, -inf and inf
	if val ~= val or val <= -math.huge or val >= math.huge then
		error("unexpected number value '" .. tostring(val) .. "'")
	end
	return string.format("%.14g", val)
end


local type_func_map = {
	["nil"] = encode_nil,
	["table"] = new_encode_table,
	["string"] = encode_string,
	["number"] = encode_number,
	["boolean"] = tostring,
}


encode = function(val, stack)
	local t = type(val)
	local f = type_func_map[t]
	if f then
		return f(val, stack)
	end
	error("unexpected type '" .. t .. "'")
end


function jsonencode(val)
	return (encode(val))
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
	local res = {}
	for i = 1, select("#", ...) do
		res[select(i, ...)] = true
	end
	return res
end

local space_chars  = create_set(" ", "\t", "\r", "\n")
local delim_chars  = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals     = create_set("true", "false", "null")

local literal_map  = {
	["true"] = true,
	["false"] = false,
	["null"] = nil,
}


local function next_char(str, idx, set, negate)
	for i = idx, #str do
		if set[str:sub(i, i)] ~= negate then
			return i
		end
	end
	return #str + 1
end


local function decode_error(str, idx, msg)
	local line_count = 1
	local col_count = 1
	for i = 1, idx - 1 do
		col_count = col_count + 1
		if str:sub(i, i) == "\n" then
			line_count = line_count + 1
			col_count = 1
		end
	end
	error(string.format("%s at line %d col %d", msg, line_count, col_count))
end


local function codepoint_to_utf8(n)
	-- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
	local f = math.floor
	if n <= 0x7f then
		return string.char(n)
	elseif n <= 0x7ff then
		return string.char(f(n / 64) + 192, n % 64 + 128)
	elseif n <= 0xffff then
		return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
	elseif n <= 0x10ffff then
		return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
			f(n % 4096 / 64) + 128, n % 64 + 128)
	end
	error(string.format("invalid unicode codepoint '%x'", n))
end


local function parse_number_b16(s)
	-- tonumber raises when given the empty string, if the base is not 10...
	if not s or s == '' then
		return nil
	end

	return tonumber(s, 16)
end


local function parse_unicode_escape(s)
	local n1 = parse_number_b16(s:sub(1, 4))
	local n2 = parse_number_b16(s:sub(7, 10))

	-- Surrogate pair?
	if n2 then
		return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
	else
		return codepoint_to_utf8(n1)
	end
end


local function parse_string(str, i)
	local res = ""
	local j = i + 1
	local k = j

	while j <= #str do
		local x = str:byte(j)

		if x < 32 then
			decode_error(str, j, "control character in string")
		elseif x == 92 then -- `\`: Escape
			res = res .. str:sub(k, j - 1)
			j = j + 1
			local c = str:sub(j, j)
			if c == "u" then
				local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
					or str:match("^%x%x%x%x", j + 1)
					or decode_error(str, j - 1, "invalid unicode escape in string")
				res = res .. parse_unicode_escape(hex)
				j = j + #hex
			else
				if not escape_chars[c] then
					decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
				end
				res = res .. escape_char_map_inv[c]
			end
			k = j + 1
		elseif x == 34 then -- `"`: End of string
			res = res .. str:sub(k, j - 1)
			return res, j + 1
		end

		j = j + 1
	end

	decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
	local x = next_char(str, i, delim_chars)
	local s = str:sub(i, x - 1)
	local n = tonumber(s)
	if not n then
		decode_error(str, i, "invalid number '" .. s .. "'")
	end
	return n, x
end


local function parse_literal(str, i)
	local x = next_char(str, i, delim_chars)
	local word = str:sub(i, x - 1)
	if not literals[word] then
		decode_error(str, i, "invalid literal '" .. word .. "'")
	end
	return literal_map[word], x
end


local function parse_array(str, i)
	local res = {}
	local n = 1
	i = i + 1
	while 1 do
		local x
		i = next_char(str, i, space_chars, true)
		-- Empty / end of array?
		if str:sub(i, i) == "]" then
			i = i + 1
			break
		end
		-- Read token
		x, i = parse(str, i)
		res[n] = x
		n = n + 1
		-- Next token
		i = next_char(str, i, space_chars, true)
		local chr = str:sub(i, i)
		i = i + 1
		if chr == "]" then break end
		if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
	end
	return res, i
end


local function parse_object(str, i)
	local res = {}
	i = i + 1
	while 1 do
		local key, val
		i = next_char(str, i, space_chars, true)
		-- Empty / end of object?
		if str:sub(i, i) == "}" then
			i = i + 1
			break
		end
		-- Read key
		if str:sub(i, i) ~= '"' then
			decode_error(str, i, "expected string for key")
		end
		key, i = parse(str, i)
		-- Read ':' delimiter
		i = next_char(str, i, space_chars, true)
		if str:sub(i, i) ~= ":" then
			decode_error(str, i, "expected ':' after key")
		end
		i = next_char(str, i + 1, space_chars, true)
		-- Read value
		val, i = parse(str, i)
		-- Set
		res[key] = val
		-- Next token
		i = next_char(str, i, space_chars, true)
		local chr = str:sub(i, i)
		i = i + 1
		if chr == "}" then break end
		if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
	end
	return res, i
end


local char_func_map = {
	['"'] = parse_string,
	["0"] = parse_number,
	["1"] = parse_number,
	["2"] = parse_number,
	["3"] = parse_number,
	["4"] = parse_number,
	["5"] = parse_number,
	["6"] = parse_number,
	["7"] = parse_number,
	["8"] = parse_number,
	["9"] = parse_number,
	["-"] = parse_number,
	["t"] = parse_literal,
	["f"] = parse_literal,
	["n"] = parse_literal,
	["["] = parse_array,
	["{"] = parse_object,
}


parse = function(str, idx)
	local chr = str:sub(idx, idx)
	local f = char_func_map[chr]
	if f then
		return f(str, idx)
	end
	decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function jsondecode(str)
	if type(str) ~= "string" then
		error("expected argument of type string, got " .. type(str))
	end
	local res, idx = parse(str, next_char(str, 1, space_chars, true))
	idx = next_char(str, idx, space_chars, true)
	if idx <= #str then
		decode_error(str, idx, "trailing garbage")
	end
	return res
end

------ UTILITY

local function trim(s)
	if not s then return "" end

	local n = s:find "%S"
	return n and s:match(".*%S", n) or ""
end

local function iterateLines(s)
	if not s or string.len(s) == 0 then
		return ipairs({})
	end

	if s:sub(-1) ~= '\n' then
		s = s .. '\n'
	end

	local pos = 1
	return function()
		if not pos then return nil end

		local p1, p2 = s:find("\r?\n", pos)

		local line
		if p1 then
			line = s:sub(pos, p1 - 1)
			pos = p2 + 1
		else
			line = s:sub(pos)
			pos = nil
		end

		return line
	end
end

local function underline(s)
	if not s or string.len(s) == 0 then
		return ""
	end

	return s .. '\n' .. string.rep('-', string.len(s)) .. '\n'
end

local function shallowCopyTable(t)
	if type(t) == 'table' then
		local copy = {}
		for key, val in pairs(t) do
			copy[key] = val
		end

		return copy
	end

	return {}
end

local function readNotebookForColor(playerColor)
	for i, tab in ipairs(Notes.getNotebookTabs()) do
		if tab.title == playerColor and tab.color == playerColor then
			return tab.body
		end
	end

	return nil
end

local function valInTable(table, v)
	for _, value in ipairs(table) do
		if value == v then
			return true
		end
	end

	return false
end

local function printErr(s)
	printToColor(s, playerColor, { r = 1, g = 0, b = 0 })
end

local function printInfo(s)
	printToColor(s, playerColor)
end

local function stringToBool(s)
	-- It is truly ridiculous that this needs to exist.
	return (string.lower(s) == "true")
end

-------------------------------------------------------------------------------

local function load_database()
	if DATABASE then
		return
	end

	WebRequest.get(DATABASE_URL, function(webReturn)
		if webReturn.is_error or webReturn.error then
			onError("Web request error: " .. webReturn.error or "unknown")
			return
		elseif string.len(webReturn.text) == 0 then
			onError("empty response")
			return
		end

		local success, data = pcall(function() return jsondecode(webReturn.text) end)

		if not success then
			onError("failed to parse JSON response")
			return
		elseif not data then
			onError("empty JSON response")
			return
		elseif data.object == "error" then
			onError("failed to find card")
			return
		end

		DATABASE = data
	end)
end

local function load_index()
	if INDEX then
		return
	end

	INDEX = {}

	for key, value in pairs(DATABASE.data) do
		INDEX[value.Name] = key
	end
end

local function get_card_by_name(name)
	return DATABASE.data[INDEX[name]]
end

------ DECK BUILDER SCRAPING
local function parseMTGALine(line)
	-- Parse out card count if present
	local count, countIndex = string.match(line, "^%s*(%d+)[x%*]?%s+()")
	if count and countIndex then
		line = string.sub(line, countIndex)
	else
		count = 1
	end

	local name, setCode, collectorNum = string.match(line, "([^%(%)]+) %(([%d%l%u]+)%) ([%d%l%u]+)")

	if not name then
		name, setCode = string.match(line, "([^%(%)]+) %(([%d%l%u]+)%)")
	end

	if not name then
		name = string.match(line, "([^%(%)]+)")
	end

	-- MTGA format uses DAR for dominaria for some reason, which scryfall can't find.
	if setCode == "DAR" then
		setCode = "DOM"
	end

	return name, count, setCode, collectorNum
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
	load_database()
	load_index()

	local matched = {}

	for index, card in ipairs(cards) do
		local found = get_card_by_name(card.name)

		-- Fallback 1 - append (hc)
		if not found then
			found = get_card_by_name(card.name .. " (hc)")
		end

		if not found then
			printToAll(card.name .. " not found in database")
		else
			found.input = card
			table.insert(matched, found)
		end
	end

	return matched
end

local function build_oracle_text(card, pos)
	local cost = ""
	local typeline = ""
	local pt = ""
	local loyalty = ""
	local text = ""
	local ft = ""

	-- Generate Cost

	if card.Cost and card.Cost[pos] and #card.Cost[pos] > 0 then
		cost = card.Cost[pos]
	end

	-- Generate Typeline

	if card["Supertype(s)"][pos] and #card["Supertype(s)"][pos] > 0 then
		local parts = 0
		for type in card["Supertype(s)"][pos]:gmatch("([^;]+)") do
			typeline = typeline .. (parts >= 1 and " " or "") .. type
			parts = parts + 1
		end
	end

	if card["Card Type(s)"][pos] and #card["Card Type(s)"][pos] > 0 then
		if #typeline > 0 then
			typeline = typeline .. " "
		end

		local parts = 0
		for type in card["Card Type(s)"][pos]:gmatch("([^;]+)") do
			typeline = typeline .. (parts >= 1 and " " or "") .. type
			parts = parts + 1
		end
	end

	if card["Subtype(s)"][pos] and #card["Subtype(s)"][pos] > 0 then
		if #typeline > 0 then
			typeline = typeline .. " - "
		end

		local parts = 0
		for type in card["Subtype(s)"][pos]:gmatch("([^;]+)") do
			typeline = typeline .. (parts >= 1 and " " or "") .. type
			parts = parts + 1
		end
	end

	-- Generate P/T

	if card.power[pos] and #card.power[pos] > 0 then
		pt = card.power[pos] .. "/"
	end

	if card.toughness[pos] and #card.toughness[pos] > 0 then
		if #pt > 0 then
			pt = pt .. card.toughness[pos]
		else
			pt = "?/" .. card.toughness[pos]
		end
	else
		if #pt > 0 then
			pt = pt .. "/?"
		end
	end

	-- Generate Loyalty

	if card.Loyalty and card.Loyalty[pos] and #card.Loyalty[pos] > 0 then
		loyalty = card.Loyalty[pos]
	end

	-- Generate Text

	if card["Text Box"] and card["Text Box"][pos] and #card["Text Box"][pos] > 0 then
		text = card["Text Box"][pos]
	end

	-- Generate FT

	if card["Flavor Text"] and card["Flavor Text"][pos] and #card["Flavor Text"][pos] > 0 then
		ft = string.format("---\n%s\n---", card["Flavor Text"][pos])
	end

	local segments = { cost, typeline, text, pt, loyalty, ft }
	local nonEmptySegments = {}

	for index, value in ipairs(segments) do
		if #value > 0 then
			table.insert(nonEmptySegments, value)
		end
	end

	return table.concat(nonEmptySegments, "\n")
end

local function build_card_objects(cards)
	local cardObjects = {}

	for index, card in ipairs(cards) do
		local cardObject = {
			title = card.Name,
			cmc = card.CMC,
			faces = {}
		}

		local nameParts = {}
		for word in card.Name:gmatch("([^//]+)") do
			local trimmed = word:gsub('^%s*(.-)%s*$', '%1')
			table.insert(nameParts, trimmed)
		end

		if card["Card Type(s)"] then			
			for i, type in ipairs(card["Card Type(s)"]) do
				if type then
					cardObject.faces[i] = {
						imageURI = card.Image,
						name = nameParts[i],
						oracleText = build_oracle_text(card, i)
					}
				end
			end
		else
			printToAll("Failed to parse " .. card.Name)
		end
	end
end

local list = "\
1 Discount Sol Ring\
1 The Entirety of Moby Dick\
1 Elfball\
1 Crucifact or Crucifixion\
1 Sheoldred, Whispering One (hc)\
1 Mime Walk\
1 Go for the `Gut`\
1 Force Pike\
1 Force of Kill\
1 Ball Torture\
1 Zelda, Legend Of\
1 Ponderfy\
1 DRUGS! DRUGS! DRUGS! DRUGS! DRUGS!\
1 Shock Land\
1 Moldspan Dragon\
1 Wrath of Richard Garfield, PHD\
1 Dread Returf\
1 Blinkhole\
1 Room Treasurer\
1 Oil\
1 Redditors strike\
1 Zalin, Gutter Bard\
1 Fact or Treason\
1 Miles Davis Kind of Blue\
1 Clackbridge Trollbooth\
1 Man Drain\
1 Psionic Bolt\
1 Arid Mesa Pegasus\
1 Tibalt’s Sex Dungeon\
1 Mental Two-Step\
1 Chalice of the Roids\
1 Stole Ring\
1 Strip Myr\
1 remember\
1 red Naturalize\
1 Aluminum Foil\
1 Clippy, Mulligan Helper\
1 Boltisphere\
1 Referee\
1 Thirst for Anything\
1 Lodestone Gottem (OG)\
1 Algebrade\
1 Omnath,        Mana\
1 Silver Sable\
1 Black(cleave) Cliffs\
1 Gloom Tender\
1 Which side are you on?\
1 Gush for All\
1 Marsh Flatter\
1 Tarni Brokenbrow\
1 Savannah Lions (hc)\
1 Path to the Gift Shop\
1 Seize the initiative (hc)\
1 The baby is involved\
1 Smallpox But You Got The Vaccine\
1 Scalding Karn\
1 Puerto Rican\
1 Wedding Ring (hc)\
1 Mana Dork\
1 Isamaru // Wasamaru\
1 Beefer Supreme\
1 Dazezon Tamar\
1 Ancestral Product Recall\
1 Build-a-Vilis\
1 _ Goblin\
1 Elfless Arbor\
1 Ancestral Recall (Alchemy Rebalanced)\
1 Pocket Sand\
1 King Big Slug the Biggest Slug\
1 Scooby, Dubious Monarch\
1 April 8, 2016 Standard Rotation\
1 Krenko, Dreadmawb Boss\
1 Phyrexian Goblin Guide\
1 Yeah here's a #suggestion\
1 Chad\
1 Anguished Making\
1 Lifetime's Supply of Mana Certificate\
1 Reactionary Bumper Sticker\
1 Jailed in a Jail in a Jail in a Jail in a Jail in a Jail in\
1 Censorship (hc)\
1 Bad to the Bone\
1 Swords to Luxurious Timeshares\
1 Feldon of Path\
1 Unnecessary Cameo\
1 Course of Kruphix\
1 Lightning Gut\
1 Mr. Tap\
1 Hellscube Internal Memo\
1 Serum Division\
1 The fish from go fish\
1 🐟'RE ESC🐟\
1 Exit Without Saving\
1 End-Raze Tworunners\
1 Braidses\
1 Oko, Thief of Crows\
1 Common Degnominator\
1 Fork Bolt\
1 Steal the British Crown Jewels\
1 fight spell\
1 Skrelv's Dispatch\
1 Medieval Mode\
1 The Twilight Zone Tower of Terror\
1 Monkeystery Mentor\
1 Careful Planning // FUCK IT, WE BALL\
1 Card Review\
1 Guy Tefieri\
1 Norin, But if he stopped being a Bitch\
1 Badbreaker Horror\
1 Raids, Plunderer Adept\
1 Bear Force One\
1 Inevitable Quadrome\
1 A Horse\
1 BoP It!\
1 Thalia, Mets Fan\
1 NO NAME\
1 Painstorm\
1 Gatekeeper\
1 Bobby Cheetofingers\
1 Black Lotus Cobra\
1 The Biggest Ball of Twine in Minnesota\
1 Demonic Kutor\
1 Boo!\
1 Ratatouille, the Rat\
1 Plot of Greed\
1 MIRRAN HIDING PLACE\
1 Dismember for Real\
1 Bojuka Dog\
1 Basilica Pipebomb\
1 Moxide Extortionist\
1 Mama Value\
1 Fellwar or Fellpeace Stone\
1 Sole Ring\
1 Dank Ritual\
1 Yargle, Yargle Yargle Yargle\
1 Regardless of the century, plane, or species, developing artificers never fail to invent the ornithopter.\
1 Wrenn and Six and Minsc and Boo\
1 Into the Royal\
1 Monkey See..\
1 Epic Rap Battles of History: Hydrogen Bomb VS Coughing Baby... Begin!\
1 Dracjack\
1 Here's the Advisor\
1 Dream Blunt Rotation\
1 Emrakul, and Memnite\
1 Megazord of Zendikar\
1 Australia\
1 Mono Black Legacy Creature Moodboard\
1 Moon Walk\
1 Baldur's Gate Tour Guide\
1 Wolpertinger\
1 Twice Upon a Time\
1 Depression\
1 Lag (Sorry)\
1 Mirrodin Besieged Rhino\
1 Swamp (hc)\
1 Bontu's Hunger\
1 tunnel through the walls\
1 Mishra's Twerkshop\
1 Computer Search\
1 Geven\
1 and Multani\
1 Uzumaki Guy\
1 Power Creep\
1 Fibonacci’s Saga\
1 Ol’ Reliable\
1 Yutavault\
1 Prison Ghost\
1 Gorilla Titan of Nature's Wrath\
1 Ancient Threemb\
1 Cut Up\
1 Monster Mash\
1 Needs Workshopping\
1 Anchor\
1 Wireless Snacker\
1 The Death of Meletis\
1 The Tinker\
1 Massacre Wurmcoil Engine\
1 Sword of Warren Instigator\
1 Sheoldred, the Ap               e\
1 Eternal Samsara\
1 Rankle's Jitte\
1 Card Leak\
1 Fblthp and Norin\
1 Zamboney\
1 Effeminate\
1 Pondering Ones\
1 lofiomancer\
1 Loki, My Cat\
1 Genie from Aladdin\
1 Ancestr Call\
1 Likening bolt\
1 Pelakkabrand\
1 Modern-Day Brontodon\
1 H-Ravenous Chupacabra\
1 Plotting Regisaur\
1 Antimar, Body of Elements\
1 Redundant Sea\
1 Me At Party\
1 Cathartic Cathar\
1 Siberian Tutor\
1 Corpse Dancer\
1 Bug Abuser\
1 Pact of Piracy\
1 Web M.D.\
1 No Hierarchy\
1 Scrub Daddy Land\
1 Toyota Tundra\
1 Zonatog\
1 Stubland\
1 Super Mana Friends\
1 Force of Rowan\
1 Krark-Clan Ironworkers Union\
1 City of Friends\
1 Bad Land // Bad Land\
1 Good in Tron\
1 Clone (hc)\
1 Charmageddon\
1 Finesser\
1 bnnuy\
1 Bananamorphose\
1 Minions: The Rise of Gru\
1 Batterie Antoinette\
1 Lost on Tropical Island\
1 Desolation Decuplet\
1 Sigil of the Porcelain Throne\
1 Demon Daze\
1 Negative Man\
1 Poisonous Dart Frog // Poisonous Dart\
1 Booster Shot\
1 Piranha Piranha Piranha Piranha\
1 Tism\
1 Going Bananas\
1 Cookie Monster\
1 Charizard\
1 Watermarked Vampire // Clipart Bats\
1 Legless Looting\
1 MAW Warden\
1 big lobter\
1 llanowar rebirth\
1 Booster Tutor but Funnier\
1 Forced Yard Sale\
1 Kruphix's Other Insight\
1 ig and noble hierarch\
1 Nusk // Norn\
1 I Forgot To Cast Spell Pierce Last Turn\
1 Bananath, Locus of CreApetion\
1 Urzbekitron Passport Card\
1 Siege Rhino // Second Siege Rhino\
1 Book of Moon\
1 Urabrask (All his limbs got chopped off)\
1 Two Headed Elf\
1 Wormhole\
1 My Apocalypse Shelter\
1 Rockforge Mystic\
1 Ass Grassify\
1 Drink the Future Juice\
1 Lingering Kohl's Cash\
1 Gushbringer\
1 Evil Gnome\
1 Cao Cao, Lord of Cao\
1 Meng Huo's Elf Husband\
1 Elesh Norn, Distant Cenobite\
1 Sylvan Librarian\
1 en-Kor\
1 Wife I Box\
1 Escalation Sage\
1 Gitaxiasoft OneDrive\
1 Call the Dermotaxi!\
1 Genesis Hydra // The Book of Genesis\
1 Rigged\
1 Llanowar // Elves\
1 Fight Fight Fight Fight Fight Fight\
1 Kodama's Extra Dextrous Super Duper Ultra Mega Reach\
1 Elesh Corn\
1 Netdecker\
1 🖕\
1 Forklift\
1 Gravetrolling\
1 Rainbow's End\
1 Phyrexian Washing Machine\
1 Spike\
1 Izzet Guildgate?\
1 Guide to Advantage City\
1 Eye in the Sky\
1 Six Mana Lightning Bolt\
1 BolaS linger\
1 re d Cabin\
1 He will never be ballin'\
1 Skitter of Chameleons\
1 That is so Fetch!\
1 Boomer Pile\
1 Nacatl\
1 Tour de Amonkhet\
1 (Vi)(gor M(o)rtus)\
1 Restoration Demon\
1 Waldo Confluence\
1 Orcish MINE\
1 Pelakka Wurmcoil Engine\
1 Dragonmaster with lots of friends 🙂\
1 Thoughtseizure\
1 World of Warcraft\
1 Fork Spike\
1 Inflation Man\
1 Pathway to Interaction // Pathway to Isolation\
1 Chisel and Dreamiel\
1 City on Extremely Confusing Fire\
1 Banding Unexplained\
1 evolution of the dreadmaw\
1 Rograkh and Ornithopter AND BONESAW!\
1 concordant alexander nitrokoffroads\
1 Timmy's Revenge Fantasy\
1 Paint Fairy\
1 Post-it Ghost\
1 Hellseeker\
1 ADHD Fuel\
1 Broodmother of Runes\
1 Goblin Dynamo (hc)\
1 Midnight aper\
1 Jin-Gitaxias, Frogress Tyrant\
1 Smaug (hc)\
1 Urabrask, Heretic Praetor and Drannith Magistrate\
1 Mistmoon Griffin and Misthollow Griffin\
1 ctf_2fort\
1 Exactly What Boros Needs More Of\
1 Gun Titan\
1 Steven\
1 Freaky Pizza\
1 Cackdos Rakler\
1 Horizons Canopy\
1 Angel of Milking\
1 ant Cat\
1 Tapped Dual w/ Upsides\
1 Colorblind Mountain\
1 Triskadekaiskelion\
1 Set Symbol Enjoyer\
1 Mana Sink\
1 Null Rod Of Blasting\
1 The Sign\
1 Eminent Domain\
1 Nicol Bolas's Day Off\
1 Loves truck Beast\
1 Anax, Divorced from // Cymede\
1 April is National Safe Digging Month\
1 Pschheewwww\
1 Fixer-Upper (hc4)\
1 Dead Joke\
1 Town That Isn’t Big Enough\
1 Call of the Herds\
1 Thallida, Guardian of Sarpadia\
1 Gerrymandering (hc)\
1 Fooded Foothills\
1 Assault and Battery (not Assault//Battery)\
1 Sideboard Hate Peace\
1 go storm!!!\
1 The Lord of the Shatterskull Pass\
1 Blade, Historian\
1 Garruk WildSticker\
1 Invasion of Privacy // Badass Hacker Cat\
1 Trample Bell\
1 Vertical Desync\
1 Wogenitus\
1 Wellness Coach\
1 storm Surge\
1 Elder Wizard\
1 Pet Gravyard\
1 Sygg, River\
1 Breed\
1 Zur, an Orb\
1 Over Grown Tomb\
1 Best Whisperer\
1 Storm Coast\
1 Thoptimus Prime\
1 THE COOL EGG\
1 Blastocragnotheriundroogodon\
1 Dense Foilage\
1 Ice and Fireblade Charger\
1 red Ultimatum\
1 Malikify\
1 Approach of the Second\
1 Ring\
1 Ancient Timb\
1 Microsynth Lattice\
1 Mirror Mash\
1 Twist of Fortune\
1 Min-Gitinyass\
1 Hasbro Lawmage\
1 Girl\
1 The Turn That Chronatog Ate\
1 The Three Weird Sisters // Compleated Conjurer\
1 Stigma\
1 Commandeeeeeer\
1 Ashnod's Waltar\
1 Primal Storm\
1 Michael\
1 Make Appear\
1 Ad Mouseam\
1 Compress\
1 Sakura-Tribe Welder\
1 Temptation // Debauchery\
1 Shards of Alara\
1 Midvale School for the Gifted\
1 Bitter Petal Blossom\
1 Animorph\
1 Run\
1 Path\
1 Troller of Physics\
1 Urza's Man Cave\
1 Heaven's ent\
1 Cavernival of Souls\
1 Extruder Extruder\
1 Green Opt\
1 Bigxalan\
1 Black Bolt\
1 Antimemetic\
1 MetalworkeD\
1 Deuces\
1 light mode\
1 Vendilion Click\
1 Good Grief\
1 relentful rats\
1 Nerf Aggro\
1 Teysa lov Extort\
1 The Guy From Burning Inquiry\
1 Imprisoned in the Blood Moon\
1 shrinkage\
1 Hollow None\
1 Siege Rhino Supplier\
1 Permeating Pass\
1 They\
1 Bestowgle\
1 Plagiarize (hc)\
1 Yuri, master of the Revue\
1 C ockwolf\
1 Quitterblossom\
1 Candelabra of anus\
1 Nightbear\
1 Pest of Titania\
1 Torbran, Tha Red Fell\
1 Assault Slug\
1 Invasion of Three Kingdoms Era China // Relentless Assault\
1 Sneak Peek\
1 Grrm Lavamancer\
1 Gahiji, Monored One\
1 Reinvent the Wheel\
1 Chrome Mox (hc)\
1 Monetary Mentor\
1 tutoring for removal/counters at instant speed for U ???\
1 Gemstone Yours\
1 Exclue\
1 Let This be a Lesson\
1 The Blitzkrieg Bop\
1 Otherworldly Daze\
1 Ghosting of Orzhova\
1 Mox Scuby\
1 Kill Spell\
1 Free Bird // Guitar Solo\
1 Menace\
1 Bloodfull Caves\
1 Your Crush Waves at You\
1 Blood Baboons\
1 Breadmaker Giant // Knead\
1 Bulbasaur // Ivysaur // Venusaur\
1 Goblin Artisan (it's different now)\
1 Skeleton Queen\
1 \"It's literally Time Walk!\"\
1 It of the Horrid **Swarm**\
1 Beast Withsperer\
1 Night coil\
1 Elephant JumpScare\
1 Grounter Spell\
1 Path to Fateful hour\
1 Oracle of Zel Daya\
1 Just a Theory\
1 Sorinu, Alpha of Innustrad // Shibalt, the Fair-Costed\
1 Poker Player\
1 Cryptid Command\
1 Is Scepter\
1 Ixalan’s Age of Dinosaurs\
1 Bald Horde\
1 Ambush Commander (for real)\
1 Studio Trigger\
1 Abstractify\
1 Nosy Intruder\
1 Henzie \"looTbox\" Torre\
1 Wilbur\
1 Curse of Chains of Mephistopheles\
1 The Dubious Monarch\
1 Caball Pits\
1 Demand Answer\
1 Landstill\
1 Impressive Iteration\
1 shitpost\
1 cure the Wastes\
1 Sol Warden\
1 Damm Blade\
1 The Royal Egg\
1 Cardnapper\
1 Grox\
1 The O Ring\
1 Tendrils of\
1 Basri\'s Sol\
1 Skullclamp and Memnite\
1 Tapewormancer\
1 Watchwolf Fan\
1 Yargoyle Castle\
1 Azusa\'s House\
1 Lotus Petal Mystical Tutor Gitaxian Probe Lotus Petal Imperial Seal Gitaxian Probe Lotus Petal Lotus Petal Lotus Petal Lotus Petal Madrush Cyclops\
1 Notorious Wicker Picker\
1 Ghost Dollar\
1 Skeleton Ship (hc)\
1 Curse of Loaches // Loaching Lurker\
1 The Classic \"Two Riptide Crabs\" Bargain\
1 Am Bush\
1 Ring Bear\
1 Gamma Counterspell\
1 Gniesburt\
1 Inquisition of Haktos the Unscarred\
1 Booblin Rabbleminscer\
1 Scrollport Merchant\
1 Mox Faithrhender\
1 Library of Alex\
1 Blasking Lotus\
1 Mine\'s Desire\
1 Rankle with Power\
1 Orcish Union Representative\
1 Another One\
1 Living Weapon\
1 Chestburster\
1 Bug Catcher\
1 Tiny Lotus\
1 Basking Tuatara\
1 Zendikar is Healing\
1 Real Bunni\
1 The Hulk\
1 Cantripping Balls\
1 Curse of Missing Out\
1 Dog Fursuit\
1 Land of ______ and ______\
1 Virtus of Persistence\
1 Inspiring Vintage\
1 Mox Brass\
1 Beach that Makes You Old\
1 Howling Werewalla\
1 Moderator\
1 Chaos Orgg\
1 Two Two/Twos on Two\
1 Hot\
1 Running Ballista\
1 Weatherman\'s Wrath\
1 Elves of Deep Light\
1 The Dross Piss\
1 Timnation\
1 Brazen Borrowee\
1 [WHO] Let\'s Kill Hitler\
1 Morph\
1 Gruff Octuplets\
1 >wires cat\
1 ABraids\
1 Sayonara\
1 Phyrexian Physicist\
1 Down the Meanstalk\
1 2014 Honda Civic\
1 Bonescythe Sliver but Friendly\
1 Thallids\'s Frightful Return\
1 Send Their Ass to Blorb-12\
1 Postmodern Manabase\
1 Normal Sleeping Faerie\
1 Sherlock Holmes\
1 Once upon a time // Twice upon a time\
1 Sakura Tribe\
1 Embrace Self\
1 How About I Just Fucking Kill You How About That\
1 Seal of Imperial\
1 lack Lotus // B ack Lotus\
1 Gopper\
1 Ultra Mega Anayalation BLAST!!!!!!!!!!!!!!!!!!!!!!\
1 Jace, Delver of Secrets\
1 Spork\
1 Me with a Shovel\
1 AI Art Waifu Proxy\
1 Alpha Dreadmaw\
1 Nevinyrral’s Nuclear Testing Site\
1 Subtract Nauseum\
1 The Iliad\
1 Evil Fucking Wizard Spell\
1 Coping Song\
1 Do Move\
1 Þirds of Paradise\
1 H-Fblthp, the Lost\
1 Phyrexian Arena Season Pass\
1 Plato\'s Allegory\
1 Kitchen Sphinx (hc4)\
1 Ex Orchard\
1 Kitesail Freeboot\
1 Dreadbore Arcanist\
1 Alex\'s Explore\
1 Gained a Toughness!\
1 9 Yottabyte ZIP Bomb\
1 Ancestral Loan\
1 Strictly Better Plateau\
1 Sunder Titan\
1 Thirst for Discover\
1 Serra Tomb\
1 Fact or Carnage Tyrant\
1 Explore your Brain\
1 Cease and Desist Letter\
1 Gary Clone (hc)\
1 Temple Walk\
1 Brainstorm Maggot\
1 Poisoning Bolt\
1 Outburst of Magic\
1 mor Mice\
1 Esperate Ritual\
1 3D Printer\
1 Oh Well\
1 Guard Thraben\
1 Among Us\
1 Sick ass skateboard\
1 Feeling\
1 All is Lost\
1 Phyrexian Generator\
1 Emergency Wipe\
1 Call for Hawk\
1 Omnath Goes to the Mana Store\
1 Eldritch Digivolution\
1 Paul Blartist\
1 Death // Death\
1 Rug of Death\
1 Rack or Fiction\
1 Dr. Who Cares\
1 Most Devout Creature\
1 Hydraulic Press\
1 Mono Red Enchantent Removal\
1 Mining\
1 Judge\'s Tower\
1 Cipherspell\
1 Postmodernism\
1 Jace, the Body Sculptor\
1 Do the Crime\
1 Fok\
1 Mountain of Coke\
1 Color Bleed\
1 Archpture Splaza\
1 {{Basic Land}}\
1 Ixalan Signet\
1 Bedtime Mandate\
1 Lava Tart\
1 Egg\
1 Oxidize (hc)\
1 Murder (hc)\
1 Grand Theft Auto\
1 Johnny, Dreadmaw Player\
1 Bottomless Sands\
1 Godo\'s Yak\
1 One with Nature (hc)\
1 s // storm\
1 Blockchain Thallid\
1 Hydroelectric Dam\
1 Spirit of Robbing another house\
1 Internet Troll\
1 Sudden But Inevitable Betrayal\
1 Darksteel Colossus 1/60 Perfect Grade Model Kit // Search for an Easier Hobby\
1 Hardly Mind Know Her\
1 Slayer of the Wickest\
1 Moxodon arhammer\
1 Breeches\
1 Smuggler\'s opter\
1 B.A.M.F\
1 American Crow\
1 Dimirbnb\
1 Auger\
1 seachrome post\
1 Macrosynth Golem\
1 Greenland\
1 Fucks Ungiven\
1 Tolarian Serra\'s Cradle\
1 Mantis Mantis Mantis\
1 Fetch shock bolt go\
1 Dope Ass Skeleton\
1 Stomping Ground // Stomp\
1 Avatar of WOE\
1 Aven Findcensor\
1 Impulsive // Hot-headed\
1 Ramping Spiketail\
1 Fort gas!\
1 Bearer of the Mulligan\
1 Dog Park\
1 Theorist\'s Motivation\
1 Thalia, Stoned in the Rain\
1 City of Radium\
1 Shock Absorbers\
1 Illusionary Player\
1 Revolving Wilds\
1 Whatever Hawk\
1 Nanukuluutuinnaqtuq\
1 Zoning Violation\
1 Bloodmoon Mire\
1 Bicycle (hc4)\
1 Cavern of S u s\
1 Krark\'s Third Leg\
1 Library (hc)\
1 Urza\'s Elevator\
1 Verdant Catalog\
1 Not on My Watchwolf\
1 Flood Stranding\
1 Blood Diamond\
1 The Florida Keys\
1 Overenthused Hype-Man\
1 NEEDS ETRATA\
1 Act of reason\
1 Playset of Squadron Hawks (On Clearance)\
1 The Dilu Horse\
1 Limerick\
1 Poll Delta\
1 Kruphix, God of the Hocus Pocus\
1 Phyrexian Hulk Hogan\
1 Gix\'s Bauble\
1 Archmage of the Photocopier\
1 Evolving Wild\
1 Twist and Shout\
1 Esper Panorama Photo I Tried to Take With My Phone but Everyone Kept Moving Around Too Much\
1 Coveted Juul\
1 Nitroglycerin Schooner\
1 KIDS MENU\
1 highl // forest\
1 Haunting House\
1 Übermegabliteration\
1 Marry into the Hull Clade GX\
1 Suddenly Siege Warfare\
1 URBorG, Tomb of Yandgmoth\
1 real Shelf\
1 Steam Events\
1 Reliquary Exchange and Returns\
1 The Other Side of Riftstone Portal\
1 Vilefin Inquisitor\
1 Denver International Airport\
1 To War!\
1 Urza\'s Simic Terraforming Device\
1 Unexpected Allosaurus\
1 Ritual Site\
1 Platinum Angel and Abyssal Persecutor\
1 Walmart Parking Lot\
1 Conditional Removal\
1 Niatnuom\
1 Dead on Board\
1 Pyramid Schemer\
1 Copperline George\
1 Doofenshmirtz Evil, Inc.\
1 the Dream-Den\
1 Draw Bridge\
1 Izzet Lecture Hall\
1 Three Mile Island\
1 Climb Mount Everest\
1 Doubling Season 2\
1 The Sparkmage"

local cards = parse_card_list(list)
local matched = match_cards(cards)
build_card_objects(matched)


------------------
---TTS
------------------
if ENV ~= "tts" then
	return
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
	local matched = match_cards(cards)
	local objects = build_card_objects(matched)

	onSuccess(objects, "")
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
		function(cardIDs, deckName)
			loadDeck(cardIDs, deckName,
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
	self.createInput({
		input_function = "onLoadDeckInput",
		function_owner = self,
		label          = "Enter deck URL, or load from Notebook.",
		alignment      = 2,
		position       = { x = 0, y = 0.1, z = 0.78 },
		width          = 2000,
		height         = 100,
		font_size      = 60,
		validation     = 1,
		value          = deckURL,
	})

	self.createButton({
		click_function = "onLoadDeckURLButton",
		function_owner = self,
		label          = "Load Deck (URL)",
		position       = { -1, 0.1, 1.15 },
		rotation       = { 0, 0, 0 },
		width          = 850,
		height         = 160,
		font_size      = 80,
		color          = { 0.5, 0.5, 0.5 },
		font_color     = { r = 1, b = 1, g = 1 },
		tooltip        = "Click to load deck from URL",
	})

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

function getDeckInputValue()
	for i, input in pairs(self.getInputs()) do
		if input.label == "Enter deck URL, or load from Notebook." then
			return trim(input.value)
		end
	end

	return ""
end

function onLoadDeckInput(_, _, _) end

function onLoadDeckURLButton(_, pc, _)
	printToColor("Not implemented.", pc)
end

function onLoadDeckNotebookButton(_, pc, _)
	if lock then
		printToColor("Another deck is currently being imported. Please wait for that to finish.", pc)
		return
	end

	playerColor = pc
	deckSource = DECK_SOURCE_NOTEBOOK

	startLuaCoroutine(self, "importDeck")
end

function onToggleAdvancedButton(_, _, _)
	advanced = not advanced
	drawUI()
end

function getCardBack()
	if not cardBackInput or string.len(cardBackInput) == 0 then
		return DEFAULT_CARDBACK
	else
		return cardBackInput
	end
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

function mtgdl__onLanguageInput(_, value, _)
	languageInput = value
end

function mtgdl__onForceLanguageInput(_, value, _)
	forceLanguage = stringToBool(value)
end

function mtgdl__onTokenButtonsInput(_, value, _)
	enableTokenButtons = stringToBool(value)
end

function mtgdl__onBlowCacheInput(_, value, _)
	blowCache = stringToBool(value)
end

function mtgdl__onPNGGraphicsInput(_, value, _)
	pngGraphics = stringToBool(value)
end

function mtgdl__onFaceDownInput(_, value, _)
	spawnEverythingFaceDown = stringToBool(value)
end

------ TTS CALLBACKS
function onLoad()
	self.setName("MTG Deck Loader")

	self.setDescription(
		[[
Enter your deck URL from many online deck builders!

You can also paste a decklist in MTG Arena format into your color's notebook.

Currently supported sites:
- tappedout.net
- archidekt.com
- moxfield.com
- deckstats.net
]])

	drawUI()
end