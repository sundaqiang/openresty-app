local route = require("resty.route").new()

local deps = {
}

-- local app = require("middleware.main").new(deps)

-- app:add_middlewares_to(route)

route:get("=/", require("controllers.home").index)

return route
