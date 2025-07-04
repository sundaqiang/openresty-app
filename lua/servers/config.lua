local dotenv = require "extend.dotenv"

local function merge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            merge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

local _app_env = os.getenv("APP_ENV") or "develop"

local _config_path = os.getenv("CONFIG_PATH") or ""

if #_config_path > 0 and not _config_path:match("/$") then
    _config_path = _config_path .. "/"
end

local _env_files = {
    string.format("%s.env", _config_path),
    string.format("%s.env.%s", _config_path, _app_env)
}

local _env_table = dotenv(_env_files)

local _M = {
    isdev = _app_env == "develop",
}

merge(_M, _env_table)

return _M
