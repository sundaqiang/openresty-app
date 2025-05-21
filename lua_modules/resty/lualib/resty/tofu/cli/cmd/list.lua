--
--
--

local _opts	= require 'resty.tofu.cli.opts'
local _util = require 'resty.tofu.util'


local _M = {
	_NAME					= 'list',
	_DESCRIPTION	= 'list deps of installed lua module',
}

_M._USAGE = string.format([[

usage: %s %s
]], _opts._CMD_NAME, _M._NAME)




local _resty_modules_path = 'lua_modules/resty'
local _rocks_modules_path = 'lua_modules/rocks'


local function _opm_list()
	local cmd = 'opm --install-dir=' .. _resty_modules_path .. ' list'
	return os.execute(cmd)
end


local function _luarocks_list()
	local cmd = 'luarocks --tree ' .. _rocks_modules_path .. ' list' 
	return os.execute(cmd)
end


local _installers = {
	opm				= _opm_installer,
	luarocks	= _luarocks_installer,
}


function _M.exec(opts)
	local tofu_package_file = 'tofu.package.lua' 
	local f = loadfile(tofu_package_file)
	if not f then
		print('can not found ' .. tofu_package_file)
		return
	end


	local mf = {}
	setfenv(f, mf)()
	local isopm = nil
	local isrocks = nil
	for _, p in ipairs( mf.deps ) do
		-- default opm
		if not isopm and 'string' == type(p) then
			isopm = true

		-- luarocks | opm
		elseif not isrocks and 'table' == type(p) then
			isrocks = true
		end
	end

	if isopm then
		_opm_list()
	end

	if isrocks then
		_luarocks_list()
	end

end



return _M
