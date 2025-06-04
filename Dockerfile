FROM tk-k8s-registry.cn-beijing.cr.aliyuncs.com/backup/overseas:alpine-slim

# 使用阿里云源，加快 apk 安装速度
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

WORKDIR /workspace

# 只复制必要文件（如有 .dockerignore 会更好）
COPY . .

# 安装依赖、执行安装脚本、清理无用文件和缓存
RUN set -ex && \
    apk add --no-cache tzdata perl bash curl && \
    chmod +x ./install.sh && \
    ./install.sh && \
    rm -rf ./install.sh && \
    mkdir -p logs && \
    chmod 777 logs && \
    # 清理 apk 缓存（虽然 --no-cache 已经不留缓存，这里再保险一下）
    rm -rf /var/cache/apk/*

# 使用非 root 用户（如有需要，建议添加，提高安全性）
# USER nobody

CMD ["/usr/local/openresty/bin/openresty", "-p", "/workspace", "-c", "conf/nginx.conf", "-g", "daemon off;"]
