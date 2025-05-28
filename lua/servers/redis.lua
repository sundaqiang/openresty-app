local redis = require "resty.redis"

local function validate_options(options)
    if not (options and options.host) then
        return false, "缺少所需的Redis配置字段"
    end
    if options.host == "" then
        return false, "Redis配置字段不能为空"
    end
    return true
end

return function(self)
    local route = self.route
    local options = self.conf.redis

    -- 校验配置有效性
    local is_valid, err_message = validate_options(options)
    if not is_valid then
        self.log:warn("redis: ", err_message, options)
        return
    end

    -- 工厂函数，返回已连接的 redis client 实例
    self["redis"] = function(custom_options)
        -- 避免重复创建实例（可选）
        if type(self["__redis"]) == "table" then
            return self["__redis"]
        end

        local opt = custom_options or options

        local rdb, err = redis:new()
        if not rdb then return route:fail(err, 503) end

        local ok, err = rdb:connect(opt.host, opt.port or 6379)
        if not ok then return route:fail(err, 503) end

        if opt.timeout and opt.timeout > 0 then rdb:set_timeout(opt.timeout) end

        if opt.password and opt.password ~= "" then
            ok, err = rdb:auth(opt.password)
            if not ok then return route:fail(err, 503) end
        end

        if opt.database and opt.database > 0 then
            ok, err = rdb:select(opt.database)
            if not ok then return route:fail(err, 503) end
        end

        -- 保存实例以便复用；你也可以每次新建，看具体业务需求
        self["__redis"] = rdb
        return rdb
    end

    -- 用cleanup注册资源释放，优雅兼容不同OpenResty版本：
    local cleanup_fn = function()
        if self["__redis"] then
            if options.max_idle_timeout and options.pool_size and options.max_idle_timeout > 0 and options.pool_size > 0 then
                pcall(function()
                    self.log:info("redis: set_keepalive")
                    self["__redis"]:set_keepalive(options.max_idle_timeout, options.pool_size)
                end)
            else
                pcall(function()
                    self.log:info("redis: close")
                    self["__redis"]:close()
                end)
            end
            self["__redis"] = nil
        end
    end

    -- 优先使用 ngx.on_cleanup（OpenResty >= 1.21），否则 fallback 到 log_by_lua*
    if ngx.on_cleanup then
        local ok, err = ngx.on_cleanup(cleanup_fn)
        if not ok then self.log:error("failed to register cleanup for redis:", err) end
    else
        ngx.ctx._finalizers = ngx.ctx._finalizers or {}
        table.insert(ngx.ctx._finalizers, cleanup_fn)
    end

end
