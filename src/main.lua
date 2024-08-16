ENV = self and "tts" or "dev"

if ENV == "tts" then
	HTTP_CLIENT = true
end

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

	function load_database(onComplete)
		if FALLBACK_DATABASE then
			return onComplete()
		end

		local filename = "./tools/Hellscube-Database.json"
		local f = assert(io.open(filename, "r"))
		local t = f:read("*all")
		f:close()

		local success, data = pcall(function() return jsondecode(t) end)

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

		FALLBACK_DATABASE = data

		onComplete()
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

if HTTP_CLIENT then
	-- Performs actual request
	function load_database(onComplete)
		if FALLBACK_DATABASE then
			return onComplete()
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

			FALLBACK_DATABASE = data

			printToAll("Database loaded")

			onComplete()
		end)
	end
end

------ CONSTANTS
DATABASE_URL = "https://skeleton.club/hellfall/Hellscube-Database.json"

FALLBACK_DATABASE = nil
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

-- Implements a radix tree - https://github.com/markert/lua-radixtree

-------------------------------------------------------------------------------

local function new_radix_tree()
	local pairs = pairs
	local next = next
	local tinsert = table.insert
	local tremove = table.remove

	local new = function()
		local j = {}

		-- the table that holds the radix_tree
		j.radix_tree = {}

		-- elments that can be filled by several functions
		-- and be returned as set of possible hits
		j.radix_elements = {}

		-- internal tree instance or table of tree instances
		-- used to hold parts of the tree that may be interesting afterwards
		j.return_tree = {}

		-- this FSM is used for string comparison
		-- can evaluate if the radix tree contains or ends with a specific string
		local lookup_fsm = function(wordpart, next_state, next_letter)
			if wordpart:sub(next_state, next_state) ~= next_letter then
				if wordpart:sub(1, 1) ~= next_letter then
					return false, 0
				else
					return false, 1
				end
			end
			if #wordpart == next_state then
				return true, next_state
			else
				return false, next_state
			end
		end

		-- evaluate if the radix tree starts with a specific string
		-- returns pointer to subtree
		local root_lookup
		root_lookup = function(tree_instance, part)
			if #part == 0 then
				j.return_tree = tree_instance
			else
				local s = part:sub(1, 1)
				if tree_instance and tree_instance[s] ~= true then
					root_lookup(tree_instance[s], part:sub(2))
				end
			end
		end

		-- evaluate if the radix tree contains or ends with a specific string
		-- returns list of pointers to subtrees
		local leaf_lookup
		leaf_lookup = function(tree_instance, word, state)
			local next_state = state + 1
			if tree_instance then
				for k, v in pairs(tree_instance) do
					if v ~= true then
						local hit, next_state = lookup_fsm(word, next_state, k)
						if hit == true then
							tinsert(j.return_tree, v)
						else
							leaf_lookup(v, word, next_state)
						end
					end
				end
			end
		end

		-- takes a single tree or a list of trees
		-- traverses the trees and adds all elements to j.radix_elements
		local radix_traverse
		radix_traverse = function(tree_instance)
			for k, v in pairs(tree_instance) do
				if v == true then
					j.radix_elements[k] = true
				elseif v ~= true then
					radix_traverse(v)
				end
			end
		end

		-- adds a new element to the tree
		local add_to_tree = function(word)
			local t = j.radix_tree

			-- for char in word:gfind(".") do
			-- 	if word == "Smart Fella // Fart Smella" then
			-- 		print(char)
			-- 	end
			-- 	if t[char] == true or t[char] == nil then
			-- 		t[char] = {}
			-- 	end
			-- 	t = t[char]
			-- end
			-- t[word] = true

			for i = 1, #word do
				local char = word:sub(i, i)
				if t[char] == true or t[char] == nil then
					t[char] = {}
				end
				t = t[char]
			end
			t[word] = true
		end

		-- removes an element from the tree
		local remove_from_tree = function(word)
			local t = j.radix_tree

			-- for char in word:gfind(".") do
			-- 	if t[char] == true then
			-- 		return
			-- 	end
			-- 	t = t[char]
			-- end
			-- t[word] = nil

			for i = 1, #word do
				local char = word:sub(i, i)
				if t[char] == true then
					return
				end
				t = t[char]
			end
			t[word] = nil
		end

		-- performs the respective actions for the parts of a fetcher
		-- that can be handled by a radix tree
		-- fills j.radix_elements with all hits that were found
		local match_parts = function(tree_instance, parts)
			j.radix_elements = {}
			if parts['equals'] then
				j.return_tree = {}
				root_lookup(tree_instance, parts['equals'])
				if j.return_tree[parts['equals']] == true then
					j.radix_elements[parts['equals']] = true
				end
			else
				local temp_tree = tree_instance
				if parts['startsWith'] then
					j.return_tree = {}
					root_lookup(temp_tree, parts['startsWith'])
					temp_tree = j.return_tree
				end
				if parts['contains'] then
					j.return_tree = {}
					leaf_lookup(temp_tree, parts['contains'], 0)
					temp_tree = j.return_tree
				end
				if parts['endsWith'] then
					j.return_tree = {}
					leaf_lookup(temp_tree, parts['endsWith'], 0)
					for k, t in pairs(j.return_tree) do
						for _, v in pairs(t) do
							if v ~= true then
								j.return_tree[k] = nil
								break
							end
						end
					end
					temp_tree = j.return_tree
				end
				if temp_tree then
					radix_traverse(temp_tree)
				end
			end
		end

		-- evaluates if the fetch operation can be handled
		-- completely or partially by the radix tree
		-- returns elements from the j.radix_tree if it can be handled
		-- and nil otherwise
		local get_possible_matches = function(path, is_case_insensitive)
			local level = 'impossible'
			local radix_expressions = {}

			if not is_case_insensitive then
				for name, value in pairs(path) do
					if name == 'equals' or name == 'startsWith' or name == 'endsWith' or name == 'contains' then
						if radix_expressions[name] then
							level = 'impossible'
							break
						end
						radix_expressions[name] = value
						if level == 'partial_pending' then
							level = 'partial'
						elseif level ~= 'partial' then
							level = 'all'
						end
					else
						if level == 'easy' or level == 'partial' then
							level = 'partial'
						else
							level = 'partial_pending'
						end
					end
				end
				if level == 'partial_pending' then
					level = 'impossible'
				end
			end

			if level ~= 'impossible' then
				match_parts(j.radix_tree, radix_expressions)
				return j.radix_elements, level
			else
				return nil, level
			end
		end

		j.add = function(word)
			add_to_tree(word)
		end
		j.remove = function(word)
			remove_from_tree(word)
		end
		j.get_possible_matches = get_possible_matches

		-- for unit testing

		j.match_parts = function(parts, xxx)
			match_parts(j.radix_tree, parts, xxx)
		end
		j.found_elements = function()
			return j.radix_elements
		end

		return j
	end

	return new()
end

-------------------------------------------------------------------------------

local function load_index()
	if INDEX then
		return
	end

	INDEX = {}

	for key, value in pairs(FALLBACK_DATABASE.data) do
		INDEX[value.Name] = key
	end
end

local function get_card_by_name(name)
	return FALLBACK_DATABASE.data[INDEX[name]]
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

local function format_text_fields(card, pos)
	local cost = ""
	local typeline = ""
	local pt = ""
	local loyalty = ""
	local text = ""
	local ft = ""
	local cmc = ""

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

	if #pt > 0 then
		pt = "[b]" .. pt .. "[/b]"
	end

	-- Generate Loyalty

	if card.Loyalty and card.Loyalty[pos] and #card.Loyalty[pos] > 0 then
		loyalty = card.Loyalty[pos]
	end

	if #loyalty > 0 then
		loyalty = "[b]" .. loyalty .. "[/b]"
	end

	-- Generate Text

	if card["Text Box"] and card["Text Box"][pos] and #card["Text Box"][pos] > 0 then
		text = card["Text Box"][pos]:gsub("\\n", "\n")
	end

	-- Generate FT

	if card["Flavor Text"] and card["Flavor Text"][pos] and #card["Flavor Text"][pos] > 0 then
		ft = string.format("---\n%s\n---", card["Flavor Text"][pos]):gsub("\\n", "\n")
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

		if card["Card Type(s)"] then
			for i, type in ipairs(card["Card Type(s)"]) do
				if type then
					local textFields = format_text_fields(card, i)
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

------------------
--- DEV
------------------

if ENV == "dev" then
	local list = "" -- Add cards here

	print("Parsing list")
	local cards = parse_card_list(list)
	print("Loading DB")

	load_database(function()
		print("Creating index")
		load_index()

		print("Creating tree")
		local radixTree = new_radix_tree()
		for _, value in pairs(FALLBACK_DATABASE.data) do
			radixTree.add(value.Name)
		end

		local m = radixTree.get_possible_matches({ startsWith = "", contains = "M" }, false)

		if m then
			for path, _ in pairs(m) do
				print(path)
			end
		end

		print("Building card data")

		local matched = match_cards(cards)
		local objects = build_card_objects(matched)
	end)
end

------------------
--- TTS
------------------
if ENV ~= "tts" then
	return
end

------ CARD SPAWNING
local function jsonForCardFace(face, position, flipped, count, index)
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
		LuaScript = "",
		LuaScriptState = "",
	}

	json.CustomDeck["24400"] = {
		FaceURL = face.imageURI,
		BackURL = getCardBack(),
		NumWidth = count,
		NumHeight = 1,
		BackIsHidden = true,
		UniqueBack = false,
		Type = 0
	}

	if enableTokenButtons and face.tokenData and face.tokenData[1] and face.tokenData[1].name and string.len(face.tokenData[1].name) > 0 then
		printErr("Token buttons not implemented.")
	end

	return json
end

-- Spawns the given card [faces] at [position].
-- Card will be face down if [flipped].
-- Calls [onFullySpawned] when the object is spawned.
local function spawnCard(faces, position, flipped, onFullySpawned)
	if not faces or not faces[1] then
		faces = { {
			name = "?",
			oracleText = "Card not found",
			imageURI =
			"https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
		} }
	end

	-- Force flipped if the user asked for everything to be spawned face-down
	if spawnEverythingFaceDown then
		flipped = true
	end

	local jsonFace1 = jsonForCardFace(faces[1], position, flipped, #faces, 0)

	if #faces > 1 then
		jsonFace1.States = {}
		for i = 2, (#(faces)) do
			local jsonFaceI = jsonForCardFace(faces[i], position, flipped, #faces, i - 1)

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
local function spawnDeck(cards, name, position, flipped, onFullySpawned, onError)
	local cardObjects = {}

	local sem = 0
	local function incSem() sem = sem + 1 end
	local function decSem() sem = sem - 1 end

	for _, card in ipairs(cards) do
		for i = 1, (card.input.count or 1) do
			if not card.faces or not card.faces[1] then
				card.faces = { {
					name = card.Name,
					oracleText = "Card not found",
					imageURI =
					"https://vignette.wikia.nocookie.net/yugioh/images/9/94/Back-Anime-2.png/revision/latest?cb=20110624090942",
				} }
			end

			incSem()
			spawnCard(card.faces, position, flipped, function(obj)
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

	for _, card in ipairs(cardObjects) do
		if card.input.maybeboard then
			table.insert(maybeboard, card)
		elseif card.input.sideboard then
			table.insert(sideboard, card)
		elseif card.input.commander then
			table.insert(commander, card)
		else
			table.insert(maindeck, card)
		end
	end

	printInfo("Spawning deck...")

	local sem = 5
	local function decSem() sem = sem - 1 end

	spawnDeck(maindeck, deckName, maindeckPosition, true,
		function() -- onSuccess
			decSem()
		end,
		function(e) -- onError
			printErr(e)
			decSem()
		end
	)

	spawnDeck(sideboard, deckName .. " - sideboard", sideboardPosition, true,
		function() -- onSuccess
			decSem()
		end,
		function(e) -- onError
			printErr(e)
			decSem()
		end
	)

	spawnDeck(maybeboard, deckName .. " - maybeboard", maybeboardPosition, true,
		function() -- onSuccess
			decSem()
		end,
		function(e) -- onError
			printErr(e)
			decSem()
		end
	)

	spawnDeck(commander, deckName .. " - commanders", commanderPosition, false,
		function() -- onSuccess
			decSem()
		end,
		function(e) -- onError
			printErr(e)
			decSem()
		end
	)

	spawnDeck(tokens, deckName .. " - tokens", tokensPosition, true,
		function() -- onSuccess
			decSem()
		end,
		function(e) -- onError
			printErr(e)
			decSem()
		end
	)

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

function preloadDB()
	if lock then
		log("DB already loading.")
	end

	load_database(function()

	end)

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
	-- self.createInput({
	-- 	input_function = "onLoadDeckInput",
	-- 	function_owner = self,
	-- 	label          = "Enter deck URL, or load from Notebook.",
	-- 	alignment      = 2,
	-- 	position       = { x = 0, y = 0.1, z = 0.78 },
	-- 	width          = 2000,
	-- 	height         = 100,
	-- 	font_size      = 60,
	-- 	validation     = 1,
	-- 	value          = deckURL,
	-- })

	self.createButton({
		click_function = "onPreloadDBButton",
		function_owner = self,
		label          = "Preload DB",
		position       = { -1, 0.1, 1.15 },
		rotation       = { 0, 0, 0 },
		width          = 850,
		height         = 160,
		font_size      = 80,
		color          = { 0.5, 0.5, 0.5 },
		font_color     = { r = 1, b = 1, g = 1 },
		tooltip        = "Click to load deck preload the database",
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

function onPreloadDBButton(_, pc, _)
	startLuaCoroutine(self, "preloadDB")
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

