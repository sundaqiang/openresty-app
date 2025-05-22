local template = require("resty.template")
template.caching(false) -- 开发时关闭缓存

local conf = require("conf.config")
local log = require ("extend.logger")
local logger

local function log_once_by_pid(l, c)
    local pid_file = "logs/nginx.pid"
    local last_file = "logs/last_nginx.pid"

    -- 读取 nginx 当前 PID
    local pf = io.open(pid_file, "r")
    if not pf then return end
    local pid = pf:read("*l")
    pf:close()
    if not pid then return end

    -- 读取上次记录的 PID
    local mf = io.open(last_file, "r")
    local last = mf and mf:read("*l") or nil
    if mf then mf:close() end

    -- 已经记录过本次启动，不再重复
    if last == pid then return end

    -- 打印初始化日志
    l.i("OpenResty 启动，配置加载成功", c)

    -- 写入这次的 PID
    local wf = io.open(last_file, "w")
    if wf then wf:write(pid); wf:close() end
end

if conf.log_type == "file" then
    logger = log.file(conf.log)
    log_once_by_pid(logger, conf)
else
    logger = log.console(conf.log)
    logger.i("OpenResty 启动，配置加载成功", conf)
end
