local cjson = require("cjson")

local _M = {}

function _M.index(self)
    -- 获取项目的配置      self.conf
    -- 打印日志             self.log:info("打印日志", {data = ""})
    -- 获取请求trace_id     self.trace_id

    -- 获取请求数据       self.get
    -- 获取请求数据       self.post
    -- 获取上传文件数据     self.files

    -- 创建验证器实例       self.verify.new{}
    -- 验证请求参数       self.get:check(schema)

    -- 获取mysql连接    db = self.mysql(); db:query()
    -- 获取redis连接    rdb = self.redis(); rdb:get()
    -- 获取lru缓存      lru = self.cache(); lru:get()

    -- 返回json数据     self:json({})
    -- 返回html     self:render(content, context)
    -- 结束路由运行     self.done()

    self.log:info("index", {
        trace_id = self.trace_id,
    })

    local schema = self.verify.new {
        username = self.verify.string:len(5, 200), -- 字符串，长度在 5 到 20 之间
        age = self.verify.tonumber:min(18):max(100), -- 转换为数字，值在 18 到 100 之间
        email = self.verify.string:email(), -- 验证是否是合法的 Email 格式
    }

    local valid, fields, errors = self.post:check(schema)

    -- 启动“协程线程”
    local th1 = ngx.thread.spawn(function()
        local db = self.mysql()
        return db:query("SELECT * FROM `store`.`open_api` LIMIT 0,1000")
    end)

    local th2 = ngx.thread.spawn(function()
        local rdb = self.redis()
        return rdb:get("sub:mch:config:1649057105")
    end)

    local th3 = ngx.thread.spawn(function()
        local lru = self.cache()
        return lru:get("sub:mch:config:1649057105")
    end)

    -- 等待两个结果
    local ok1, res1, err1, errcode, sqlstate = ngx.thread.wait(th1)
    local ok2, res2, err2 = ngx.thread.wait(th2)
    local ok3, res3, err3 = ngx.thread.wait(th3)

    local risk = self.risk(true, false, true)


    self:json({
        get = self.get,
        post = self.post,
        files = self.files,
        valid = valid,
        fields = fields,
        errors = errors,
        headers = risk.headers,
        real_ip = risk.real_ip,
        qqwry = risk.qqwry,
        ip2location = risk.ip2location,
        ip2proxy = risk.ip2proxy,
        res1 = res1,
        err1 = err1,
        res2 = res2,
        err2 = err2,
        res3 = res3,
        err3 = err3,
    })

    self.done()
end

return _M
