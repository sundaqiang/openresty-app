local mlcache = require "resty.mlcache"

return function(self)
    local route = self.route

    local options = self.conf.cache

    if not (options.name and options.shm_name) then
        self.yield()
    else
        local lru, err = mlcache.new(
                options.name,
                options.shm_name,
                {
                    lru_size       = options.lru_size      or 5e5,     -- L1本地LRU缓存容量（整数），默认100
                    ttl            = options.ttl           or 900,     -- 正常缓存有效期(秒)
                    neg_ttl        = options.neg_ttl       or 300,     -- 未命中缓存有效期(秒)，默认nil（不缓存miss）
                    resurrect_ttl  = options.resurrect_ttl or 30,     -- 复活过期数据的时间窗，默认nil
                    shm_set_tries  = options.shm_set_tries or 3,       -- shm set()重试次数，默认3
                    shm_miss = options.shm_name .. "_miss",
                    shm_locks = options.shm_name .. "_locks",
                    ipc_shm = options.shm_name,
                }
        )
        if not lru then
            return route:fail(err, 503)
        end

        --- Redis fetcher: 支持字符串key，按需可扩展hget/json等方式。
        local function fetch_from_redis(key)
            local redis_name = self.conf.redis.name or "redis"
            local redis_obj = self[redis_name]

            self.log:info("redis fetcher: key="..key)
            self.log:info("redis fetcher: redis_name="..redis_name)

            if not redis_obj then
                -- 不回源，不报错，只是L3 miss
                return nil   -- 注意不要返回第二个参数err
            end
            local val, err = redis_obj:get(key)
            if val == ngx.null then val=nil end
            return val, err
        end

        self[options.name or "lru"] = setmetatable({}, {
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
    end
end
