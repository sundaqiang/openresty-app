-- init每个worker都会执行一次，不知道库会不会重复加载，之后在看要不要用lua_shared_dict

local ffi = require("ffi")
local bit = require("bit")

-- macOS 实际 dlopen 标志值
ffi.cdef[[
static const int RTLD_LAZY   = 0x1;
static const int RTLD_GLOBAL = 0x8;
void* dlopen(const char *filename, int flags);
void* dlsym(void *handle, const char *symbol);
char* dlerror(void);
]]

-- 固定 libiconv 路径
local lib_path = "/opt/homebrew/opt/libiconv/lib/libiconv.dylib"

-- 加载库并设置全局标志
local handle = ffi.C.dlopen(lib_path, bit.bor(ffi.C.RTLD_LAZY, ffi.C.RTLD_GLOBAL))
if handle == nil then
    ngx.log(ngx.ERR, "dlopen 失败: ", ffi.string(ffi.C.dlerror()))
end

-- 验证符号是否存在
local iconv_open_ptr = ffi.C.dlsym(handle, "iconv_open")
if iconv_open_ptr == nil then
    ngx.log(ngx.ERR, "dlsym(iconv_open) 失败: ", ffi.string(ffi.C.dlerror()))
end

ffi.cdef[[
struct in_addr {
  uint32_t s_addr;
};

int inet_aton(const char *cp, struct in_addr *inp);
uint32_t ntohl(uint32_t netlong);

typedef void *iconv_t;
iconv_t iconv_open (const char *__tocode, const char *__fromcode);
size_t iconv (
  iconv_t __cd,
  char ** __inbuf, size_t * __inbytesleft,
  char ** __outbuf, size_t * __outbytesleft
);
int iconv_close (iconv_t __cd);
]]

-- 验证全局符号是否可见（关键步骤）
local test_cd = ffi.C.iconv_open("UTF-8", "UTF-8")
if test_cd == ffi.cast("iconv_t", -1) then
    ngx.log(ngx.ERR, "iconv_open 自检失败，请检查库路径和权限")
else
    ffi.C.iconv_close(test_cd)
    ngx.log(ngx.INFO, "libiconv 全局加载成功")
end


local conf = require("servers.config")

if conf.risk then
    if conf.risk.cz and conf.risk.cz == true then
        local cz = require ('resty.qqwry')
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
