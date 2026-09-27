#!/usr/bin/env bash
# ==========================================================
# 一键部署脚本 —— 中老双语农业病虫害识别与防控平台
#
# 用法（在 deploy 目录下）：
#   ./deploy.sh              部署或更新（幂等，可反复执行）
#   ./deploy.sh status       查看各服务状态
#   ./deploy.sh logs [服务]  看日志（不填服务名看全部）
#   ./deploy.sh restart      重启
#   ./deploy.sh down         停止（保留数据）
#   ./deploy.sh keys         查看当前密钥配置（脱敏）
#
# 设计原则：
#   * 幂等：重复执行不会重复初始化数据库（数据卷已有数据时 initdb 自动跳过）
#   * 密钥只生成一次：写入 deploy/.env 后不再变动，
#     尤其是 AI_KEY_SECRET —— 它一变，数据库里已存的 AI Key 就解不开了
#   * 任何一步失败立刻退出（set -e），不留下半启动状态
# ==========================================================
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DEPLOY_DIR/.." && pwd)"
ENV_FILE="$DEPLOY_DIR/.env"
COMPOSE="docker compose -f $DEPLOY_DIR/docker-compose.prod.yml --env-file $ENV_FILE"

log()  { printf '\033[32m[部署]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[注意]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[失败]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 子命令 ----------
case "${1:-deploy}" in
  status)  exec $COMPOSE ps ;;
  logs)
    shift
    if [ $# -gt 0 ]; then exec $COMPOSE logs -f --tail=200 "$@"; else exec $COMPOSE logs -f --tail=200; fi ;;
  restart) log "重启全部服务"; exec $COMPOSE restart ;;
  down)    warn "停止服务（数据卷与上传文件保留）"; exec $COMPOSE down ;;
  keys)
    [ -f "$ENV_FILE" ] || die "还没有 $ENV_FILE，先跑一次 ./deploy.sh"
    log "当前密钥（只显示前 6 位，完整值在 $ENV_FILE，务必另行备份）："
    while IFS='=' read -r k v; do
      case "$k" in
        JWT_SECRET|AI_KEY_SECRET|ADMIN_INIT_PASSWORD|POSTGRES_PASSWORD)
          printf '   %-22s %s...\n' "$k" "${v:0:6}" ;;
      esac
    done < "$ENV_FILE"
    exit 0 ;;
esac

# ==================== 1. 前置检查 ====================
log "检查运行环境"
[ "$(id -u)" = "0" ] || die "请用 root 运行（sudo -i 后再执行）"
command -v docker >/dev/null || die "未安装 Docker，先执行：curl -fsSL https://get.docker.com | bash"
docker compose version >/dev/null 2>&1 || die "缺少 docker compose 插件"
[ -f "$REPO_ROOT/database/init.sql" ] || die "找不到 $REPO_ROOT/database/init.sql（请确认整个仓库已上传到服务器）"

TOTAL_MEM_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
log "内存 ${TOTAL_MEM_MB}MB / CPU $(nproc) 核"
if [ "$TOTAL_MEM_MB" -lt 3500 ]; then
  warn "内存小于 3.5GB，建议把 docker-compose.prod.yml 里 spring 的 -Xmx 从 1024m 下调到 768m"
fi

# ==================== 2. 生成密钥（只做一次） ====================
if [ ! -f "$ENV_FILE" ]; then
  log "首次部署：生成密钥并写入 $ENV_FILE"
  umask 077
  cat > "$ENV_FILE" <<EOF
# ==========================================================
# 生产环境变量 —— 已加入 .gitignore，绝不能提交到版本库
# 生成时间：$(date '+%F %T %Z')
#
# ⚠️ 备份提醒：这三个密钥丢失/变更的后果
#   JWT_SECRET          变了 → 所有人需要重新登录（影响小）
#   AI_KEY_SECRET       变了 → 后台里存的 AI Key 全部解不开，要逐个重填（影响大）
#   ADMIN_INIT_PASSWORD 只在首次建管理员时生效（影响小）
# ==========================================================

JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-64)
AI_KEY_SECRET=$(openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-64)
ADMIN_INIT_PASSWORD=$(openssl rand -base64 24 | tr -d '\n=+/' | cut -c1-16)

# 数据库
POSTGRES_USER=laos
POSTGRES_PASSWORD=$(openssl rand -base64 36 | tr -d '\n=+/' | cut -c1-32)
POSTGRES_DB=laos_agri

# 生产安全开关
APP_SECURITY_STRICT=true
# 留空即关闭"本机重置密码"接口（生产不需要）
OPS_TOKEN=
# 跨域：先用 IP 访问，留空即可；有域名后填域名
APP_CORS_ALLOWED_ORIGINS=

TZ=Asia/Vientiane
EOF
  chmod 600 "$ENV_FILE"
  log "密钥已生成（$ENV_FILE，权限 600）"
else
  log "已存在 $ENV_FILE，沿用原有密钥（不会重新生成）"
fi

# ==================== 3. 组装数据库初始化脚本 ====================
# postgres 官方镜像只在数据卷为空时执行 docker-entrypoint-initdb.d 里的 *.sql，
# 且按**文件名字典序**执行 —— 所以这里用数字前缀严格定序。
log "组装数据库初始化脚本（db-init/）"
mkdir -p "$DEPLOY_DIR/db-init"

copy_sql() {   # $1 = database 下的文件名，$2 = db-init 下的目标文件名（数字前缀决定执行顺序）
  if [ -f "$REPO_ROOT/database/$1" ]; then
    cp "$REPO_ROOT/database/$1" "$DEPLOY_DIR/db-init/$2"
  else
    warn "跳过不存在的脚本：database/$1"
  fi
}

copy_sql init.sql                        01-init.sql
copy_sql training_dataset.sql            02-training_dataset.sql
copy_sql evaluation_record.sql           03-evaluation_record.sql
copy_sql v5_user_admin_ai_config.sql     04-v5_user_admin_ai_config.sql
copy_sql seed_data_v1.sql                05-seed_data_v1.sql
copy_sql seed_corpus_6ps_v1.sql          06-seed_corpus_6ps_v1.sql
copy_sql seed_raw_materials_v1.sql       07-seed_raw_materials_v1.sql

log "已准备 $(ls -1 "$DEPLOY_DIR/db-init"/*.sql | wc -l) 个 SQL 脚本（按序号执行）"

# ==================== 4. 目录准备 ====================
mkdir -p "$DEPLOY_DIR/data/uploads" "$DEPLOY_DIR/data/certs" "$DEPLOY_DIR/data/certbot-www"
log "上传目录：$DEPLOY_DIR/data/uploads"

# ==================== 5. 构建并启动 ====================
log "构建镜像（首次约 5-10 分钟，主要耗在下载 Maven / pip 依赖）"
$COMPOSE build

log "启动服务"
$COMPOSE up -d

# ==================== 6. 等待健康 ====================
log "等待服务就绪（最多 3 分钟）"
for i in $(seq 1 36); do
  if curl -fsS --max-time 3 http://127.0.0.1/api/v1/auth/countries >/dev/null 2>&1; then
    log "后端已就绪 ✅"
    break
  fi
  [ "$i" = "36" ] && warn "等待超时，请执行 ./deploy.sh logs spring 查看原因"
  sleep 5
done

# ==================== 7. 结果 ====================
PUBLIC_IP=$(curl -s --max-time 8 ifconfig.me || echo "<本机公网IP>")
echo
log "==================== 部署完成 ===================="
$COMPOSE ps
echo
log "管理后台：  http://$PUBLIC_IP/admin/login"
log "接口自检：  http://$PUBLIC_IP/api/v1/auth/countries"
log "管理员账号：admin"
log "管理员密码：见 $ENV_FILE 里的 ADMIN_INIT_PASSWORD（执行 ./deploy.sh keys 可看前 6 位）"
echo
warn "下一步（务必做）："
warn "  1. 立刻备份 $ENV_FILE —— 尤其是 AI_KEY_SECRET，换服务器时必须一起搬"
warn "  2. 登录后台后第一件事是修改管理员密码"
warn "  3. 在「AI 配置中心」填入真实 AI Key 并点「测试连接」"
echo
log "常用命令： ./deploy.sh status | logs [服务] | restart | down"
