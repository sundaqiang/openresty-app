local mysql = require "resty.mysql"

-- 配置验证函数：检查必需字段是否有效（非 nil 且非空字符串）
local function validate_options(options)
    if not (options.name and options.host and options.database and options.user) then
        return false, "缺少所需的MySQL配置字段"
    end

    if options.name == "" or
            options.host == "" or
            options.database == "" or
            options.user == "" then
        return false, "MySQL配置字段不能为空"
    end

    return true
end

return function(self)
    local route = self.route

    -- 获取 MySQL 配置选项并输出日志以供调试
    local options = self.conf.mysql

    -- 验证 MySQL 配置选项是否齐全且有效
    local is_valid, err_message = validate_options(options)

    if not is_valid then
        -- 如果配置无效，记录日志并退出初始化逻辑
        self.log:info("mysql: ", err_message, options)
        self.yield()
        return  -- 确保后续代码不会执行
    end

    self.log:info("mysql: ", options)

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
