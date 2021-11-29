local fmt = string.format
local var = "[%w%.%[%]\"\'_]"

local operators = {
	["([%+%-%*%^/&|])="] = function(a, b, c)
		return fmt("%s = %s %s %s", a, a, b, c)
	end,

	["+%+"] = function(a, b)
		return fmt("%s = %s + 1\n%s", a, a, b)
	end,

	["&"] = function(a, b)
		return fmt("bit.band(%s, %s)", a, b)
	end,

	["|"] = function(a, b)
		return fmt("bit.bor(%s, %s)", a, b)
	end,

	["<<"] = function(a, b)
		return fmt("bit.lshift(%s, %s)", a, b)
	end,

	[">>"] = function(a, b)
		return fmt("bit.rshift(%s, %s)", a, b)
	end,

	["<<="] = function(a, b)
		return fmt("%s = bit.lshift(%s, %s)", a, a, b)
	end,

	[">>="] = function(a, b)
		return fmt("%s = bit.rshift(%s, %s)", a, a, b)
	end,
}

local function compile(data)
	for op, func in pairs(operators) do
		data = data:gsub("(" .. var .. "+)%s?" .. op .. "%s?(" .. var .. "*)", func)
	end

	return data
end

local function _load(path, line, data)
	if line then
		data = data:split"\n"
		data[line] = data[line]:gsub("(" .. var .. "+)%s?=%s?(" .. var .. "*)", function(_,b) return b end)
		data = table.concat(data, "\n")
	else
		local file = assert(io.open(path, "r"))
		data = file:read"*a"
		file:close()
		data = compile(data)
	end

	local l, err = loadstring(data)

	if not l then
		local err_line = tonumber(err:match(":(%d+):"))

		if line ~= err_line then
			return _load(path, err_line, data)
		end
	end

	return l, err
end

return function(path)
	return _load(path) or loadfile(path)
end
