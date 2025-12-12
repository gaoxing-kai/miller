#!/bin/bash
# config.sh - 通用配置变量文件

# GitHub 仓库配置
GITHUB_USER="gaoxing-kai"
GITHUB_REPO="miller"
GITHUB_BRANCH="main"
INDEX_FILE="install.txt"

# 构建完整的索引URL
INDEX_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/${INDEX_FILE}"

# 系统配置
CONFIG_DIR="${HOME}/.nas-deployer"
PASSWORD_FILE="${CONFIG_DIR}/mima.txt"
LOG_FILE="${CONFIG_DIR}/deploy.log"

# Docker 配置
DOCKER_COMPOSE_VERSION="v2"  # v1 或 v2

# 颜色配置
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 进度条字符
BAR_CHAR="▓"
BAR_EMPTY="░"

# 导出所有变量
export GITHUB_USER GITHUB_REPO GITHUB_BRANCH INDEX_FILE INDEX_URL
export CONFIG_DIR PASSWORD_FILE LOG_FILE DOCKER_COMPOSE_VERSION
export RED GREEN YELLOW BLUE MAGENTA CYAN WHITE NC
export BAR_CHAR BAR_EMPTY