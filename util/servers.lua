local JSON = require"JSON" -- luarocks install json-lua
os.execute "clear"

local list = io.popen("curl -s -H 'Accept: text/html' http://servers.minetest.net/list"):read("*a")
      list = JSON:decode(list).list

local servers = {}

for _, server in ipairs(list) do
	if server.mods then
		for _, mod in ipairs(server.mods) do
			if mod == "i3" then
				table.insert(servers, server.name)
			end
		end
	end
end

if #servers > 0 then
	print(("=> %u/%u servers using [i3]:\n\t• %s"):format(#servers, #list, table.concat(servers, "\n\t• ")))
else
	print"No server using [i3]"
end
