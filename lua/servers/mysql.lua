local mysql = require "resty.mysql"

-- 配置验证函数：检查必需字段是否有效
local function validate_options(options)
    if not (options and options.host and options.database and options.user) then
        return false, "缺少所需的MySQL配置字段"
    end
    if options.host == "" or options.database == "" or options.user == "" then
        return false, "MySQL配置字段不能为空"
    end
    return true
end

return function(self)
    local route = self.route
    local options = self.conf.mysql

    -- 工厂函数，返回已连接的 mysql client 实例（可支持 custom_options）
    self["mysql"] = function(custom_options)
        if type(self["__mysql"]) == "table" then
            return self["__mysql"]
        end

        -- 验证选项有效性
        local opt = custom_options or options
        local is_valid, err_message = validate_options(opt)
        if not is_valid then
            self.log:warn("mysql", err_message, opt)
            return nil -- 或者 route:fail(err_message, 503)
        end

        local db, err = mysql:new()
        if not db then return route:fail(err, 503) end

        if opt.timeout and opt.timeout > 0 then db:set_timeout(opt.timeout) end

        local ok, conn_err, errcode, sqlstate = db:connect{
            host            = opt.host,
            port            = opt.port or 3306,
            database        = opt.database,
            user            = opt.user,
            password        = opt.password or "",
            charset         = opt.charset or "utf8mb4",
            max_packet_size = opt.max_packet_size or (1024 * 1024),
        }
        if not ok then return route:fail(conn_err, 503) end

        self["__mysql"] = db -- 保存实例以便复用（本请求内）

        return db
    end

    -- 自动资源释放钩子（推荐 on_cleanup，兼容旧OpenResty就 log_by_lua*）
    local cleanup_fn = function()
        if self["__mysql"] then
            if options.max_idle_timeout and options.pool_size and options.max_idle_timeout>0 and options.pool_size>0 then
                pcall(function()
                    -- self.log:info("mysql: set_keepalive")
                    self["__mysql"]:set_keepalive(options.max_idle_timeout, options.pool_size)
                end)
            else
                pcall(function()
                    -- self.log:info("mysql: close")
                    self["__mysql"]:close()
                end)
            end
            self["__mysql"] = nil -- 防止内存泄漏或脏数据残留！
        end
    end

    if ngx.on_cleanup then
        local ok, err = ngx.on_cleanup(cleanup_fn)
        if not ok then self.log:error("failed to register cleanup for mysql:", err) end
    else
        ngx.ctx._finalizers = ngx.ctx._finalizers or {}
        table.insert(ngx.ctx._finalizers, cleanup_fn)
    end

end
