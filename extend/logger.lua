local _M = {}

local fmt, gsub, rep, date, concat, sort =
string.format, string.gsub, string.rep, os.date, table.concat, table.sort

-- 日志等级
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

-- 日志等级反查表（数值转小写字符串）
local r_levels = {}
for k,v in pairs(levels) do r_levels[v] = k:lower() end

-- 统一色表（小写 key）
local colors = {
    black=0, red=4, green=2, yellow=6,
    blue=1, magenta=5, cyan=3, white=7,
    reset=7 -- Windows 默认白色/灰；ANSI 用于还原
}
_M.colors = colors

-- 等级对应颜色
local lvl_colors = {
    stderr=colors.red, emerg=colors.magenta,
    alert=colors.blue, crit=colors.blue,
    err=colors.red, warn=colors.yellow,
    notice=colors.cyan, info=colors.white,
    debug=colors.green
}

-- 平台检测
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

-- utf8->utf16 buffer for Windows控制台
function utf8_to_utf16_buf(str)
    local bit=require"bit"
    local tab,i={},1
    while i<=#str do
        local c=str:byte(i)
        if c<0x80 then table.insert(tab,c);i=i+1
        elseif c<0xE0 then local c2=str:byte(i+1)
            table.insert(tab,(bit.lshift(bit.band(c,0x1F),6)+bit.band(c2,0x3F)))
            i=i+2
        elseif c<0xF0 then local c2,c3=str:byte(i+1),str:byte(i+2)
            table.insert(tab,(bit.lshift(bit.band(c,0x0F),12)+bit.lshift(bit.band(c2,0x3F),6)+bit.band(c3,0x3F)))
            i=i+3
        else table.insert(tab,string.byte("?"));i=i+4 end -- 超出BMP直接?
    end
    local buf=ffi.new("wchar_t[?]",#tab+1)
    for j=1,#tab do buf[j-1]=tab[j] end
    return buf,#tab
end

-- 彩色输出：ANSI/Linux/Mac 控制台使用 ANSI 转义码，Windows 用 API 设置属性。
local function color_fmt(lvl,msg)
    local r_lvl=r_levels[lvl]
    local color=lvl_colors[r_lvl]
    return color and ("\27["..(color+30).."m"..msg.."\27[0m") or msg -- ANSI前景色起点为30
end

local function win_console_printer()
    local STD_OUTPUT_HANDLE=-11
    local handle=ffi.C.GetStdHandle(STD_OUTPUT_HANDLE)
    return function(lvl,msg)
        local color_name=r_levels[lvl]
        ffi.C.SetConsoleTextAttribute(handle,lvl_colors[color_name] or colors.reset)
        local u16buf,u16len=utf8_to_utf16_buf(msg)
        ffi.C.WriteConsoleW(handle,u16buf,u16len,nil,nil)
        ffi.C.SetConsoleTextAttribute(handle,colors.reset)
    end
end

-- 简单table pretty打印器（可选美观缩进）
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
        if vt=='table' then tpl[#tpl+1]=fmt('%s%s%s',opt_indent_str,keystr,_dump(v,{pretty=pretty,level=(opt_level+1),sort=opt_sort}))
        elseif vt=='string' then tpl[#tpl+1]=fmt('%s%s"%s"',opt_indent_str,keystr,v)
        elseif vt=='function' then tpl[#tpl+1]=fmt('%s%sfunction',opt_indent_str,keystr)
        else tpl[#tpl+1]=fmt('%s%s%s',opt_indent_str,keystr,tostring(v)) end
    end

    return pretty and '{\n'..concat(tpl,",\n")..'\n'..rep('\t',(opt_level-1))..'}'
            or '{'..concat(tpl,",")..'}'
end

-- 日志主函数（支持模板、trace、彩色等）
local function log(self,lvl,...)
    if self._level < lvl then return end
    local t={}
    for i=1,select('#',...) do t[#t+1]=self._dump((select(i,...))) end

    -- 检查模板是否有trace字段，需要时才取栈信息
    local need_trace=self._fmter:match("%${%s*trace%s*}")

    local trace_str=""
    if need_trace then
        local info=debug.getinfo(3)
        trace_str=(info.short_src or '')..':'..(info.currentline or '')
    end

    local r_lvl=r_levels[lvl]
    local assobj={
        datetime=date('%Y-%m-%d %H:%M:%S'),
        level=r_lvl,msg=concat(t,' '),
        trace=trace_str,
    }

    local msg=gsub(self._fmter,'${%s*(.-)%s*}',function(v)return assobj[v]or''end):gsub(" ?%[%s*%]? ?", "")

    if self._color then msg=color_fmt(lvl,msg) end

    if not msg:find('\n') then msg = msg .. '\n' end

    self._printer(lvl,msg)
end

-- 工厂函数：通用new方法，自动生成各日志方法(d/i/n/w/e等)
local function new(opts)
    opts = opts or {}

    -- _dump决定是否美化table显示
    local self={
        _level   = opts.level or levels.DEBUG,
        _color   = opts.color and true or false,
        _printer = opts.printer,
        _fmter   = opts.formater or '${datetime} [${level}] [${trace}] ${msg}',
        _dump=(opts.pretty and function(v)return _dump(v,{pretty=true,sort=true})end)or _dump
    }

    -- 支持设置日志等级（数字或字符串）
    local obj={}
    function obj.level(lvl)
        if lvl then
            if type(lvl)=="string" and levels[lvl:upper()] then self._level=levels[lvl:upper()]
            elseif r_levels[lvl] then self._level=lvl end
        end
        return self._level
    end

    -- 快捷方法 d/i/n/w/e 分别对应五种常用日志等级
    for m,l in pairs{d="DEBUG",i="INFO",n="NOTICE",w="WARN",e="ERR"} do
        obj[m]=function(...) log(self,levels[l],...) end
    end

    return obj
end

-- OpenResty专用ngx.errlog包装器（彩色输出）
function _M.ngxlog(opts)
    opts  = opts or {}
    local el=require 'ngx.errlog'
    local raw_log=el.raw_log

    -- 包装成彩色errlog输出
    local printer=function()
        el.raw_log=function(lvl,msg) raw_log(lvl,color_fmt(lvl,msg)) end;
        return el.raw_log;
    end

    return new{
        level   = opts.level or levels.DEBUG,
        printer = opts.printer or printer(),
        color   = opts.color,
        pretty  = opts.pretty,
        formater= opts.formater
    }
end

-- 控制台日志工厂：支持 Windows 彩色中文/ANSI 彩色/普通输出三种情况。
function _M.console(opts)
    opts  = opts or {}

    -- 优先使用WinAPI，否则走标准IO
    local printer_func =
    (IS_WINDOWS and pcall(require,"ffi")) and win_console_printer()
            or (function(_,msg) io.stdout:setvbuf('no'); io.stdout:write(msg) end)

    return new{
        level   = opts.level or levels.DEBUG,
        printer = opts.printer or printer_func,
        color   = not IS_WINDOWS and opts.color or true,
        pretty  = opts.pretty,
        formater= opts.formater
    }
end

-- 文件日志工厂：文件切割、历史保留等功能不变。
function _M.file(opts)
    opts   = opts or {}
    local fd,file=nil,nil;
    -- 拆分目录、基础名、后缀
    local function split_file(filename)
        local dir,name=(filename):match("^(.-)([^/]+)$")
        dir=(dir=="" and "" )or dir;
        local base,suff=name:match("^(.-)%.([^.]+)$")
        if not base then base,suff=name,"" end;
        return dir,(base),suff;
    end

    -- 列出所有历史日志文件
    local function get_log_files(log_dir,base_name,suffix,max_files)
        local files={}
        local pattern=(log_dir or "")..base_name..".*."..suffix;
        for fname in io.popen('ls -1 "' .. pattern .. '" 2>/dev/null'):lines() do
            if fname~=(log_dir..base_name.."."..suffix) and fname:match("^"..base_name.."%..+%."..suffix.."$")
            then files[#files+1]=fname;
            end
        end
        table.sort(files);return files;
    end

    -- 删除多余历史文件
    local function remove_old_files(log_dir,bn,suf,max_files)
        if not max_files or max_files < 1 then return end;
        while #get_log_files(log_dir,bn,suf)>max_files do
            os.remove(get_log_files(log_dir,bn,suf)[1])
            table.remove(get_log_files(log_dir,bn,suf), 1);
        end
    end

    -- 日志切割
    local function rotate_file(log_dir,bn,suf,max_files)
        fd:close();fd=nil;
        os.rename(
                log_dir..bn.."."..suf,string.format("%s%s.%s.%s",
                        log_dir,bn,date('%Y-%m-%d_%H-%M-%S'),suf))
        remove_old_files(log_dir,bn,suf,max_files);
    end

    -- 初始化参数，只做一次
    local log_dir,bn,suf=
    split_file(opts.file or "app.log");
    log_dir=(log_dir~=""and log_dir:sub(-1)=="/")and log_dir or (log_dir==""and ""or log_dir.."/");
    suf=suf==""and"log"or suf;

    -- 写入函数，每次调用时检查是否需要轮转
    local function printer()
        return function(_,msg)
            fd=(fd and fd )or assert(io.open(log_dir..bn.."."..suf,'a+'));fd:setvbuf('no')
            fd:flush();
            if (fd:seek("end")>= (opts.max_size or (10*1024*1024)))then rotate_file(log_dir,bn,suf,(opts.max_files or 10));
                fd=nil;fd=assert(io.open(log_dir..bn.."."..suf,'a+'));fd:setvbuf('no');
            end;
            fd:write(msg);fd:flush();
        end
    end

    return new{
        level   =(opts.level   )or levels.INFO ,
        printer =(opts.printer )or printer(),
        pretty	=(opts.pretty ),
        color	=false ,
        formater=(opts.formater),
    }
end

return _M
