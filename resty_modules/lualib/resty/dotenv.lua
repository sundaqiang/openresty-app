local function expand_value(value, env)
  return (value:gsub("%$%b{}", function(match)
    return env[match:sub(3, -2)] or match
  end):gsub("%$(%w+)", function(match)
    return env[match] or match
  end))
end

-- local env = setmetatable({}, {
--   __newindex = function(t, k, v)
--     rawset(t, k, v)
--     print(k, '->', v)
--   end
-- })

---@alias environment {[string]:string}

---@param content string
---@return environment
local function parse(content)
  local env = {}
  local state = "key"
  local key, value = "", ""
  local quote_char = nil
  local i = 1
  local len = #content

  while i <= len do
    local char = content:sub(i, i)

    if state == "key" then
      if char:match("[%w_]") then
        key = key .. char
      elseif char:match("%s") and key ~= "" then
        state = "after_key"
      elseif char == "=" then
        state = "before_value"
      elseif char == "#" and key == "" then
        -- Skip to end of line
        while i <= len and content:sub(i, i) ~= "\n" do
          i = i + 1
        end
      end
    elseif state == "after_key" then
      if char == "=" then
        state = "before_value"
      elseif not char:match("%s") then
        -- Invalid character in key
        key = ""
        state = "invalid"
      end
    elseif state == "before_value" then
      if char == "\n" then
        -- empty value
        env[key] = ""
        key, value = "", ""
        state = "key"
      elseif char:match("%s") then
        -- Skip whitespace
      elseif char == "'" or char == '"' or char == "`" then
        quote_char = char
        state = "quoted_value"
      else
        value = value .. char
        state = "value"
      end
    elseif state == "value" then
      if char == "#" then
        -- End of value, start of comment
        env[key] = expand_value(value:match("^%s*(.-)%s*$"), env)
        key, value = "", ""
        state = "comment"
      elseif char == "\n" then
        -- End of value
        env[key] = expand_value(value:match("^%s*(.-)%s*$"), env)
        key, value = "", ""
        state = "key"
      else
        value = value .. char
      end
    elseif state == "quoted_value" then
      if char == quote_char then
        -- End of quoted value
        env[key] = expand_value(value, env)
        key, value = "", ""
        state = "after_value"
      else
        value = value .. char
      end
    elseif state == "after_value" then
      if char == "\n" then
        state = "key"
        -- Ignore everything else until newline
      end
    elseif state == "comment" then
      if char == "\n" then
        state = "key"
      end
    elseif state == "invalid" then
      if char == "\n" then
        state = "key"
      end
    end
    i = i + 1
  end

  -- Handle last value if not followed by newline
  if key ~= "" then
    env[key] = expand_value(value:match("^%s*(.-)%s*$"), env)
  end

  return env
end


---@param path string
---@return environment
local function parse_file(path)
  local file = io.open(path, "r")
  if not file then
    return {}
  end
  local lines = file:read("*a")
  local env = assert(parse(lines))
  return env
end

---@param a string[]
---@return environment
local function parse_files(a)
  local env = {}
  for i, path in ipairs(a) do
    local res = parse_file(path)
    for key, value in pairs(res) do
      env[key] = value
    end
  end
  return env
end

local function dotenv_main(a)
  if a == nil then
    return parse_file '.env'
  elseif type(a) == 'string' then
    return assert(parse(a))
  else
    assert(type(a) == 'table', 'invalid type:' .. type(a))
    return parse_files(a)
  end
end

local JSON_ENV
---@param key string
---@return string
---@overload fun():environment
local function getenv(key)
  if not JSON_ENV then
    local json = parse_file '.env'
    JSON_ENV = json
  end
  if key then
    return JSON_ENV[key]
  else
    return JSON_ENV
  end
end

---@class Dotenv
---@operator call:environment
local dotenv = setmetatable(
  {
    parse = parse,
    parse_file = parse_file,
    getenv = getenv
  },
  {
    __call = function(t, a)
      return dotenv_main(a)
    end
  })

return dotenv
