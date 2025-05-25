

return function(self)
    self.headers = ngx.req.get_headers()
    self.real_ip = self.headers["X-Forwarded-For"] or self.headers["X-Real-IP"] or ngx.var.remote_addr

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
end
