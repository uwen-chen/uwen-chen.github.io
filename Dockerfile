# =============================================================================
# Hugo + FixIt 博客镜像（多阶段构建）
# 构建:  docker build -t blog:latest --build-arg BASE_URL=https://blog.example.com/ .
# 运行:  docker run -d -p 8080:80 --name blog blog:latest
# =============================================================================

# ---------- 阶段 1：构建静态站点 ----------
FROM debian:bookworm-slim AS builder

ARG HUGO_VERSION=0.168.0
ARG DART_SASS_VERSION=1.106.1
# 构建时自动注入：amd64 / arm64，与 Hugo、dart-sass 的 release 包名一致
ARG TARGETARCH
# BASE_URL 决定 sitemap/RSS/canonical 中的绝对链接，构建时按实际域名注入
ARG BASE_URL=https://uwen-chen.github.io/

ENV HUGO_ENVIRONMENT=production
WORKDIR /src

# 安装 Hugo extended + Dart Sass（FixIt v1.0 硬依赖）
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget \
    && wget -qO /tmp/hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-${TARGETARCH}.tar.gz" \
    && tar -xzf /tmp/hugo.tar.gz -C /usr/local/bin hugo \
    && wget -qO /tmp/dart-sass.tar.gz "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && tar -xzf /tmp/dart-sass.tar.gz -C /opt \
    && ln -s /opt/dart-sass/sass /usr/local/bin/sass \
    && hugo version && sass --version

# 复制源码（.dockerignore 已排除 public/.git 等）
COPY . .

RUN hugo --minify --cleanDestinationDir --baseURL "${BASE_URL}" -d /public

# ---------- 阶段 2：nginx 运行时 ----------
FROM nginx:1.27-alpine

# 移除默认配置中的冗余
RUN rm /etc/nginx/conf.d/default.conf

COPY deploy/nginx.conf /etc/nginx/conf.d/blog.conf
COPY --from=builder /public /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1
