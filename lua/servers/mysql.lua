local mysql = require "resty.mysql"

return function(self)
    local route = self.route

    local options = self.conf.mysql
    if not (options.name and options.host and options.database and options.user) then
        self.yield()
    else
        local db, err = mysql:new()
        if not db then
            return route:fail(err, 503)
        end

        local ok, err, errcode, sqlstate = db:connect{
            host = options.host or "127.0.0.1",
            port = options.port or 3306,
            database = options.database or "",
            user = options.user or "root",
            password = options.password or "",
            charset = options.charset or "utf8mb4",
            max_packet_size = options.max_packet_size or 1024 * 1024,
        }
        if not ok then
            return route:fail(err, 503)
        end

        if options.timeout then
            db:set_timeout(options.timeout)
        end
        self[options.name or "mysql"] = db

        self.yield()

        if options.max_idle_timeout and options.pool_size then
            db:set_keepalive(options.max_idle_timeout, options.pool_size)
        else
            db:close()
        end
    end
end
