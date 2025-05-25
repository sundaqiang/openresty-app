local cjson = require("cjson")

local _M = {}

function _M.index(self)
    -- 获取项目的配置      self.conf
    -- 打印日志             self.log:info("打印日志", {data = ""})

    -- 获取请求数据       self.get
    -- 获取请求数据       self.post
    -- 获取上传文件数据     self.files

    -- 创建验证器实例       self.verify.new{}
    -- 验证请求参数       self.get:check(schema)

    -- 获取mysql连接    self.db
    -- 获取redis连接    self.rdb
    -- 获取lru缓存      self.lru

    -- 返回json数据     self:json({})
    -- 返回html     self:render(content, context)
    -- 结束路由运行     self.done()

    local schema = self.verify.new {
        username = self.verify.string:len(5, 200), -- 字符串，长度在 5 到 20 之间
        age = self.verify.tonumber:min(18):max(100), -- 转换为数字，值在 18 到 100 之间
        email = self.verify.string:email(), -- 验证是否是合法的 Email 格式
    }

    local valid, fields, errors = self.post:check(schema)

    self:json({
        get = self.get,
        post = self.post,
        files = self.files,
        valid = valid,
        fields = fields,
        errors = errors,
        headers = self.headers,
        real_ip = self.real_ip,
        qqwry = self.qqwry,
    })

    self.done()



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
