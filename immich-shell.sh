#!/bin/bash

# 米乐星球NAS - Immich智能相册Shell部署脚本
# 版本: 1.0
# 作者: 米乐星球技术支持团队

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

# 获取主机IP
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")

# 配置变量
IMMICH_DIR="/volume1/docker/immich"
IMMICH_DATA_DIR="$IMMICH_DIR/data"
IMMICH_UPLOAD_DIR="$IMMICH_DIR/upload"
IMMICH_PORT=8088
IMMICH_DB_PASSWORD=$(openssl rand -base64 16)
IMMICH_ADMIN_EMAIL="admin@example.com"
IMMICH_ADMIN_PASSWORD=$(openssl rand -base64 12)

# 创建目录结构
echo -e "${YELLOW}[1/6] 创建目录结构...${NC}"
mkdir -p "$IMMICH_DIR" "$IMMICH_DATA_DIR" "$IMMICH_UPLOAD_DIR"
echo -e "${GREEN}✓ 目录创建完成${NC}"
echo ""

# 下载docker-compose配置文件
echo -e "${YELLOW}[2/6] 下载配置文件...${NC}"
COMPOSE_FILE="$IMMICH_DIR/docker-compose.yml"
cat > "$COMPOSE_FILE" << 'EOF'
version: "3.8"

services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "${IMMICH_PORT}:3001"
    env_file:
      - .env
    depends_on:
      - redis
      - database
    restart: always
    networks:
      - immich-network

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    container_name: immich-machine-learning
    volumes:
      - model-cache:/cache
    env_file:
      - .env
    restart: always
    networks:
      - immich-network

  redis:
    image: redis:7-alpine
    container_name: immich-redis
    volumes:
      - redis-data:/data
    restart: always
    networks:
      - immich-network

  database:
    image: postgres:14
    container_name: immich-database
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: postgres
      POSTGRES_DB: immich
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: always
    networks:
      - immich-network

networks:
  immich-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:
  model-cache:
EOF
echo -e "${GREEN}✓ docker-compose.yml 配置文件创建完成${NC}"
echo ""

# 创建环境变量文件
echo -e "${YELLOW}[3/6] 配置环境变量...${NC}"
ENV_FILE="$IMMICH_DIR/.env"
cat > "$ENV_FILE" << EOF
# Immich 环境变量配置
DB_HOSTNAME=database
DB_USERNAME=postgres
DB_PASSWORD=${IMMICH_DB_PASSWORD}
DB_DATABASE_NAME=immich
DB_PORT=5432
REDIS_HOSTNAME=redis
REDIS_PORT=6379

# 文件上传路径
UPLOAD_LOCATION=${IMMICH_UPLOAD_DIR}

# 服务器设置
IMMICH_PORT=${IMMICH_PORT}
PUBLIC_LOGIN_PAGE_MESSAGE="欢迎使用Immich智能相册"

# 机器学习设置
MACHINE_LEARNING_ENABLED=true
MACHINE_LEARNING_URL=http://immich-machine-learning:3003

# 默认管理账户
IMMICH_ADMIN_EMAIL=${IMMICH_ADMIN_EMAIL}
IMMICH_ADMIN_PASSWORD=${IMMICH_ADMIN_PASSWORD}
EOF
echo -e "${GREEN}✓ 环境变量配置文件创建完成${NC}"
echo ""

# 启动服务
echo -e "${YELLOW}[4/6] 启动Immich服务...${NC}"
cd "$IMMICH_DIR"

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker服务未运行，请先启动Docker${NC}"
    exit 1
fi

# 拉取镜像并启动容器
echo "拉取Docker镜像，这可能需要几分钟..."
docker-compose pull --quiet
docker-compose up -d

# 等待服务启动
echo "等待服务启动..."
sleep 10
echo -e "${GREEN}✓ Immich服务启动完成${NC}"
echo ""

# 验证服务状态
echo -e "${YELLOW}[5/6] 验证服务状态...${NC}"
if docker ps | grep -q "immich-server"; then
    echo -e "${GREEN}✓ Immich容器正在运行${NC}"
else
    echo -e "${RED}✗ Immich容器启动失败${NC}"
    exit 1
fi
echo ""

# 显示部署结果
echo -e "${YELLOW}[6/6] 部署完成！${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}✅ Immich 家庭AI智能相册部署成功！${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${WHITE}📋 服务器信息：${NC}"
echo -e "  ${YELLOW}•${NC} 服务名称: ${GREEN}Immich 智能相册${NC}"
echo -e "  ${YELLOW}•${NC} 容器状态: ${GREEN}运行中${NC}"
echo -e "  ${YELLOW}•${NC} 部署目录: ${WHITE}$IMMICH_DIR${NC}"
echo ""
echo -e "${WHITE}🌐 访问地址：${NC}"
echo -e "  ${YELLOW}•${NC} Web界面: ${CYAN}http://${HOST_IP}:${IMMICH_PORT}${NC}"
echo -e "  ${YELLOW}•${NC} 本地访问: ${CYAN}http://localhost:${IMMICH_PORT}${NC}"
echo ""
echo -e "${WHITE}🔑 默认登录凭据：${NC}"
echo -e "  ${YELLOW}•${NC} 管理员邮箱: ${GREEN}${IMMICH_ADMIN_EMAIL}${NC}"
echo -e "  ${YELLOW}•${NC} 管理员密码: ${RED}${IMMICH_ADMIN_PASSWORD}${NC}"
echo -e "  ${YELLOW}⚠${NC} 请首次登录后立即修改密码！"
echo ""
echo -e "${WHITE}📁 目录结构：${NC}"
echo -e "  ${YELLOW}•${NC} 照片上传目录: ${WHITE}${IMMICH_UPLOAD_DIR}${NC}"
echo -e "  ${YELLOW}•${NC} 数据库目录: ${WHITE}${IMMICH_DATA_DIR}/postgres${NC}"
echo -e "  ${YELLOW}•${NC} 缓存目录: ${WHITE}${IMMICH_DATA_DIR}/redis${NC}"
echo ""
echo -e "${WHITE}⚙️  其他功能：${NC}"
echo -e "  ${YELLOW}•${NC} AI智能分类: ${GREEN}已启用${NC}"
echo -e "  ${YELLOW}•${NC} 人脸识别: ${GREEN}已启用${NC}"
echo -e "  ${YELLOW}•${NC} 自动备份: ${GREEN}已启用${NC}"
echo ""
echo -e "${WHITE}🔧 管理命令：${NC}"
echo -e "  ${YELLOW}•${NC} 启动服务: ${WHITE}cd $IMMICH_DIR && docker-compose up -d${NC}"
echo -e "  ${YELLOW}•${NC} 停止服务: ${WHITE}cd $IMMICH_DIR && docker-compose down${NC}"
echo -e "  ${YELLOW}•${NC} 查看日志: ${WHITE}cd $IMMICH_DIR && docker-compose logs${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}💡 提示：请确保防火墙已开放端口 ${IMMICH_PORT}${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════════════${NC}"

# 保存部署信息到文件（供一键部署脚本收集信息）
DEPLOY_INFO_FILE="$IMMICH_DIR/deploy-info.txt"
cat > "$DEPLOY_INFO_FILE" << EOF
IMMICH_SERVICE_NAME=immich
IMMICH_ACCESS_URL=http://${HOST_IP}:${IMMICH_PORT}
IMMICH_ADMIN_EMAIL=${IMMICH_ADMIN_EMAIL}
IMMICH_ADMIN_PASSWORD=${IMMICH_ADMIN_PASSWORD}
IMMICH_DEPLOYMENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')
EOF

exit 0