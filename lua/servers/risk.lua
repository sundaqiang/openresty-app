

return function(self)
    self.headers = ngx.req.get_headers()
    self.real_ip = self.headers["X-Forwarded-For"] or self.headers["X-Real-IP"] or ngx.var.remote_addr

    self.real_ip = "118.178.196.163"

    if qqwry then
        local res, err = qqwry:lookup(self.real_ip)
        if err then
            self.log.warn("qqwry error", {
                ip = self.real_ip,
                err = err,
            })
        else
            self.qqwry = res
        end
    end

    if ip2location then
        local res = ip2location:get_all(self.real_ip)
        if not res then
            self.log.warn("ip2location error", {
                ip = self.real_ip,
            })
        else
            self.ip2location = res
        end
    end

    if ip2proxy then
        local res = ip2proxy:get_all(self.real_ip)
        if not res then
            self.log.warn("ip2proxy error", {
                ip = self.real_ip,
            })
        else
            self.ip2proxy = res
        end
    end
end
