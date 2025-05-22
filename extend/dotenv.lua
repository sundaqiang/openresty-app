---@alias environment table<string, any>

local function is_quoted(v)
  return type(v) == "string" and (
          (v:sub(1,1) == "'" and v:sub(-1) == "'") or
                  (v:sub(1,1) == '"' and v:sub(-1) == '"')
  )
end

local function expand_value(val, env)
  return val
          :gsub("%$%b{}", function(m)
    local k = m:sub(3, -2):lower()
    return env[k] ~= nil and tostring(env[k]) or m
  end)
          :gsub("%$(%w+)", function(m)
    local k = m:lower()
    return env[k] ~= nil and tostring(env[k]) or m
  end)
end

local function smart_convert(v)
  if type(v) ~= "string" then return v end
  v = v:match("^%s*(.-)%s*$")
  if v == "" then return "" end
  if is_quoted(v) then return v:sub(2,-2) end
  local l = v:lower()
  if l == "true" then return true end
  if l == "false" then return false end
  local n = tonumber(v); if n then return n end
  return v
end

---支持多级key（点分）写入，已小写化处理
local function set_deep(tbl, key, val)
  local parts = {}
  for part in key:lower():gmatch("[^%.]+") do parts[#parts+1] = part end
  local t = tbl
  for i=1,#parts-1 do
    if not t[parts[i]] or type(t[parts[i]])~="table" then t[parts[i]]={} end
    t=t[parts[i]]
  end
  t[parts[#parts]]=val
end

---@param content string
---@return environment
local function parse(content)
  local env, lines = {}, {}
  for line in content:gmatch("([^\r\n]*)[\r\n]?") do lines[#lines+1]=line end
  local i=1
  while i<=#lines do
    local line = lines[i]:match("^%s*(.-)%s*$")
    if line~="" and not line:match("^#") then
      local key,val = line:match("^([%w%.%_]+)%s*=%s*(.*)$")
      if key then
        val = val:gsub("%s+#.*$", "")
        if val:sub(1,1) == "`" then -- 多行反引号文本支持
          local multi = val
          while not multi:find("`$") and i < #lines do
            i = i + 1
            multi = multi .. "\n" .. lines[i]
          end
          set_deep(env, key,
                  multi:find("`$") and multi:sub(2,-2) or multi:sub(2)
          )
        elseif is_quoted(val) then
          set_deep(env, key, val:sub(2,-2))
        else
          set_deep(env, key, smart_convert(expand_value(val,env)))
        end
      end
    end
    i = i + 1
  end
  return env
end

local function parse_file(path)
  local f=io.open(path,"r"); if not f then return nil end; local c=f:read("*a"); f:close(); return parse(c)
end

-- 智能合并：后文件有key即使为空也覆盖，无key则保留旧值；递归合并table。
local function merge_env(dst, src)
  for k,v in pairs(src) do
    if type(v)=="table" and type(dst[k])=="table" then merge_env(dst[k],v)
    else dst[k]=v end -- 空字符串也会覆盖前值！
  end
end

local function parse_files(files)
  local env={}
  for _,p in ipairs(files) do
    local r=parse_file(p);
    if r then merge_env(env,r)
    end
  end;
  return env
end

-- getenv 支持多级点访问，懒加载默认.env内容。
local JSON_ENV

---@param key? string|nil @环境变量名，多级用点分隔；无参数返回整个表。
---@return any|environment @返回指定key的值或整个环境表。
local function getenv(key)
  if not JSON_ENV then JSON_ENV=parse_file('.env') or {} end -- 懒加载且缓存一份，可加reload参数支持热加载。
  if not key then return JSON_ENV end
  local t=JSON_ENV; for part in key:lower():gmatch("[^%.]+") do t=t and t[part] or nil end; return t
end

---@class DotenvLib : {parse:function, parse_file:function, getenv:function}
---@operator call : fun(a:string|string[]):environment

return setmetatable({
  parse=parse,
  parse_file=parse_file,
  getenv=getenv,
},{
  __call=function(_,a)
    if a==nil then return parse_file('.env')
    elseif type(a)=='string' then return parse(a)
    elseif type(a)=='table' then return parse_files(a)
    else error('invalid argument type:'..type(a)) end
  end,
})
