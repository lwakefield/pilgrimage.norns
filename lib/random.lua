-- thank you rosetta code!
-- http://rosettacode.org/wiki/Pseudo-random_numbers/Xorshift_star#Lua
function xorshiftstar()
    local g = {
        magic = 0x2545F4914F6CDD1D,
        state = 0,
        seed = function(self, num)
            self.state = num
        end,
        next_int = function(self)
            local x = self.state
            x = x ~ (x >> 12)
            x = x ~ (x << 25)
            x = x ~ (x >> 27)
            self.state = x
            local answer = (x * self.magic) >> 32
            return answer
        end,
        next_float = function(self)
            return self:next_int() / (1 << 32)
        end
    }
    return g
end

return xorshiftstar