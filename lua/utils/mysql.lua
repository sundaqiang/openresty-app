local mysql = require "resty.mysql"

return function(self)
    local route = self.route

    local option = self.svcs.c.mysql
    if not (option.name and option.host and option.database and option.user) then
        self.yield()
    else
        local db, err = mysql:new()
        if not db then
            return route:fail(err, 503)
        end

        local ok, err, errcode, sqlstate = db:connect{
            host = option.host or "127.0.0.1",
            port = option.port or 3306,
            database = option.database or "",
            user = option.user or "root",
            password = option.password or "",
            charset = option.charset or "utf8mb4",
            max_packet_size = option.max_packet_size or 1024 * 1024,
        }
        if not ok then
            return route:fail(err, 503)
        end

        if option.timeout then
            db:set_timeout(option.timeout)
        end
        self[option.name or "mysql"] = db

        self.yield()

        if option.max_idle_timeout and option.pool_size then
            db:set_keepalive(option.max_idle_timeout, option.pool_size)
        else
            db:close()
        end
    end
end
