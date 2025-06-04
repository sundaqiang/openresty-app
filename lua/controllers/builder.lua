
local _M = {}

function _M.index(self, sign)

    self:render([[
    <!DOCTYPE html>
    <html>
    <body>
      <h1>{{message}}</h1>
    </body>
    </html>]], { message = sign })

    self.done()
end

return _M
