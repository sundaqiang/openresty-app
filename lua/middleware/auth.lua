local _M = {}

function _M.auth()
    local token = ngx.req.get_headers()["Authorization"]
    if not token or token ~= "Bearer my-secret-token" then
        ngx.status = 401
        ngx.say("Unauthorized")
        ngx.exit(401)
    end
end

return _M
