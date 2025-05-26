local base        = require("resty.core.base")
local bit         = require("bit")
local clear_tab   = require("table.clear")
local nkeys       = require("table.nkeys")
local new_tab     = base.new_tab
local find_str    = string.find
local tonumber    = tonumber
local ipairs      = ipairs
local pairs       = pairs
local ffi         = require "ffi"
local ffi_cdef    = ffi.cdef
local insert_tab  = table.insert
local sort_tab    = table.sort
local string      = string
local setmetatable=setmetatable
local type        = type
local error       = error
local str_sub     = string.sub
local cur_level   = ngx.config.subsystem == "http" and
                    require "ngx.errlog" .get_sys_filter_level()

local AF_INET6    = 10
if ffi.os == "OSX" then
    AF_INET6 = 30
end


local _M = {_VERSION = 0.31}


ffi_cdef[[
    int inet_pton(int af, const char * restrict src, void * restrict dst);
    uint32_t ntohl(uint32_t netlong);
]]


local function parse_ipv4(ip)
    if not ip then return false end
    local a,b,c,d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if not (a and b and c and d) then return false end
    if a < 0 or a > 255 or b < 0 or b > 255 or c < 0 or c > 255 or d < 0 or d > 255 then
        return false
    end
    -- 高字节在前（网络序）
    return bit.bor(
            bit.lshift(a,24),
            bit.lshift(b,16),
            bit.lshift(c,8),
            d
    )
end

_M.parse_ipv4 = parse_ipv4

local function parse_bin_ipv4(ip)
    if not ip or #ip ~= 4 then return false end
    local a, b, c, d = ip:byte(1,4)
    return bit.bor(
            bit.lshift(a,24),
            bit.lshift(b,16),
            bit.lshift(c,8),
            d
    )
end

-- 返回长度为16的字节数组，或false
local function ipv6_to_bytes(ip)
    -- 去掉方括号
    if ip:sub(1,1) == "[" and ip:sub(-1,-1) == "]" then
        ip = ip:sub(2,-2)
    end

    -- ::缩写展开处理
    local parts = {}
    local double_colon_pos = ip:find("::",1,true)
    if double_colon_pos then
        -- 分成两段，各自split(':')
        local left = ip:sub(1,double_colon_pos-1)
        local right = ip:sub(double_colon_pos+2)
        for part in left:gmatch("[^:]+") do table.insert(parts, part) end
        local missing = 8 - (#parts + select(2,right:gsub(":", "")) + (right~="" and 1 or 0))
        for i=1,missing do table.insert(parts,"0") end
        for part in right:gmatch("[^:]+") do table.insert(parts, part) end
    else
        for part in ip:gmatch("[^:]+") do table.insert(parts, part) end
    end

    -- 支持尾部嵌入式IPv4地址，如 ::ffff:192.168.0.1
    if #parts > 0 and parts[#parts]:find("%.") then
        local ipv4bytes = {parts[#parts]:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")}
        if #ipv4bytes == 4 then
            parts[#parts] = string.format("%02x%02x", ipv4bytes[1], ipv4bytes[2])
            table.insert(parts,string.format("%02x%02x", ipv4bytes[3], ipv4bytes[4]))
        else
            return false   -- 非法嵌入式IPv4格式
        end
    end

    if #parts ~=8 then return false end

    local bytes = {}
    for i=1,8 do
        local word = tonumber(parts[i],16)
        if not word or word<0 or word>0xffff then return false end
        table.insert(bytes, math.floor(word/256))
        table.insert(bytes, word %256)
    end

    return bytes   -- 返回长度为16的字节数组，每个元素是0~255整数
end

-- 转换为四个uint32（与原C代码一致）
local function parse_ipv6(ip)
    local bytes = ipv6_to_bytes(ip)
    if not bytes then return false end

    local arr = {}
    for i=0,3 do -- 每32位一个整数，高位在前（网络序）
        arr[i+1] =
        bit.bor(
                bit.lshift(bytes[i*4+1],24),
                bit.lshift(bytes[i*4+2],16),
                bit.lshift(bytes[i*4+3],8),
                bytes[i*4+4]
        )
    end
    return arr -- 长度为4的数字数组，每个都是uint32（高位在前）
end

-- 二进制版，直接取字节拼装即可：
local function parse_bin_ipv6(bin)
    if type(bin)=="string" and #bin==16 then
        local arr={}
        for i=0,3 do
            arr[i+1]=bit.bor(
                    bit.lshift(bin:byte(i*4+1),24),
                    bit.lshift(bin:byte(i*4+2),16),
                    bit.lshift(bin:byte(i*4+3),8),
                    bin:byte(i*4+4)
            )
        end
        return arr
    else
        return false
    end
end

_M.parse_ipv6 = parse_ipv6

local mt = {__index = _M}


local ngx_log = ngx.log
local ngx_INFO = ngx.INFO
local function log_info(...)
    if cur_level and ngx_INFO > cur_level then
        return
    end

    return ngx_log(ngx_INFO, ...)
end


local function split_ip(ip_addr_org)
    local idx = find_str(ip_addr_org, "/", 1, true)
    if not idx then
        return ip_addr_org
    end

    local ip_addr = str_sub(ip_addr_org, 1, idx - 1)
    local ip_addr_mask = str_sub(ip_addr_org, idx + 1)
    return ip_addr, tonumber(ip_addr_mask)
end
_M.split_ip = split_ip


local idxs = {}
local function gen_ipv6_idxs(inets_ipv6, mask)
    clear_tab(idxs)

    for _, inet in ipairs(inets_ipv6) do
        local valid_mask = mask
        if valid_mask > 32 then
            valid_mask = 32
        end

        if valid_mask == 32 then
            insert_tab(idxs, inet)
        else
            insert_tab(idxs, bit.rshift(inet, 32 - valid_mask))
        end

        mask = mask - 32
        if mask <= 0 then
            break
        end
    end

    return idxs
end


local function cmp(x, y)
    return x > y
end


local function new(ips, with_value)
    if not ips or type(ips) ~= "table" then
        error("missing valid ip argument", 2)
    end

    local parsed_ipv4s = {}
    local parsed_ipv4s_mask = {}
    local ipv4_match_all_value

    local parsed_ipv6s = {}
    local parsed_ipv6s_mask = {}
    local ipv6_values = {}
    local ipv6s_values_idx = 1
    local ipv6_match_all_value

    local iter = with_value and pairs or ipairs
    for a, b in iter(ips) do
        local ip_addr_org, value
        if with_value then
            ip_addr_org = a
            value = b

        else
            ip_addr_org = b
            value = true
        end

        local ip_addr, ip_addr_mask = split_ip(ip_addr_org)

        local inet_ipv4 = parse_ipv4(ip_addr)
        if inet_ipv4 then
            ip_addr_mask = ip_addr_mask or 32
            if ip_addr_mask == 32 then
                parsed_ipv4s[inet_ipv4] = value

            elseif ip_addr_mask == 0 then
                ipv4_match_all_value = value

            else
                local valid_inet_addr = bit.rshift(inet_ipv4, 32 - ip_addr_mask)

                parsed_ipv4s_mask[ip_addr_mask] = parsed_ipv4s_mask[ip_addr_mask] or {}
                parsed_ipv4s_mask[ip_addr_mask][valid_inet_addr] = value
                log_info("ipv4 mask: ", ip_addr_mask,
                         " valid inet: ", valid_inet_addr)
            end

            goto continue
        end

        local inets_ipv6 = parse_ipv6(ip_addr)
        if inets_ipv6 then
            ip_addr_mask = ip_addr_mask or 128
            if ip_addr_mask == 128 then
                parsed_ipv6s[ip_addr] = value

            elseif ip_addr_mask == 0 then
                ipv6_match_all_value = value
            end

            parsed_ipv6s[ip_addr_mask] = parsed_ipv6s[ip_addr_mask] or {}

            local inets_idxs = gen_ipv6_idxs(inets_ipv6, ip_addr_mask)
            local node = parsed_ipv6s[ip_addr_mask]
            for i, inet in ipairs(inets_idxs) do
                if i == #inets_idxs then
                    if with_value then
                        ipv6_values[ipv6s_values_idx] = value
                        node[inet] = ipv6s_values_idx
                        ipv6s_values_idx = ipv6s_values_idx + 1
                    else
                        node[inet] = true
                    end
                end
                node[inet] = node[inet] or {}
                node = node[inet]
            end

            parsed_ipv6s_mask[ip_addr_mask] = true

            goto continue
        end

        if not inet_ipv4 and not inets_ipv6 then
            return nil, "invalid ip address: " .. ip_addr
        end

        ::continue::
    end

    local ipv4_mask_arr = new_tab(nkeys(parsed_ipv4s_mask), 0)
    local i = 1
    for k, _ in pairs(parsed_ipv4s_mask) do
        ipv4_mask_arr[i] = k
        i = i + 1
    end

    sort_tab(ipv4_mask_arr, cmp)

    local ipv6_mask_arr = new_tab(nkeys(parsed_ipv6s_mask), 0)

    i = 1
    for k, _ in pairs(parsed_ipv6s_mask) do
        ipv6_mask_arr[i] = k
        i = i + 1
    end

    sort_tab(ipv6_mask_arr, cmp)

    return setmetatable({
        ipv4 = parsed_ipv4s,
        ipv4_mask = parsed_ipv4s_mask,
        ipv4_mask_arr = ipv4_mask_arr,
        ipv4_match_all_value = ipv4_match_all_value,

        ipv6 = parsed_ipv6s,
        ipv6_mask = parsed_ipv6s_mask,
        ipv6_mask_arr = ipv6_mask_arr,
        ipv6_values = ipv6_values,
        ipv6_match_all_value = ipv6_match_all_value,
    }, mt)
end

function _M.new(ips)
    return new(ips, false)
end

function _M.new_with_value(ips)
    return new(ips, true)
end


local function match_ipv4(self, ip)
    local ipv4s = self.ipv4
    local value = ipv4s[ip]
    if value ~= nil then
        return value
    end

    local ipv4_mask = self.ipv4_mask
    if self.ipv4_match_all_value ~= nil then
        return self.ipv4_match_all_value -- match any ip
    end

    for _, mask in ipairs(self.ipv4_mask_arr) do
        local valid_inet_addr = bit.rshift(ip, 32 - mask)

        log_info("ipv4 mask: ", mask,
                 " valid inet: ", valid_inet_addr)

        value = ipv4_mask[mask][valid_inet_addr]
        if value ~= nil then
            return value
        end
    end

    return false
end

local function match_ipv6(self, ip)
    local ipv6s = self.ipv6
    if self.ipv6_match_all_value ~= nil then
        return self.ipv6_match_all_value -- match any ip
    end

    for _, mask in ipairs(self.ipv6_mask_arr) do
        local node = ipv6s[mask]
        local inet_idxs = gen_ipv6_idxs(ip, mask)
        for _, inet in ipairs(inet_idxs) do
            if not node[inet] then
                break
            else
                node = node[inet]
                if node == true then
                    return true
                end
                if type(node) == "number" then
                    -- fetch with the ipv6s_values_idx
                    return self.ipv6_values[node]
                end
            end
        end
    end

    return false
end

function _M.match(self, ip)
    local inet_ipv4 = parse_ipv4(ip)
    if inet_ipv4 then
        return match_ipv4(self, inet_ipv4)
    end

    local inets_ipv6 = parse_ipv6(ip)
    if not inets_ipv6 then
        return false, "invalid ip address, not ipv4 and ipv6"
    end

    local ipv6s = self.ipv6
    local value = ipv6s[ip]
    if value ~= nil then
        return value
    end

    return match_ipv6(self, inets_ipv6)
end


function _M.match_bin(self, bin_ip)
    local inet_ipv4 = parse_bin_ipv4(bin_ip)
    if inet_ipv4 then
        return match_ipv4(self, inet_ipv4)
    end

    local inets_ipv6 = parse_bin_ipv6(bin_ip)
    if not inets_ipv6 then
        return false, "invalid ip address, not ipv4 and ipv6"
    end

    return match_ipv6(self, inets_ipv6)
end


return _M
