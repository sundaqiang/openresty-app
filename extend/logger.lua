local _M = {}

local default_format = '${datetime} [${level}] [${trace}] ${msg}'

local bit = require("bit")

local fmt, gsub, rep, date, concat, sort =
string.format, string.gsub, string.rep, os.date, table.concat, table.sort

local levels = {
    STDERR = ngx.STDERR,
    EMERG  = ngx.EMERG,
    ALERT  = ngx.ALERT,
    CRIT   = ngx.CRIT,
    ERR    = ngx.ERR,
    WARN   = ngx.WARN,
    NOTICE = ngx.NOTICE,
    INFO   = ngx.INFO,
    DEBUG  = ngx.DEBUG,
}
_M.levels = levels

local r_levels = {}
for k,v in pairs(levels) do r_levels[v] = k:lower() end

-- 色表统一定义（只留一份）
local colors = {
    BLACK=0, RED=4, GREEN=2, YELLOW=6,
    BLUE=1, MAGENTA=5, CYAN=3, WHITE=7,
    RESET=-1,
}
_M.colors=colors

-- 日志等级对应颜色（小写key）
local lvl_colors={
    stderr=colors.RED, emerg=colors.MAGENTA,
    alert=colors.BLUE, crit=colors.BLUE,
    err=colors.RED, warn=colors.YELLOW,
    notice=colors.CYAN, info=colors.WHITE,
    debug=colors.GREEN
}

local IS_WINDOWS = package.config:sub(1,1) == '\\'
local ffi
if IS_WINDOWS then
    ffi = require("ffi")
    ffi.cdef[[
        typedef int BOOL;
        typedef void* HANDLE;
        HANDLE GetStdHandle(int nStdHandle);
        int WriteConsoleW(HANDLE hConsoleOutput, const wchar_t* lpBuffer, unsigned long nNumberOfCharsToWrite, unsigned long* lpNumberOfCharsWritten, void* lpReserved);
        BOOL SetConsoleTextAttribute(HANDLE hConsoleOutput, unsigned short wAttributes);
    ]]
end

function utf8_to_utf16_buf(str)
    local tab = {}
    local i = 1
    while i <= #str do
        local c = str:byte(i)
        if c < 0x80 then
            table.insert(tab, c)
            i = i + 1
        elseif c < 0xE0 then
            local c2 = str:byte(i+1)
            table.insert(tab,
                    bit.bor(
                            bit.lshift(bit.band(c, 0x1F), 6),
                            bit.band(c2, 0x3F)
                    )
            )
            i = i + 2
        elseif c < 0xF0 then
            local c2, c3 = str:byte(i+1), str:byte(i+2)
            table.insert(tab,
                    bit.bor(
                            bit.lshift(bit.band(c, 0x0F), 12),
                            bit.lshift(bit.band(c2, 0x3F), 6),
                            bit.band(c3, 0x3F)
                    )
            )
            i = i + 3
        else -- 超出BMP直接?
            table.insert(tab, string.byte("?"))
            i = i + 4
        end
    end

    local buf = ffi.new("wchar_t[?]", #tab + 1) -- 多留一个\0结尾更安全（WriteConsoleW不要求）
    for j=1,#tab do buf[j-1]=tab[j] end

    return buf, #tab   -- 返回buffer和字符数！
end

local function win_console_printer(lvl_colors_map)
    local STD_OUTPUT_HANDLE = -11
    local handle = ffi.C.GetStdHandle(STD_OUTPUT_HANDLE)
    return function(lvl,msg)
        local color_name = r_levels[lvl]
        local color_value = lvl_colors_map[color_name] or colors.RESET
        ffi.C.SetConsoleTextAttribute(handle, color_value)
        local u16buf, u16len = utf8_to_utf16_buf(msg)
        ffi.C.WriteConsoleW(handle, u16buf, u16len, nil, nil)
        ffi.C.SetConsoleTextAttribute(handle, colors.RESET) -- 恢复原色
    end
end

-- Table pretty printer
local function _dump(obj,opt)
    if type(obj)~='table' then return tostring(obj) end
    opt = opt or {level=1}
    local pretty,opt_level,opt_sort,opt_indent_str =
    opt.pretty,opt.level or 1,opt.sort,(opt.pretty and rep('\t',opt.level or 1) or '')
    local tpl,keys={},{}
    for k in pairs(obj) do keys[#keys+1]=k end
    if opt_sort then sort(keys,function(a,b)return tostring(a)<tostring(b)end) end
    for _,k in ipairs(keys) do
        local v=obj[k]
        local vt,typek=type(v),type(k)
        local keystr=(typek=='number') and '' or (k..(pretty and ': 'or ':'))
        if vt=='table' then
            tpl[#tpl+1]=fmt('%s%s%s',opt_indent_str,keystr,_dump(v,{
                pretty=pretty,level=(opt_level+1),sort=opt_sort}))
        elseif vt=='string' then tpl[#tpl+1]=fmt('%s%s"%s"',opt_indent_str,keystr,v)
        elseif vt=='function' then tpl[#tpl+1]=fmt('%s%sfunction',opt_indent_str,keystr)
        else tpl[#tpl+1]=fmt('%s%s%s',opt_indent_str,keystr,tostring(v)) end
    end
    return pretty and '{\n'..concat(tpl,",\n")..'\n'..rep('\t',(opt_level-1))..'}'
            or '{'..concat(tpl,",")..'}'
end

local function color_fmt(lvl,msg)
    local r_lvl=r_levels[lvl]
    if not lvl_colors[r_lvl] then return msg end
    local code=lvl_colors[r_lvl]+30 -- ANSI前景色起点为30
    return '\27['..code..'m'..msg..'\27[0m'
end

local function log(self,lvl,...)
    if self._level < lvl then return end
    local t={}
    for i=1,select('#',...) do t[#t+1]=self._dump((select(i,...))) end

    -- 精确检测模板里是否包含${trace}
    local need_trace = self._fmter:match("%${%s*trace%s*}")

    local trace_str=""
    if need_trace then
        local info = debug.getinfo(3)
        trace_str=(info.short_src or '')..':'..(info.currentline or '')
    end

    local r_lvl=r_levels[lvl]
    local assobj={
        datetime=date('%Y-%m-%d %H:%M:%S'),
        level=r_lvl,msg=concat(t,' '),
        trace=trace_str,
    }

    local msg=gsub(self._fmter,'${%s*(.-)%s*}',function(v)return assobj[v]or''end)

    -- 可选：去除模板中未填充的 [] 避免出现空方括号（如 [${trace}] trace为空时）
    msg = msg:gsub(" ?%[%s*%] ?", "")

    if self._color then msg=color_fmt(lvl,msg) end

    -- 保证结尾有换行符（防止自定义格式漏掉）
    if not msg:find('\n$') then msg = msg .. '\n' end

    self._printer(lvl,msg)
end

local function new(opts)
    opts = opts or {}

    local self={
        _level   = opts.level or levels.DEBUG,
        _color   = opts.color and true or false,
        _printer = opts.printer,
        _fmter   = opts.formater or default_format,
        _pretty  = opts.pretty,
        _dump=(opts.pretty and function(v)return _dump(v,{pretty=true,sort=true})end)or _dump
    }

    local obj={}

    -- 优化：支持字符串或数字设置日志等级
    function obj.level(lvl)
        if lvl then
            if type(lvl)=="string" and levels[lvl:upper()] then self._level=levels[lvl:upper()]
            elseif r_levels[lvl] then self._level=lvl end
        end
        return self._level
    end

    local method_map={d="DEBUG",i="INFO",n="NOTICE",w="WARN",e="ERR"}
    for m,l in pairs(method_map) do obj[m]=function(...) log(self,levels[l],...) end end

    return obj
end

function _M.ngxlog(opts)
    opts  = opts or {}
    local el=require 'ngx.errlog'
    local raw_log=el.raw_log
    local function printer()
        el.raw_log=function(lvl,msg) raw_log(lvl,color_fmt(lvl,msg)) end; return el.raw_log;
    end

    return new{
        level   = opts.level or levels.DEBUG,
        printer = opts.printer or printer(),
        color   = opts.color,
        pretty  = opts.pretty,
        formater= opts.formater
    }
end

function _M.console(opts)
    opts  = opts or {}
    local printer_func

    if IS_WINDOWS and pcall(require,"ffi") then -- Windows下用WinAPI输出带中文彩色日志
        printer_func = win_console_printer(lvl_colors)
    else -- Linux/Mac或无ffi时走原始方式
        printer_func = function(_,msg) io.stdout:setvbuf('no'); io.stdout:write(msg) end
    end

    return new{
        level   = opts.level or levels.DEBUG,
        printer = opts.printer or printer_func,
        color   = not IS_WINDOWS and opts.color or true,   -- Win下强制彩色，其他跟随参数
        pretty  = opts.pretty,
        formater= opts.formater
    }
end

function _M.file(opts)
    opts = opts or {}
    local fd, file = nil, nil
    local log_dir, base_name, suffix

    -- 拆分目录、基础名、后缀
    local function split_file(filename)
        local dir, name = filename:match("^(.-)([^/]+)$")
        dir = dir or ""
        local base, suff = name:match("^(.-)%.([^.]+)$")
        if not base then base, suff = name, "" end
        return dir, base, suff
    end

    -- 列出所有历史日志文件
    local function get_log_files()
        local files = {}
        local pattern = string.format("%s%s.*.%s", log_dir or "", base_name, suffix)
        local p = io.popen('ls -1 "' .. pattern .. '" 2>/dev/null')
        if p then
            for fname in p:lines() do
                -- 排除当前log，只保留历史分割出来的（有时间戳的）文件
                if fname ~= (log_dir..base_name.."."..suffix) and fname:match("^"..base_name.."%..+%."..suffix.."$") then
                    table.insert(files, fname)
                end
            end
            p:close()
        end
        table.sort(files)
        return files
    end

    -- 删除多余历史文件
    local function remove_old_files(max_files)
        if not max_files or max_files < 1 then return end
        local files = get_log_files()
        while #files > max_files do
            os.remove(files[1])
            table.remove(files, 1)
        end
    end

    -- 日志切割：dl-jf.log -> dl-jf.YYYY-MM-DD_HH-MM-SS.log
    local function rotate_file()
        fd:close(); fd=nil;
        local timestamp = os.date('%Y-%m-%d_%H-%M-%S')
        local old_path = log_dir..base_name.."."..suffix
        local new_path = string.format("%s%s.%s.%s", log_dir, base_name, timestamp, suffix)
        os.rename(old_path, new_path)
        remove_old_files(opts.max_files or 10)
    end

    -- 初始化参数（只做一次）
    do
        log_dir, base_name, suffix = split_file(opts.file or "app.log")
        if log_dir ~= "" and log_dir:sub(-1) ~= "/" then log_dir = log_dir .. "/" end
        if suffix == "" then suffix = "log" end -- 默认加 .log 后缀
    end

    -- 写入函数，每次调用时检查是否需要轮转
    local function printer()
        return function(_, msg)
            local max_size = opts.max_size or (10*1024*1024) -- 默认10MB单个日志最大体积

            if not fd then
                fd = assert(io.open(log_dir..base_name.."."..suffix,'a+'))
                fd:setvbuf('no')
            end

            fd:flush()
            local size = (fd and fd:seek("end")) or 0

            if size >= max_size then
                rotate_file()
                fd = assert(io.open(log_dir..base_name.."."..suffix,'a+'))
                fd:setvbuf('no')
            end

            fd:write(msg)
            fd:flush()
        end
    end

    return new{
        level     = opts.level or levels.INFO,
        printer   = opts.printer or printer(),
        pretty	  = opts.pretty,
        color	  = false,
        formater  = opts.formater,
    }
end

return _M
