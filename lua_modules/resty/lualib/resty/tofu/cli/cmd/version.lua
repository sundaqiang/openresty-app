--
--
--

local _mate	= require 'resty.tofu.mate'
local _opts = require 'resty.tofu.cli.opts'


local _M = {
	_NAME					= 'version',
	_DESCRIPTION	= 'show version information',
}

_M._USAGE = string.format([[

usage: %s %s
]], _opts._CMD_NAME, _M._NAME)




function _M.exec(opts)
	print(_mate._SERVER_TOKENS)
end



return _M
