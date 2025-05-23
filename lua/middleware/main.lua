local conf = require("utils.config")

local _M = {}

_M.__index = _M

function _M.new(deps)
    obj = {
        deps = deps
    }
    setmetatable(obj, _M)
    return obj
end

function _M:add_middlewares_to(route)
    route:use(function(self)
        require("resty.route.middleware.form")
        require("resty.route.middleware.reqargs")
        require("resty.route.middleware.template")
        require("utils.mysql"){conf.mysql}
        require("utils.redis"){conf.redis}
    end)
end

return _M
