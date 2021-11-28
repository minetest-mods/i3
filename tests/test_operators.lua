local a, b, c = 0, 0, 0

b+=1
c++; local foo = "bar";
print(c-=1)
print(c++)
local t = {
	a = a++,
	b = b++,
	c = c++,
	d = a&3,
}
print(dump(t))

--c += 1
c*=2

local i = 16
i += i<<4
print(i) -- 272

print(a+=2) -- 2
print(c++) -- 3
print(a-=1) -- -1
print(c^=4) -- 16
print(a&b) -- 0
print(c|=a) -- 2
print(1<<8) -- 256
