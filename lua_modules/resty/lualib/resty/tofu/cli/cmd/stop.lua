--
--
--

local _opts = require 'resty.tofu.cli.opts'


local _M = {
	_NAME					= 'stop',
	_DESCRIPTION	= 'stop service',

	_op_str	= 'c',
}


_M._USAGE = string.format([[
usage: %s %s [options]

%s

options:
-c	configuration file
]], _opts._CMD_NAME, _M._NAME, _M._DESCRIPTION)


local _cmd_tpl = [[
NGX_ENV=production \
openresty \
-p %s \
-c %s \
-s stop
]]


function _M.exec(opts)
	local p = opts.p or '$PWD'
	local c = opts.c or _opts.ngx_runtime_dir .. '/conf/' .. _opts.ngx_conf_file
	local cmd = string.format(_cmd_tpl, p, c)
	os.execute(cmd)		
end



return _M

