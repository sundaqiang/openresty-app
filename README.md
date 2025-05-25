# 项目依赖清单

本文件列出了项目所需的所有依赖模块及其版本信息.请确保这些模块已正确安装,以确保项目正常运行.

## 模块列表,

| 模块名称                                                                                  | 版本号    | 描述                           |
|---------------------------------------------------------------------------------------|--------|------------------------------|
| [xiangnanscu/lua-resty-ipmatcher](https://github.com/xiangnanscu/lua-resty-ipmatcher) | 0.31   | 高性能 IP 匹配器，支持 CIDR 和 IP 范围匹配 |
| [xiedacon/lua-fs-module](https://github.com/xiedacon/lua-fs-module)                   | 0.1    | Lua 文件系统操作模块                 |
| [xiedacon/lua-utility](https://github.com/xiedacon/lua-utility)                       | 0.3    | 一组实用工具函数集合                   |
| [openresty/lua-resty-mysql](https://github.com/openresty/lua-resty-mysql)             | 0.27   | MySQL 客户端库用于 OpenResty       |
| [xiedacon/lua-resty-logger](https://github.com/xiedacon/lua-resty-logger)             | 0.2.1  | 高性能日志记录库                     |
| [thibaultcha/lua-resty-mlcache](https://github.com/thibaultcha/lua-resty-mlcache)     | 2.7.0  | 多层缓存库，用于共享内存和 worker 缓存      |
| [fffonion/lua-resty-openssl](https://github.com/fffonion/lua-resty-openssl)           | 1.5.2  | OpenSSL 的 Lua 封装，提供加解密功能     |
| [ip2location/ip2location-resty](https://www.ip2location.com/)                         | 8.7.1  | 基于 IP 地址进行地理位置查询             |
| [DevonStrawn/lua-resty-route](https://github.com/DevonStrawn/lua-resty-route)         | 0.1    | 基于路由规则的请求处理                  |
| [bungle/lua-resty-reqargs](https://github.com/bungle/lua-resty-reqargs)               | 1.4    | 用于解析 HTTP 请求参数               |
| [openresty/lua-resty-upload](https://github.com/openresty/lua-resty-upload)           | 0.10   | 文件上传处理库                      |
| [ip2location/ip2proxy-resty](https://www.ip2location.com/)                            | 3.4.0  | 基于 IP 地址检测代理使用情况             |
| [bungle/lua-resty-validation](https://github.com/bungle/lua-resty-validation)         | 2.7    | 数据验证库                        |
| [bungle/lua-resty-template](https://github.com/bungle/lua-resty-template)             | 2.0    | HTML 模板引擎                    |
| [ledgetech/lua-resty-http](https://github.com/ledgetech/lua-resty-http)               | 0.17.1 | HTTP 客户端库                    |
| [openresty/lua-resty-redis](https://github.com/openresty/lua-resty-redis)             | 0.32   | Redis 客户端库                   |
| [axpwx/lua-resty-qqwry](https://github.com/axpwx/restylib/tree/master/restylib/qqwry) | 0.01   | QQWry IP 库解析工具               |

## 安装步骤
1. 安装openresty
    ```bash
    brew install openresty/brew/openresty
    ```
2. 安装依赖
    ```bash
    ./install.sh
    ```
## 启动步骤
1. 创建环境变量文件
    ```bash
   cp .env .env.develop
   export APP_ENV=develop
   openresty -p `pwd` -c conf/nginx.conf -g 'daemon off;'
   ```
2. 未配置环境变量APP_ENV时,APP_ENV=develop
3. 默认先读取.env,再读取.env.APP_ENV,且.env.APP_ENV覆盖.env