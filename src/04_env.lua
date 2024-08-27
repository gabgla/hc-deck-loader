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
		if DATABASE then
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
		if DATABASE then
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
