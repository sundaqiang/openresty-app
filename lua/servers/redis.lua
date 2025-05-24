local redis = require "resty.redis"

return function(self)
    local route = self.route

    local options = self.conf.redis
    if not (options.name and options.host) then
        self.yield()
    else
        local rdb, err = redis:new()
        if not rdb then
            return route:fail(err, 503)
        end

        local ok, err = rdb:connect(options.host or "127.0.0.1", options.port or 6379)
        if not ok then
            return route:fail(err, 503)
        end

        if options.timeout then
            rdb:set_timeout(options.timeout)
        end

        if options.password then
            ok, err = rdb:auth(options.password)
            if not ok then return route:fail(err, 503) end
        end

        if options.database then
            ok, err = rdb:select(options.database)
            if not ok then return route:fail(err, 503) end
        end

        self[options.name or "redis"] = rdb

        self.yield()

        if options.max_idle_timeout and options.pool_size then
            rdb:set_keepalive(options.max_idle_timeout, options.pool_size)
        else
            rdb:close()
        end
    end
end
