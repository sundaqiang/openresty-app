local _M = {}

_M.__index = _M

function _M.new(svcs)
    local obj = { svcs = svcs }
    setmetatable(obj, _M)
    return obj
end

function _M:add_middlewares_to(route)
    local svcs = self.svcs
    route:use(function(self)
        self.svcs = svcs
    end)

    route:use(require("resty.route.middleware.form"))
    route:use(require("resty.route.middleware.reqargs"))
    route:use(require("resty.route.middleware.template"))
    route:use(require("utils.mysql"))
    route:use(require("utils.redis"))
end

return _M
