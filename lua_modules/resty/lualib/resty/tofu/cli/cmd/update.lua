--
--
--

local _opts = require 'resty.tofu.cli.opts'


local _M = {
	_NAME					= 'update',
	_DESCRIPTION	= 'update deps of isntalled',
}

_M._USAGE = string.format([[

usage: %s %s
]], _opts._CMD_NAME, _M._NAME)




local _resty_modules_path = 'lua_modules/resty'
local _rocks_modules_path = 'lua_modules/rocks'


local function _opm_updater(package)
	local cmd = 'opm --install-dir=' .. _resty_modules_path .. ' upgrade ' .. package
	return os.execute(cmd)
end


local function _luarocks_updater(package)
	local cmd = 'luarocks --tree ' .. _rocks_modules_path .. ' install ' .. package
	return os.execute(cmd)
end


local _updaters = {
	opm				= _opm_updater,
	luarocks	= _luarocks_updater,
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

	local name = nil
	for _, p in ipairs( mf.deps ) do
		-- default opm
		if 'string' == type(p) then
			name = 'opm'

		-- luarocks | opm
		elseif 'table' == type(p) and p[1] and p[2] then
			name = p[1]
			p = p[2]
		else
			print('\27[0;31merror config in ' .. tofu_package_file .. ':' .. type(p) .. '\27[m')
			return
		end

		local updater = _updaters[name]
		if not updater then
			print('\27[0;31merror updater ' .. name .. '\27[m')
		end
		print('updater ' .. '\27[0;32m' .. p .. '\27[m')
		if not updater(p) then
			return
		end
	end

end


return _M

