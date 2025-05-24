local cjson = require("cjson")

local _M = {}

function _M.index(self)
    -- 获取项目的配置      self.conf
    -- 打印日志         self.log:info("打印日志", {data = ""})
    -- 获取mysql连接    self.db
    -- 获取redis连接    self.rdb
    -- 获取lru缓存      self.lru
    local lru, err1 = self.lru:get("sub:mch:config:1649057105")

    local rdb, err2 = self.rdb:get("sub:mch:config:1649057105")

    local res, err3, errcode, sqlstate =
    self.db:query("SELECT * FROM `store`.`open_api` LIMIT 0,1000")

    ngx.say(cjson.encode({
        data = self.conf,
        res = res,
        lru = lru,
        rdb = rdb,
        err1 = err1,
        err2 = err2,
        err3 = err3,
    }))
    ngx.exit(ngx.OK)
end

return _M
