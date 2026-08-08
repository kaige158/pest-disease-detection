# Spring Boot 业务后端

## 状态

第三阶段开始搭建。此目录当前为占位。

## 技术栈

- Spring Boot 3.x
- Spring Security (用户认证)
- Spring Data JPA (ORM)
- Springdoc OpenAPI (API文档)
- PostgreSQL 16 (数据库)
- Redis 7 (缓存)

## 端口

8080

## 依赖的AI服务

Python AI Service (ai-service:8000) — 病虫害识别、诊断Agent

## 第三阶段实施计划

1. Spring Boot项目初始化 (Spring Initializr)
2. JPA实体类 (对应10张核心表)
3. Spring Data JPA Repository层
4. 基础CRUD Controller
5. 连接 PostgreSQL + Redis
6. 调用 Python AI Service 的 Feign/RestTemplate 客户端
