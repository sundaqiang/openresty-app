local template = require("resty.template")
template.caching(false) -- 开发时关闭缓存

-- 加载配置
require("app.config")
