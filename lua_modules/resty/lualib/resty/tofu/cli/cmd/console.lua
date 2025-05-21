--
--
--

local _opts = require 'resty.tofu.cli.opts'


local _M = {
	_NAME					= 'console',
	_DESCRIPTION	= 'start service (development)',

	_op_str	= 'epcg',
}


_M._USAGE = string.format([[

usage: %s %s [options]
%s

options:
-e	set environment(default devemopment)
-c	configuration file
-p	override prefix directory
]], _opts._CMD_NAME, _M._NAME, _M._DESCRIPTION)


local _cmd_tpl = [[
NGX_ENV=%s \
openresty \
-p %s \
-c %s \
-g " \
daemon off; \
error_log /dev/stderr debug; \
%s \
"]]


function _M.exec(opts)
	local e = opts.e or 'development'
	local p = opts.p or '$PWD'
	local c = opts.c or _opts.ngx_runtime_dir .. '/conf/' .. _opts.ngx_conf_file
	local g = opts.g or ''
	local cmd = string.format(_cmd_tpl, e, p, c, g)
	tofu.ENV = e
	_opts._init(opts)
	os.execute(cmd)		
end



return _M

