--[[
Copyright (c) axpwx<axpwx08@gmail.com>

@url:     https://github.com/axpwx/lua-resty-qqwry
@author:  axpwx
@version: 0.01
@license: MIT License
--]]

local _M         = {_VERSION = '0.01'}
local mt         = { __index = _M }
local ngx        = ngx
local math       = math
local string     = string
local error      = error
local assert     = assert
local floor      = math.floor
local byte       = string.byte
local tonumber   = tonumber
local set_mt     = setmetatable
local io_open    = io.open
local iconv = require "resty.iconv"

local cd = iconv:new("UTF-8", "GBK")

if not cd then
  return ngx.log(ngx.ERR, "qqwry:init() can only be called in init phase")
end

-- 模拟文件IO
local sim_io   = {}
sim_io.__index = sim_io

function sim_io:new(content)
  local obj = {
    content = content,
    position = 1
  }
  set_mt(obj, sim_io)

  return obj
end

function sim_io:read(num_bytes)
  local start_pos = self.position
  local end_pos   = start_pos + num_bytes - 1
  self.position   = end_pos + 1

  return self.content:sub(start_pos, end_pos)
end

function sim_io:seek(whence, offset)
  whence = whence or 'cur'
  offset = offset or 0

  if whence == 'set' then
    self.position = 1 + offset
  elseif whence == 'cur' then
    self.position = self.position + offset
  elseif whence == 'end' then
    self.position = #self.content + 1 + offset
  else
    error('Invalid seek mode')
  end

  if self.position < 1 then
    self.position = 1
  elseif self.position > #self.content + 1 then
    self.position = #self.content + 1
  end

  return self.position - 1
end

local function bin2big(s)
  if s == nil then return nil end
  local r = 0
  local len = #s
  for i = len, 1, -1 do
    r = r + byte(s, i) * 256 ^ (i - 1)
  end

  return r
end

local function ip2long(ip)
  if type(ip) ~= "string" then return nil end
  local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  a, b, c, d = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
  if not (a and b and c and d) then return nil end
  if a < 0 or a > 255 or b < 0 or b > 255 or c < 0 or c > 255 or d < 0 or d > 255 then return nil end
  return a * 16777216 + b * 65536 + c * 256 + d
end

-- copy from https://github.com/lancelijade/qqwry.lua/blob/b1aebeaad204f6277e3f35f0d8c0547c1e80e967/qqwry.lua#L57
-- Copyright (C) 2011, Lance Li <lancelijade@gmail.com>.
-- with the BSD license.
-- locate absolute ip info offset from index area
local function locateIpIndex(qqwry, ip, offset1, offset2)
  local curIp, offset, nextIp
  local m = floor((offset2 - offset1) / 7 / 2) * 7 + offset1
  qqwry:seek('set', m)

  local count = 0
  while offset == nil do
    curIp  = bin2big(qqwry:read(4))
    offset = bin2big(qqwry:read(3))
    nextIp = bin2big(qqwry:read(4))
    if nextIp == nil then nextIp = 2 ^ 32 end
    if curIp <= ip and ip < nextIp then
      break
    elseif ip < curIp then
      offset2 = m
    else
      offset1 = m + 7
    end
    m = floor((offset2 - offset1) / 7 / 2) * 7 + offset1
    qqwry:seek('set', m)
    offset = nil
    count = count + 1
    if count > 200 then break end
  end
  if count > 200 then return nil end

  return offset
end

-- copy from https://github.com/lancelijade/qqwry.lua/blob/b1aebeaad204f6277e3f35f0d8c0547c1e80e967/qqwry.lua#L87
-- Copyright (C) 2011, Lance Li <lancelijade@gmail.com>.
-- with the BSD license.
-- get location info from given offset
-- param  offset, offset for return (if not set offsetR, the function will return current pos)
-- return location offset, next location info offset
local function getOffsetLoc(qqwry, offset, offsetR)
  local loc = ''
  qqwry:seek('set', offset)
  local form = qqwry:read(1)

  if form ~= '\1' and form ~= '\2' then
    qqwry:seek('set', offset)
    local b = qqwry:read(1)
    while b ~= nil and b ~= '\0' do
      loc = loc .. b
      b = qqwry:read(1)
    end
    if offsetR ~= nil then
      return loc, offsetR
    else
      return loc, qqwry:seek()
    end
  else
    local offsetNew = bin2big(qqwry:read(3))
    if form == '\2' then
      return getOffsetLoc(qqwry, offsetNew, offset + 4)
    else
      return getOffsetLoc(qqwry, offsetNew)
    end
  end
end

function _M.init(db_path)
  if ngx.get_phase() ~= 'init' then error('init function should be called in init phase') end
  local self = {qqwry = nil}
  local f = assert(io_open(db_path, 'rb'))
  self.qqwry = sim_io:new(f:read('*all'))
  f:close()

  set_mt(self, mt)

  return self
end

function _M.lookup(self, ip)
  self.qqwry:seek('set', 0)
  local offset = locateIpIndex(self.qqwry, ip2long(ip), bin2big(self.qqwry:read(4)), bin2big(self.qqwry:read(4)))
  if offset == nil then return nil, 'not found' end

  local loc1, loc2
  loc1, offset = getOffsetLoc(self.qqwry, offset + 4)
  loc2 = offset and getOffsetLoc(self.qqwry, offset) or ''

  _, loc1 = cd:convert(loc1)
  _, loc2 = cd:convert(loc2)

  return {
    region = loc1,
    isp    = loc2
  }
end

return _M
