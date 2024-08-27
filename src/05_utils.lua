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
