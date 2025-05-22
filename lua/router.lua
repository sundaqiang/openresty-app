-- lua/router.lua
local _M = {}

-- 路由结构优化（将API路由作为根节点的子路由）
local routes = {
    {
        path = "/",
        methods = { GET = "app.controllers.main.index" },
        middlewares = {"root_middleware"},  -- 根路由中间件示例
        children = {
            {
                path = "api",
                middlewares = {"api_middleware"},
                children = {
                    { path = "data", methods = { GET = "app.controllers.api.get_data" } },
                    { path = "info", methods = { GET = "app.controllers.api.get_info" } },
                    {
                        path = "submit",
                        methods = { POST = "app.controllers.api.post_data" },
                        middlewares = {"submit_middleware"}
                    }
                }
            }
        }
    }
}

-- 路径分割优化（统一处理首尾斜杠）
local function split_path(path)
    path = path:gsub("^/", ""):gsub("/$", "")
    return path == "" and {} or { string.match(path, "([^/]+)") }
end

-- 路由节点匹配器（支持多级路径匹配）
local function find_matching_nodes(nodes, part)
    local matches = {}
    for _, current in ipairs(nodes) do
        if current.node.children then
            for _, child in ipairs(current.node.children) do
                local child_part = child.path:gsub("^/", "")
                if child_part == part then
                    table.insert(matches, {
                        node = child,
                        path = current.path .. (current.path == "/" and "" or "/") .. child_part
                    })
                end
            end
        end
    end
    return matches
end

-- 中间件加载器（通用模块加载）
local function load_module(name)
    local ok, mod = pcall(require, name)
    if not ok then
        ngx.log(ngx.ERR, "Module load failed: ", name)
        return nil
    end
    return mod
end

-- 路由匹配主逻辑
local function match_route(method, path)
    local parts = split_path(path)
    local nodes = { { node = routes[1], path = "/" } }  -- 从根节点开始
    local middlewares = {}

    for i, part in ipairs(parts) do
        nodes = find_matching_nodes(nodes, part)
        if #nodes == 0 then break end

        -- 收集当前层级的中间件
        for _, node in ipairs(nodes) do
            if node.node.middlewares then
                for _, mw in ipairs(node.node.middlewares) do
                    table.insert(middlewares, mw)
                end
            end
        end
    end

    -- 精确匹配验证
    local final_node
    for _, node in ipairs(nodes) do
        if node.path:lower() == path:lower() then
            final_node = node.node
            break
        end
    end

    return final_node and final_node.methods[method], middlewares
end

-- 中间件执行器（迭代方式）
local function execute_middlewares(middlewares, handler)
    local index = 1
    local function next()
        index = index + 1
        if middlewares[index] then
            middlewares[index](next)
        else
            handler()
        end
    end
    if middlewares[1] then
        middlewares[1](next)
    else
        handler()
    end
end

function _M.route()
    local method = ngx.req.get_method()
    local path = ngx.var.uri:match("(.-)/?$")  -- 统一处理结尾斜杠

    -- 路由匹配
    local handler_path, middlewares = match_route(method, path)
    if not handler_path then
        ngx.status = 404
        return ngx.say("404 Not Found")
    end

    -- 加载处理器
    local handler = load_module(handler_path:match("(.+)%..+$"))
    local handler_func = handler and handler[handler_path:match("[^.]+$")]
    if not handler_func then
        ngx.log(ngx.ERR, "Handler load failed: ", handler_path)
        ngx.exit(500)
    end

    -- 加载中间件
    local loaded_mws = {}
    for _, mw_path in ipairs(middlewares) do
        local mw = load_module(mw_path)
        if mw then table.insert(loaded_mws, mw) end
    end

    -- 执行处理链
    execute_middlewares(loaded_mws, handler_func)
end

return _M
