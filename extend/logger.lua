local _M = {}

local default_format = '${datetime} [${level}] [${trace}] ${msg}'

local fmt, gsub, match, rep, date, concat, sort =
string.format, string.gsub, string.match, string.rep, os.date, table.concat, table.sort

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

local colors = {
    BLACK=30, RED=31, GREEN=32, YELLOW=33,
    BLUE=34, MAGENTA=35, CYAN=36, WHITE=37
}
_M.colors = colors

local lvl_colors = {
    stderr=colors.RED, emerg=colors.MAGENTA,
    alert=colors.BLUE, crit=colors.BLUE,
    err=colors.RED, warn=colors.YELLOW,
    notice=colors.CYAN, info=colors.WHITE,
    debug=colors.GREEN
}

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
    return '\27['..(lvl_colors[r_lvl]or"")..'m'..msg..'\27[m'
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
    local function printer()
        io.stdout:setvbuf('no')
        return function(_,msg) io.stdout:write(msg) end
    end

    return new{
        level   = opts.level or levels.DEBUG,
        printer = opts.printer or printer(),
        color   = opts.color,
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
