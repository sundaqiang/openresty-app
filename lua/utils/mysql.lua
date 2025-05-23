local mysql = require "resty.mysql"

return function(self)
    return function(options)
        local route = self.route
        local db, err = mysql:new()
        if not db then
            return route:error(err)
        end

        local ok, err, _, _ = db:connect{
            host = options.host or "127.0.0.1",
            port = options.port or 3306,
            database = options.database or "ngx_test",
            user = options.user or "ngx_test",
            password = options.password or "ngx_test",
            charset = options.charset or "utf8",
            max_packet_size = options.max_packet_size or 1024 * 1024,
        }

        if not ok then
            db:close()
            return route:error(err)
        end

        if options.timeout then
            db:set_timeout(options.timeout)
        end

        self[options.name or "mysql"] = db

        route:after(function()
            if options.max_idle_timeout and options.pool_size then
                db:set_keepalive(options.max_idle_timeout, options.pool_size)
            else
                db:close()
            end
        end)
    end
end
