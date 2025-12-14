#!/bin/bash

# Immich 智能相册部署脚本
# 支持手动输入配置参数

set -e

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║               Immich 家庭AI智能相册部署脚本                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 函数：验证路径是否存在
validate_path() {
    local path=$1
    if [ ! -d "$path" ]; then
        read -p "目录不存在，是否创建? (y/n): " create_dir
        if [[ $create_dir == "y" || $create_dir == "Y" ]]; then
            mkdir -p "$path"
            echo -e "${GREEN}✓ 已创建目录: $path${NC}"
        else
            echo -e "${RED}✗ 目录不存在，请检查路径: $path${NC}"
            return 1
        fi
    fi
    return 0
}

# 函数：获取用户输入
get_input() {
    local prompt=$1
    local default=$2
    local input
    
    if [ -n "$default" ]; then
        read -p "$prompt (默认: $default): " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

echo -e "${YELLOW}[1/7] 配置部署参数${NC}"
echo ""

# 获取基本配置
DEPLOY_DIR=$(get_input "请输入部署目录" "/volume1/docker/immich")
IMMICH_PORT=$(get_input "请输入Web访问端口" "2283")
ADMIN_EMAIL=$(get_input "请输入管理员邮箱" "admin@example.com")
ADMIN_PASSWORD=$(get_input "请输入管理员密码" "$(openssl rand -base64 12)")

echo ""
echo -e "${YELLOW}[2/7] 配置存储路径${NC}"
echo ""

# 获取路径配置
echo -e "${WHITE}注意：以下路径请使用绝对路径${NC}"
UPLOAD_LOCATION=$(get_input "1. 照片存储路径 (存放已上传照片)" "$DEPLOY_DIR/upload")
UPLOAD_WAIBU=$(get_input "2. 扫描照片路径 (外部照片目录，用于扫描)" "$DEPLOY_DIR/external")
UPLOAD_CACHE=$(get_input "3. 大模型缓存路径" "$DEPLOY_DIR/model-cache")
UPLOAD_GEODATA=$(get_input "4. 地图数据路径" "$DEPLOY_DIR/geodata")
UPLOAD_COUNTRIES=$(get_input "5. 国家数据路径" "$DEPLOY_DIR/countries")
DB_DATA_LOCATION=$(get_input "6. 数据库数据路径" "$DEPLOY_DIR/postgres-data")

echo ""
echo -e "${YELLOW}[3/7] 验证路径${NC}"

# 验证并创建目录
echo "正在验证目录..."
validate_path "$DEPLOY_DIR" || exit 1
validate_path "$UPLOAD_LOCATION" || exit 1
validate_path "$UPLOAD_WAIBU" || exit 1
validate_path "$UPLOAD_CACHE" || exit 1
validate_path "$UPLOAD_GEODATA" || exit 1
validate_path "$UPLOAD_COUNTRIES" || exit 1
validate_path "$DB_DATA_LOCATION" || exit 1

echo -e "${GREEN}✓ 所有路径验证通过${NC}"
echo ""

# 生成随机密码
DB_PASSWORD=$(openssl rand -base64 16)
DB_USERNAME="postgres"
DB_DATABASE_NAME="immich"
IMMICH_VERSION="release"
TZ="Asia/Shanghai"

echo -e "${YELLOW}[4/7] 生成配置文件${NC}"

# 创建docker-compose.yml
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.yml"
cat > "$COMPOSE_FILE" << EOF
name: immich

services:
  immich-server:
    container_name: immich_server
    image: ghcr.nju.edu.cn/immich-app/immich-server:\${IMMICH_VERSION:-release}
    volumes:
      - \${UPLOAD_LOCATION}:/data
      - /etc/localtime:/etc/localtime:ro
      - \${UPLOAD_GEODATA}:/build/geodata
      - \${UPLOAD_COUNTRIES}:/usr/src/app/node_modules/i18n-iso-countries
      - \${UPLOAD_WAIBU}:/extlib    #/extlib 这个路径是添加扫描路径
    env_file:
      - .env
    ports:
      - '$IMMICH_PORT:2283'
    depends_on:
      - redis
      - database
    restart: always
    healthcheck:
      disable: false

  immich-machine-learning:
    container_name: immich_machine_learning
    image: ghcr.nju.edu.cn/immich-app/immich-machine-learning:\${IMMICH_VERSION:-release}
    volumes:
      - \${UPLOAD_CACHE}:/cache
    env_file:
      - .env
    restart: always
    healthcheck:
      disable: false

  redis:
    container_name: immich_redis
    image: docker.io/valkey/valkey:8-bookworm@sha256:fea8b3e67b15729d4bb70589eb03367bab9ad1ee89c876f54327fc7c6e618571
    healthcheck:
      test: redis-cli ping || exit 1
    restart: always

  database:
    container_name: immich_postgres
    image: ghcr.nju.edu.cn/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
    environment:
      POSTGRES_PASSWORD: \${DB_PASSWORD}
      POSTGRES_USER: \${DB_USERNAME}
      POSTGRES_DB: \${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - \${DB_DATA_LOCATION}:/var/lib/postgresql/data
    shm_size: 128mb
    restart: always

volumes:
  model-cache:
EOF

echo -e "${GREEN}✓ docker-compose.yml 已创建${NC}"

# 创建.env文件
ENV_FILE="$DEPLOY_DIR/.env"
cat > "$ENV_FILE" << EOF
# 填写一下配置路径
UPLOAD_LOCATION=$UPLOAD_LOCATION    #照片存储路径
UPLOAD_GEODATA=$UPLOAD_GEODATA   #地图路径
UPLOAD_COUNTRIES=$UPLOAD_COUNTRIES    #地图路径
UPLOAD_CACHE=$UPLOAD_CACHE      #大模型路径
UPLOAD_WAIBU=$UPLOAD_WAIBU       #扫描照片路径

# 填写服务器数据库路径
DB_DATA_LOCATION=$DB_DATA_LOCATION      #缓存文件路径

TZ=$TZ
# 默认即可
IMMICH_VERSION=$IMMICH_VERSION
# 默认即可
DB_PASSWORD=$DB_PASSWORD
DB_USERNAME=$DB_USERNAME
DB_DATABASE_NAME=$DB_DATABASE_NAME
EOF

echo -e "${GREEN}✓ .env 配置文件已创建${NC}"
echo ""

# 创建配置说明文件
README_FILE="$DEPLOY_DIR/README.md"
cat > "$README_FILE" << EOF
# Immich 智能相册配置信息

## 服务信息
- Web访问地址: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost"):$IMMICH_PORT
- 管理员邮箱: $ADMIN_EMAIL
- 管理员密码: $ADMIN_PASSWORD

## 目录结构
1. 照片存储路径: $UPLOAD_LOCATION
2. 扫描照片路径: $UPLOAD_WAIBU
3. 大模型缓存: $UPLOAD_CACHE
4. 地图数据: $UPLOAD_GEODATA
5. 国家数据: $UPLOAD_COUNTRIES
6. 数据库数据: $DB_DATA_LOCATION

## 管理命令
- 启动服务: cd $DEPLOY_DIR && docker compose up -d
- 停止服务: cd $DEPLOY_DIR && docker compose down
- 查看日志: cd $DEPLOY_DIR && docker compose logs -f
- 重启服务: cd $DEPLOY_DIR && docker compose restart

## 注意事项
1. 首次登录后请立即修改管理员密码
2. 需要在Web界面中设置扫描路径: /extlib
3. 确保所有目录有正确的读写权限
EOF

echo -e "${YELLOW}[5/7] 启动Docker服务${NC}"

# 检查Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker服务未运行，请先启动Docker${NC}"
    exit 1
fi

echo "正在拉取Docker镜像，请稍候..."
cd "$DEPLOY_DIR"
docker compose pull

echo -e "${YELLOW}[6/7] 启动Immich容器${NC}"
docker compose up -d

echo "等待服务启动..."
sleep 15

echo -e "${YELLOW}[7/7] 验证服务状态${NC}"
if docker ps | grep -q "immich_server"; then
    echo -e "${GREEN}✓ Immich服务已成功启动${NC}"
else
    echo -e "${RED}✗ Immich服务启动失败，请检查日志${NC}"
    echo "运行以下命令查看日志:"
    echo "cd $DEPLOY_DIR && docker compose logs"
    exit 1
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}✅ Immich 智能相册部署完成！${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${WHITE}📋 部署信息：${NC}"
echo -e "  ${YELLOW}•${NC} 部署目录: ${GREEN}$DEPLOY_DIR${NC}"
echo -e "  ${YELLOW}•${NC} Web端口: ${GREEN}$IMMICH_PORT${NC}"
echo -e "  ${YELLOW}•${NC} 管理员邮箱: ${GREEN}$ADMIN_EMAIL${NC}"
echo -e "  ${YELLOW}•${NC} 管理员密码: ${RED}$ADMIN_PASSWORD${NC}"
echo ""
echo -e "${WHITE}🌐 访问地址：${NC}"
echo -e "  ${YELLOW}•${NC} http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost"):$IMMICH_PORT${NC}"
echo ""
echo -e "${WHITE}📁 目录配置：${NC}"
echo -e "  ${YELLOW}•${NC} 照片存储: ${WHITE}$UPLOAD_LOCATION${NC}"
echo -e "  ${YELLOW}•${NC} 扫描路径: ${WHITE}$UPLOAD_WAIBU${NC}"
echo -e "  ${YELLOW}•${NC} 模型缓存: ${WHITE}$UPLOAD_CACHE${NC}"
echo ""
echo -e "${WHITE}⚙️  后续步骤：${NC}"
echo -e "  1. 登录Web界面，使用上述管理员账号"
echo -e "  2. 进入设置 → 存储设置，添加扫描路径: ${CYAN}/extlib${NC}"
echo -e "  3. 首次使用建议开启AI识别功能"
echo -e "  4. 可在设置中修改语言为中文"
echo ""
echo -e "${WHITE}🔧 常用命令：${NC}"
echo -e "  ${YELLOW}•${NC} 启动: ${WHITE}cd $DEPLOY_DIR && docker compose up -d${NC}"
echo -e "  ${YELLOW}•${NC} 停止: ${WHITE}cd $DEPLOY_DIR && docker compose down${NC}"
echo -e "  ${YELLOW}•${NC} 日志: ${WHITE}cd $DEPLOY_DIR && docker compose logs -f${NC}"
echo ""
echo -e "${YELLOW}⚠️  重要提示：请确保防火墙已开放端口 $IMMICH_PORT${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
echo ""

# 保存部署配置
CONFIG_FILE="$DEPLOY_DIR/deploy-config.txt"
cat > "$CONFIG_FILE" << EOF
DEPLOY_TIME=$(date '+%Y-%m-%d %H:%M:%S')
DEPLOY_DIR=$DEPLOY_DIR
IMMICH_PORT=$IMMICH_PORT
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASSWORD
UPLOAD_LOCATION=$UPLOAD_LOCATION
UPLOAD_WAIBU=$UPLOAD_WAIBU
UPLOAD_CACHE=$UPLOAD_CACHE
UPLOAD_GEODATA=$UPLOAD_GEODATA
UPLOAD_COUNTRIES=$UPLOAD_COUNTRIES
DB_DATA_LOCATION=$DB_DATA_LOCATION
EOF

echo -e "${GREEN}✓ 部署配置已保存至: $CONFIG_FILE${NC}"
echo -e "${GREEN}✓ 详细说明文档: $README_FILE${NC}"

exit 0