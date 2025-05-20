local template = require("resty.template")
local config = require("app.config")

local _M = {}

function _M.index()
    -- 渲染模板并传递数据
    local view = template.new("layout.html", "index.html")
    view.title = "OpenResty Starter"
    view.data = {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        env = config.env
    }
    view:render()
end

return _M
