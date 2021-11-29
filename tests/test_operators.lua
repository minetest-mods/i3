local a, b, c = 0, 0, 0
b+=1
c++; local foo = "bar";
local t = {
	a = a++,
	b = 2,
	c = c+=2,
	d = a&3,
	e = 1,
}
t["b"] <<= 4
t.b >>= 2
assert(t.b == 8)
--print(dump(t))
--c += 1
c*=2
local i = 16
i += i<<4
assert(i == 272)
assert((a+=2) == 2)
assert(c++ == 3)
assert((a-=1) == -1)
assert((c^=4) == 16)
assert((a&b) == 0)
assert((c|=a) == 2)
assert((1<<8) == 256)
