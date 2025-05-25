local _M = {}

_M.__index = _M

function _M.new(svcs)
    -- 将svcs挂载到临时对象上，并返回对象
    local obj = { _svcs = svcs }
    setmetatable(obj, _M)
    return obj
end

function _M:add_middlewares_to(route)
    -- 获取临时对象上的svcs，并清空临时对象
    local _svcs = self._svcs
    self._svcs = nil

    -- 添加中间件
    route:use(function(self)
        for k, v in pairs(_svcs) do
            self[k] = v
        end
    end)

    -- 添加中间件
    -- route:use(require("servers.form"))
    route:use(require("servers.risk"))
    route:use(require("servers.args"))
    route:use(require("resty.route.middleware.template"))
    route:use(require("servers.mysql"))
    route:use(require("servers.redis"))
    route:use(require("servers.lru"))
end

return _M
