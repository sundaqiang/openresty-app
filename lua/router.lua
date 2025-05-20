local router = {
    GET = {
        ["/"] = require("app.controllers.main").index,
        ["/api/data"] = require("app.controllers.api").get_data
    },
    POST = {
        ["/api/submit"] = require("app.controllers.api").post_data
    }
}

return {
    route = function()
        local method = ngx.req.get_method()
        local path = ngx.var.uri
        local handler = router[method] and router[method][path]

        if handler then
            -- 中间件执行（如鉴权）
            require("middleware.auth")()
            handler()
        else
            ngx.status = 404
            ngx.say("404 Not Found")
        end
    end
}
