local redis = require "resty.redis"

-- 配置验证函数：检查必需字段是否有效（非 nil 且非空字符串）
local function validate_options(options)
    if not (options.name and options.host) then
        return false, "缺少所需的Redis配置字段"
    end

    if options.name == "" or options.host == "" then
        return false, "Redis配置字段不能为空"
    end

    return true
end

return function(self)
    local route = self.route

    -- 获取 Redis 配置选项并输出日志以供调试
    local options = self.conf.redis

    -- 验证 Redis 配置选项是否齐全且有效
    local is_valid, err_message = validate_options(options)

    if not is_valid then
        -- 如果配置无效，记录日志并退出初始化逻辑
        -- self.log:info("redis: ", err_message, options)
        self.yield()
        return  -- 确保后续代码不会执行
    end

    -- self.log:info("redis: ", options)

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

    if options.database > 0 then
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
