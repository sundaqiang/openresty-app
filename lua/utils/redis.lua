local redis = require "resty.redis"

return function(self)
    return function(options)
        local route = self.route
        local r, e = redis:new()
        if not r then
            return route:error(e)
        end

        local o, e = r:connect(options.host or "127.0.0.1", options.port or 6379)

        if not o then
            return route:error(e)
        end

        if options.timeout then
            r:set_timeout(options.timeout)
        end

        if options.password then
            local ok, err = r:auth(options.password)
            if not ok then return route:error(err) end
        end

        if options.database then
            local ok, err = r:select(options.database)
            if not ok then return route:error(err) end
        end

        self[options.name or "redis"] = r

        route:after(function()
            if options.max_idle_timeout and options.pool_size then
                r:set_keepalive(options.max_idle_timeout, options.pool_size)
            else
                r:close()
            end
        end)
    end
end
