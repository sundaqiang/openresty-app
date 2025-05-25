local req = require "resty.reqargs"
local verify = require "resty.validation"
local remove  = os.remove
local pairs   = pairs

-- 定义验证器元方法
local CheckMeta = {}

-- 错误方法的中文提示映射表
local error_method_messages = {
    -- 类型验证器
    ["nil"] = "字段必须为空值",
    boolean = "字段必须是布尔值",
    number = "字段必须是数字类型",
    string = "字段必须是字符串类型",
    table = "字段必须是表类型",
    userdata = "字段必须是用户数据类型",
    ["function"] = "字段必须是函数类型",
    callable = "字段必须是可调用的函数或带有 __call 的表",
    thread = "字段必须是线程类型",
    integer = "字段必须是整数类型",
    float = "字段必须是浮点数类型",
    file = "字段必须是文件对象",

    -- 数值范围验证器
    min = "值不能小于最小限制",
    max = "值不能大于最大限制",
    between = "值必须在指定范围内",
    outside = "值不能在指定范围内",
    divisible = "值必须能被指定数字整除",
    indivisible = "值不能被指定数字整除",

    -- 字符串长度验证器
    len = "长度不符合要求",
    minlen = "长度不能少于最小限制",
    maxlen = "长度不能超过最大限制",

    -- 值比较验证器
    equals = "值不匹配要求的具体值",
    unequal = "值不应等于指定值",
    oneof = "值不在允许的集合中",
    noneof = "值在禁止的集合中",

    -- 正则表达式验证器
    match = "格式不正确，未匹配指定模式",
    unmatch = "格式不正确，不应匹配指定模式",

    -- 特殊用途验证器
    email = "请输入有效的邮箱地址",

    -- 其他过滤器
    tostring = "无法将值转换为字符串",
    tonumber = "无法将值转换为数字",
    tointeger = "无法将值转换为整数",

}

-- 遍历 errors 表并生成友好的错误消息函数
local function generate_errors(errors)
    local friendly_errors = {}

    for field_name, error_code in pairs(errors) do
        -- 从映射表中获取对应的中文提示信息
        local message_template =
        error_method_messages[error_code] or string.format("未知错误：%s", error_code)

        -- 生成最终提示信息
        friendly_errors[field_name] = message_template
    end

    return friendly_errors
end

function CheckMeta:check(schema)
    local   valid, fields, errors = schema(self) -- 执行验证逻辑，传入自身作为参数。
    errors = generate_errors(errors)
    return valid, fields, errors
end

-- 包装参数表，使其支持 validator 方法，同时保持原始数据不变。
local function add_check(params)
    return setmetatable(params or {}, { __index = CheckMeta })
end

local function cleanup(self)
    local files = self.files
    for _, f in pairs(files) do
        if f.n then
            for i = 1, f.n do
                remove(f[i].temp)
            end
        else
            remove(f.temp)
        end
    end
    self.files = {}
    self.log:info("cleanup")
end

return function(self)
    local get, post, files = req()

    add_check(get)
    add_check(post)

    self.get = get
    self.post = post
    self.files = files
    self.verify = verify

    self.yield()

    cleanup(self)
end