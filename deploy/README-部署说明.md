# 生产部署说明 —— 2核4G 云服务器（香港 / 学校服务器通用）

> 适用：把平台部署到公网服务器，先给老师验收，再交老挝使用
> 内存基线：**2核4G 起步**（4个容器实测占用约 1.7GB）
> 首次部署耗时：约 15~25 分钟（大部分耗在下载 Maven / pip 依赖）

---

## 一、目录结构

```
deploy/
├── deploy.sh                 一键部署脚本（幂等，可反复执行）
├── docker-compose.prod.yml   生产编排（只有 Nginx 对外开端口）
├── nginx/laos-agri.conf      反向代理 + 预留 HTTPS 段
├── db-init/
│   ├── 00-schemas.sql        建 4 个 schema（必须最先执行）
│   └── 01~07-*.sql           由 deploy.sh 从 database/ 自动复制并按序编号
├── .env                      三个密钥 + 数据库密码（deploy.sh 自动生成，权限600）
└── data/
    ├── uploads/              识别图片（宿主机目录，容器重建不丢）
    ├── certs/                HTTPS 证书（阶段 2）
    └── certbot-www/          ACME 校验目录
```

---

## 二、首次部署

把整个仓库上传到服务器（例如 `/opt/laos-cn-APP`），然后：

```bash
cd /opt/laos-cn-APP/deploy
chmod +x deploy.sh
./deploy.sh
```

脚本会依次完成：

1. 检查 Docker 与内存
2. **生成三个密钥**（JWT_SECRET / AI_KEY_SECRET / ADMIN_INIT_PASSWORD）与数据库密码，写入 `.env`（已存在则沿用，不会覆盖）
3. 组装 `db-init/`（把 `database/*.sql` 按正确顺序编号）
4. `docker compose build`
5. `docker compose up -d` 并等待后端健康
6. 打印访问地址与管理员密码位置

完成后访问 `http://<公网IP>/admin/login`，账号 `admin`。

> ⚠️ **第一件事**：登录后立刻改管理员密码；并把 `deploy/.env` 备份到本地
> （尤其 `AI_KEY_SECRET`，换服务器时必须一起搬，否则后台里存的 AI Key 全部解不开）。

---

## 三、为什么这样设计（几个关键决定）

| 决定 | 原因 |
|------|------|
| **只有 Nginx 对外开端口** | 数据库/AI/后端只在内部网络，公网只能通过 80/443 进来；安全组里也不需要放 8080/8000/5432/6379 |
| **限制 JVM 堆为 1GB** | 2核4G 上，Spring 默认堆 = 内存/4，加上堆外很容易把机器压垮；`JAVA_OPTS` 里显式限死 |
| **上传目录挂到宿主机** | `./data/uploads` 而非容器内路径 —— 容器重建、升级镜像都不丢图片；迁移服务器时只要带走这个目录 |
| **健康检查用 `/api/v1/auth/countries`** | 不用 `/actuator/health`：后者会把 Redis 等依赖算进来，任何一个抖动都会让容器被标记 unhealthy |
| **不用 ufw 做端口管控** | Docker 会绕过 ufw 直接改 iptables，ufw 在 Docker 宿主机上基本是摆设；靠**安全组 + compose 不暴露端口**才可靠 |
| **保留 Redis 但限制 64MB** | 代码里其实没用到 Redis（无 `RedisTemplate`/`@Cacheable`），保留只为兼容健康检查；想省内存可整段删除 |
| **`db-init/00-schemas.sql` 排第一** | `init.sql` 只建了 `core`，而训练资产表用 `extension.`、评估表用 `expert.` —— 少了这个文件第二步就会报 schema 不存在 |

---

## 四、日常运维

```bash
./deploy.sh status            # 各服务状态与内存占用
./deploy.sh logs spring       # 看后端日志（服务名：spring / ai-service / postgres / nginx）
./deploy.sh restart           # 重启
./deploy.sh down              # 停止（数据保留）
./deploy.sh keys              # 查看当前密钥（脱敏）
./deploy.sh                   # 更新代码后重新构建并滚动启动
```

**看资源占用**：`docker stats --no-stream`

**进数据库**：
```bash
docker exec -it laos_pg psql -U laos -d laos_agri
```

---

## 五、备份（**务必配，数据丢了是真事故**）

```bash
# 手动备份一次
mkdir -p /opt/backup
docker exec laos_pg pg_dump -U laos laos_agri | gzip > /opt/backup/db-$(date +%F).sql.gz
tar czf /opt/backup/uploads-$(date +%F).tar.gz -C /opt/laos-cn-APP/deploy/data uploads

# 每天 3 点自动备份（crontab -e 添加）
0 3 * * * docker exec laos_pg pg_dump -U laos laos_agri | gzip > /opt/backup/db-$(date +\%F).sql.gz && find /opt/backup -name 'db-*.sql.gz' -mtime +14 -delete
```

**迁移到新服务器**：把 `db-*.sql.gz` + `uploads-*.tar.gz` + `deploy/.env` 三样带过去即可。

---

## 六、阶段 2：配域名与 HTTPS

APP 正式包必须走 HTTPS（Android 9+ 默认禁止明文 HTTP）。步骤：

1. 域名解析到服务器公网 IP（**香港地域免备案**，解析后立即可用）
2. 签证书：
   ```bash
   cd /opt/laos-cn-APP/deploy
   docker run --rm \
     -v "$PWD/data/certs:/etc/letsencrypt" \
     -v "$PWD/data/certbot-www:/var/www/certbot" \
     certbot/certbot certonly --webroot -w /var/www/certbot \
     -d 你的域名 --email 你的邮箱 --agree-tos --no-eff-email
   ```
3. 打开 `nginx/laos-agri.conf`，把文件末尾注释掉的 443 段取消注释，`server_name` 改成你的域名
4. `docker exec laos_nginx nginx -s reload`
5. 验证：`curl -I https://你的域名/api/v1/auth/countries`

**APP 打包**（指向 HTTPS 域名）：
```bash
flutter build apk --release -t lib/main_vegetable.dart \
  --dart-define=API_BASE_URL=https://你的域名/api/v1
```

---

## 七、排障速查

| 现象 | 原因 / 处理 |
|------|------------|
| 浏览器打不开 `http://IP` | 安全组没放 80；或 `./deploy.sh status` 看 nginx 是否起来 |
| 上传图片报 413 | Nginx `client_max_body_size` 没生效（本项目已设 12m，确认配置挂载正确） |
| 农户拍照后转圈很久 | AI 识别走同步调用，属正常；看 `./deploy.sh logs ai-service` 有无报错 |
| 后端容器一直 unhealthy | `./deploy.sh logs spring`；常见原因是数据库连接失败或密钥未通过严格自检 |
| 「AI识别服务不可用」 | AI 服务没起来，或后台没配 AI Key —— 去「AI 配置中心」点「测试连接」 |
| 换服务器后 AI Key 解不开 | `AI_KEY_SECRET` 与旧环境不一致；用原密钥，或回后台重填 Key |
| 磁盘写满 | 图片在 `deploy/data/uploads`；`du -sh` 看看，必要时接对象存储 |

---

## 八、与开发环境的差异

| 项 | 开发（本机） | 生产（本服务器） |
|----|------------|----------------|
| 数据库 | H2 内存库，重启清空 | PostgreSQL 16，数据卷持久化 |
| 启动方式 | `mvn spring-boot:run -Dspring-boot.run.profiles=demo` | `docker compose up -d` |
| 短信验证码 | 演示回显（`SMS_EXPOSE_CODE=true`） | 需接真实通道；未接入时保持回显仅限内网验证 |
| 管理员密码 | `.env` 固定值 | 部署时随机生成 |
| 上传目录 | `spring-backend/uploads/` | `deploy/data/uploads/` |
