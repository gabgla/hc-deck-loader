DATABASE_URL = "https://raw.githubusercontent.com/bones-bones/hellfall/main/src/data/Hellscube-Database.json"

ENV = "dev"

if ENV == "dev" then
    -- Override TTS WebRequest
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

    -- Override onError
    function onError(msg)
        io.stderr:write(msg, "\n")
    end
end


local json = { _version = "0.1.2" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
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
   local string_keys = { }
   local number_keys = { }
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
         return { }
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
      map = { }
      for key, val in pairs(T) do
         map[key] = val
      end

      --
      -- Throw numeric keys in there as strings
      --
      for _, number_key in ipairs(number_keys) do
         local string_key = tostring(number_key)
         if map[string_key] == nil then
            table.insert(string_keys , string_key)
            map[string_key] = T[number_key]
         else
            error("conflict converting table with mixed-type keys into a JSON object: key " .. number_key .. " exists both as a string and a number.")
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
       local ITEMS = { }
       for i = 1, maximum_number_key do
          table.insert(res, encode(val[i], stack))
       end
       stack[val] = nil
       return "["  .. table.concat(res, ",")  .. "]"
    elseif object_keys then
       -- An object
      local TT = map or val
      local PARTS = { }
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
  [ "nil"     ] = encode_nil,
  [ "table"   ] = new_encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
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
  return ( encode(val) )
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
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
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
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
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_number_b16(s)
    -- tonumber raises when given the empty string, if the base is not 10...
    if not s or s == '' then
        return nil
    end

    return tonumber(s, 16)
end


local function parse_unicode_escape(s)
  local n1 = parse_number_b16( s:sub(1,4) )
  local n2 = parse_number_b16( s:sub(7, 10) )

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
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
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

    local n = s:find"%S"
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
    return function ()
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
    printToColor(s, playerColor, {r=1, g=0, b=0})
end

local function printInfo(s)
    printToColor(s, playerColor)
end

local function stringToBool(s)
    -- It is truly ridiculous that this needs to exist.
    return (string.lower(s) == "true")
end

-------------------------------------------------------------------------------

DATABASE = nil
INDEX = nil

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
                local name, count, setCode, collectorNum = parseMTGALine(line)

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
        if not found then
            onError(card.name .. " not found in database")
        else
            found.input = card
            table.insert(matched, found)
        end
    end

    return matched
end

local function build_oracle_text(card)
    print()
end

local function build_card_objects(cards)
    local cardObjects = {}

    for index, card in ipairs(cards) do
        local cardObject = {
            faces = {}
        }

        local nameParts = {}
        for word in card.Name:gmatch("([^//]+)") do
            local trimmed = word:gsub('^%s*(.-)%s*$', '%1')
            table.insert(nameParts, trimmed)
        end

        for i, type in ipairs(card["Card Type(s)"]) do
            if type then
                cardObject.faces[i] = {
                    imageURI = card.Image,
                    name = nameParts[i],
                    oracleText = ""
                }
            end
        end
    end

end


local list = "\
1 Smart Fella // Fart Smella\
1 Marie Kondo\
1 Maximillion Pegasus\
2 Benalish Mentor\
2 Graven Karens\
1 AITA\
2 Beedevil\
1 Loicense Inspector"

local cards = parse_card_list(list)
local matched = match_cards(cards)
build_card_objects(matched)
