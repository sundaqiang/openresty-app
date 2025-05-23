local route = require("resty.route").new()

local deps = {}

local middleware = require("middleware.main").new(deps)

middleware:add_middlewares_to(route)

route:get("=/", require("controllers.home").index)

return route
