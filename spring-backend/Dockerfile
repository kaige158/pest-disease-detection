# ==========================================================
# Spring Boot 业务后端 —— 生产镜像（多阶段构建）
#
# 为什么需要这个文件：仓库根目录的 docker-compose.yml 里写了
# `build: ./spring-backend`，但这个 Dockerfile 一直缺失 ——
# 直接 `docker compose up` 会在构建阶段就失败。
# ==========================================================

# ---------- 阶段 1：编译 ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

# 先只拷 pom 拉依赖，利用 Docker 层缓存：改源码时不必重新下载依赖
COPY pom.xml ./
RUN mvn -B -ntp -DskipTests dependency:go-offline || true

COPY src ./src
RUN mvn -B -ntp -DskipTests clean package

# ---------- 阶段 2：运行 ----------
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# curl 用于容器健康检查；tzdata 保证容器内时区正确
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl tzdata \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/target/*.jar /app/app.jar

# 上传目录（由 compose 挂载到宿主机，容器重建不丢图片）
ENV UPLOAD_DIR=/data/uploads
RUN mkdir -p /data/uploads

EXPOSE 8080

# JAVA_OPTS 由 compose 注入 —— 2核4G 机器上必须限堆，
# 否则默认吃 1/4 内存（1GB 堆 + 堆外）容易把机器压垮
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
