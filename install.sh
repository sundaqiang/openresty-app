#!/bin/bash

# 定义依赖模块列表
dependencies=(
    "xiangnanscu/lua-resty-ipmatcher"
    "xiedacon/lua-fs-module"
    "xiedacon/lua-utility"
    "openresty/lua-resty-mysql"
    "xiedacon/lua-resty-logger"
    "thibaultcha/lua-resty-mlcache"
    "fffonion/lua-resty-openssl"
    "ip2location/ip2location-resty"
    "DevonStrawn/lua-resty-route"
    "bungle/lua-resty-reqargs"
    "openresty/lua-resty-upload"
    "ip2location/ip2proxy-resty"
    "bungle/lua-resty-validation"
    "bungle/lua-resty-template"
    "ledgetech/lua-resty-http"
    "openresty/lua-resty-redis"
    "axpwx/lua-resty-qqwry"
)

# 遍历依赖列表并安装每个模块
for dep in "${dependencies[@]}"; do
  echo "Installing $dep..."
  opm --cwd get "$dep" || {
      echo "Failed to install $dep!"
      exit 1
  }
done

echo "All dependencies installed successfully!"
