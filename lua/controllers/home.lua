local cjson = require("cjson")

local _M = {}

function _M.index(self)
    local rdbs, err = self.rdb:get("sub:mch:config:1649057105")

    local res, err, errcode, sqlstate =
    self.db:query("SELECT * FROM `store`.`open_api` LIMIT 0,1000")

    ngx.say(cjson.encode({
        data = self.svcs.c,
        res = res,
        rdbs = rdbs,
    }))
    ngx.exit(ngx.OK)
end

return _M
