local conf = require("utils.config")
local route = require("resty.route").new()

local svcs = {
    c = conf,
    l = require("utils.logger")
}

local middleware = require("middleware.main").new(svcs)

middleware:add_middlewares_to(route)

route:get("=/", require("controllers.home").index)

return route
