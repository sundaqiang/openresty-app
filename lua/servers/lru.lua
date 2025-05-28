local mlcache = require "resty.mlcache"

-- 配置验证函数
local function validate_options(options)
    if not (options and options.name and options.shm_name) then
        return false, "缺少所需的Cache配置字段"
    end
    if options.name == "" or options.shm_name == "" then
        return false, "Cache配置字段不能为空"
    end
    return true
end

return function(self)
    local route = self.route
    local options = self.conf.cache

    -- 校验配置有效性
    local is_valid, err_message = validate_options(options)
    if not is_valid then
        self.log:warn("cache: ", err_message, options)
        return
    end

    -- 工厂函数，返回已初始化的 mlcache 实例（支持 custom_options）
    self["cache"] = function(custom_options)
        if type(self["__cache"]) == "table" then
            return self["__cache"]
        end

        local opt = custom_options or options

        local lru, err = mlcache.new(
                opt.name,
                opt.shm_name,
                {
                    lru_size       = opt.lru_size      or 5e5,
                    ttl            = opt.ttl           or 900,
                    neg_ttl        = opt.neg_ttl       or 300,
                    resurrect_ttl  = opt.resurrect_ttl or 30,
                    shm_set_tries  = opt.shm_set_tries or 3,
                    shm_miss       = opt.shm_name .. "_miss",
                    shm_locks      = opt.shm_name .. "_locks",
                    ipc_shm        = opt.shm_name,
                }
        )
        if not lru then return route:fail(err, 503) end

        -- 默认的 Redis 回源 fetcher，可自定义覆盖
        local function fetch_from_redis(key)
            local redis = type(self["redis"])=="function" and self["redis"]() or nil
            if not redis then return nil end
            local val, err = redis:get(key)
            if val == ngx.null then val=nil end
            return val, err
        end

        -- 包一层 proxy，兼容 get/fetch等API，并可默认回源到Redis
        local proxy = setmetatable({}, {
            __index=function(_, k)
                if k == "get" then
                    return function(_, key, opts, fetcher,...)
                        if type(opts) == "function" or opts == nil then fetcher, opts=opts,nil end
                        fetcher=fetcher or fetch_from_redis   --- 默认走redis回源！
                        return lru:get(key, opts, fetcher,key,...)
                    end
                else
                    return lru[k]
                end
            end,
            __tostring=function() return "<mlcache+redis>" end,
        })

        self["__cache"] = proxy -- 缓存实例避免重复创建

        return proxy
    end
end
