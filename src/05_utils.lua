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

-- Damerau–Levenshtein distance
local function string_similarity(a, b)
	local d = {}
	for i = 0, #a do
		d[i] = {}
		d[i][0] = i
	end

	for j = 0, #b do
		d[0][j] = j
	end

	local cost

	for i = 1, #a do
		for j = 1, #b do
			if a:sub(i, i) == b:sub(j, j) then
				cost = 0
			else
				cost = 1
			end

			d[i][j] = math.min(d[i-1][j] + 1, d[i][j-1] + 1, d[i-1][j-1] + cost)

			if i > 1 and j > 1 and a:sub(i, i) == b:sub(j-1, j-1) and a:sub(i-1, i-1) == b:sub(j, j) then
				d[i][j] = math.min(d[i][j], d[i-2][j-2] + 1)
			end
		end
	end

	return d[#a][#b]
end