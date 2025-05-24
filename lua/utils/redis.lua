local redis = require "resty.redis"

return function(self)
    local route = self.route

    local option = self.svcs.c.redis
    if not (option.name and option.host) then
        self.yield()
    else
        local rdb, err = redis:new()
        if not rdb then
            return route:fail(err, 503)
        end

        local ok, err = rdb:connect(option.host or "127.0.0.1", option.port or 6379)
        if not ok then
            return route:fail(err, 503)
        end

        if option.timeout then
            rdb:set_timeout(option.timeout)
        end

        if option.password then
            ok, err = rdb:auth(option.password)
            if not ok then return route:fail(err, 503) end
        end

        if option.database then
            ok, err = rdb:select(option.database)
            if not ok then return route:fail(err, 503) end
        end

        self[option.name or "redis"] = rdb

        self.yield()

        if option.max_idle_timeout and option.pool_size then
            rdb:set_keepalive(option.max_idle_timeout, option.pool_size)
        else
            rdb:close()
        end
    end
end
