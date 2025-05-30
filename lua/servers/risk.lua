return function(self)
    local keys = {"qqwry", "ip2location", "ip2proxy"}

    self.trace_id = ngx.var.request_id

    self["risk"] = function(...)
        local args = {...}
        local opts = {}
        for i, k in ipairs(keys) do
            opts[k] = args[i] ~= nil and args[i] or false
        end

        local risk = {}

        risk.headers = ngx.req.get_headers()
        risk.real_ip = risk.headers["X-Forwarded-For"] or risk.headers["X-Real-IP"] or ngx.var.remote_addr

        if qqwry and opts.qqwry then
            local res, err = qqwry:lookup(risk.real_ip)
            if err then
                self.log.warn("qqwry error", {
                    ip = risk.real_ip,
                    err = err,
                })
            else
                risk.qqwry = res
            end
        end

        if ip2location and opts.ip2location then
            local res = ip2location:get_all(risk.real_ip)
            if not res then
                self.log.warn("ip2location error", {
                    ip = risk.real_ip,
                })
            else
                risk.ip2location = res
            end
        end

        if ip2proxy and opts.ip2proxy then
            local res = ip2proxy:get_all(risk.real_ip)
            if not res then
                self.log.warn("ip2proxy error", {
                    ip = risk.real_ip,
                })
            else
                risk.ip2proxy = res
            end
        end

        return risk
    end
end
