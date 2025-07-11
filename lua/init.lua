local conf = require("servers.config")

if conf.risk then
    if conf.risk.cz and conf.risk.cz == true then
        local cz = require ('utils.qqwry_mac')
        qqwry = cz.init('ipdb/qqwry.dat')
    end

    if conf.risk.location and conf.risk.location == true then
        local ip2l = require('ip2location')
        ip2location = ip2l:new('ipdb/IP2LOCATION-LITE-DB3.BIN')
    end

    if conf.risk.proxy and conf.risk.proxy == true then
        local ip2p = require('ip2proxy')
        ip2proxy = ip2p:open('ipdb/IP2PROXY-LITE-PX3.BIN')
    end
end
