local exec = os.execute
local fmt, find, sub = string.format, string.find, string.sub
local var = "[%w%.%[%]\"\'_]"
local _,_, fs_elements = dofile("../src/styles.lua")

exec "clear"

local function split(str, delim, include_empty, max_splits, sep_is_pattern)
	delim = delim or ","
	max_splits = max_splits or -2
	local items = {}
	local pos, len = 1, #str
	local plain = not sep_is_pattern
	max_splits = max_splits + 1
	repeat
		local np, npe = find(str, delim, pos, plain)
		np, npe = (np or (len+1)), (npe or (len+1))
		if (not np) or (max_splits == 1) then
			np = len + 1
			npe = np
		end
		local s = sub(str, pos, np - 1)
		if include_empty or (s ~= "") then
			max_splits = max_splits - 1
			items[#items + 1] = s
		end
		pos = npe + 1
	until (max_splits == 0) or (pos > (len + 1))
	return items
end

local files = {
	"api",
	"bags",
	"caches",
	"callbacks",
	"common",
	"compression",
	"detached_inv",
	"fields",
	"groups",
	"gui",
	"hud",
	"model_aliases",
	"progressive",
	"styles",
}

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
	data = data:gsub("IMPORT%((.-)%)", function(a)
		return "local " .. a:gsub("\"", "") .. " = i3.get(" .. a .. ")"
	end)

	data = data:gsub("([%w_]+)%(", function(a)
		if fs_elements[a] then
			return fmt("fs('%s',", a)
		end
	end)

	data = data:gsub("([%w_]+)-%-\n", function(a)
		return fmt("%s = %s - 1", a, a)
	end)

	for op, func in pairs(operators) do
		data = data:gsub("(" .. var .. "+)%s?" .. op .. "%s?(" .. var .. "*)", func)
	end

	return data
end

for _, p in ipairs(files) do
	local function _load(path, line, data, t)
		if line then
			if not t then
				t = split(data, "\n")
			end
			t[line] = t[line]:gsub("(" .. var .. "+)%s?=%s?(" .. var .. "*)", "%2")
			data = table.concat(t, "\n")
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
				return _load(path, err_line, data, t)
			end
		end

		local _file = io.open(path:match("(.*)%.") .. ".lc", "w")
		_file:write(data)
		_file:close()
	end

	_load("../src/" .. p .. ".lua")
end

exec "luacheck ../init.lua"
exec "luacheck ../src/preprocessor.lua"
exec "luacheck ../src/*.lc"
exec "rm ../src/*.lc"
