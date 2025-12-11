#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
ORANGE='\033[1;38;5;214m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
TEAL='\033[1;38;5;80m'
MAGENTA='\033[1;38;5;201m'
WHITE='\033[1;37m'
NC='\033[0m'

# 进度条字符
BAR_CHAR="▓"
BAR_EMPTY="░"

# 配置变量
INDEX_URL="https://raw.githubusercontent.com/gaoxing-kai/miller/refs/heads/main/install.txt"
CONTAINER_DIR=""
CONFIG_DIR=""
SELECTED_PROJECTS=()
SERVICES_INFO=()
USED_PORTS=()
PROJECT_CONFIGS=()
HOST_IP=""
PASSWORD_INFO=()

# 总步骤数
TOTAL_STEPS=9
CURRENT_STEP=0

# 函数：显示横幅
show_banner() {
    clear
    echo -e "${TEAL}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║                                                       ║"
    echo "║                 米乐星球一键部署脚本                  ║"
    echo "║                微信交流：kaixin17770                  ║"
    echo "║                                                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}提示: 按任意键开始部署...${NC}"
    read -n 1 -s -r
    echo ""
}

# 函数：显示步骤标题
show_step() {
    ((CURRENT_STEP++))
    local progress=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local progress_bar=$(get_progress_bar $progress)
    echo -e "${TEAL}步骤 $CURRENT_STEP/$TOTAL_STEPS [$progress%] $progress_bar ➤ $1${NC}"
}

# 获取进度条
get_progress_bar() {
    local percent=$1
    local width=20
    local completed=$((percent * width / 100))
    local remaining=$((width - completed))
    
    local bar=""
    for ((i=0; i<completed; i++)); do
        bar+="${GREEN}${BAR_CHAR}${NC}"
    done
    for ((i=0; i<remaining; i++)); do
        bar+="${CYAN}${BAR_EMPTY}${NC}"
    done
    echo "[$bar]"
}

# 进度显示函数
show_progress() { echo -e "  ${TEAL}↳${NC} $1"; }
show_warning() { echo -e "  ${ORANGE}⚠${NC} $1"; }
show_error() { echo -e "  ${RED}✗${NC} $1"; }
show_success() { echo -e "  ${GREEN}✓${NC} $1"; }
show_info() { echo -e "  ${GREEN}✓${NC} $1"; }

# 检查系统依赖和Docker状态
check_system() {
    show_step "系统环境检查"
    
    local deps=("curl" "docker" "docker-compose")
    local all_ok=true
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            show_error "缺少依赖: $dep"
            all_ok=false
        fi
    done
    
    if ! docker info > /dev/null 2>&1; then
        show_error "Docker服务未运行或权限不足"
        all_ok=false
    fi
    
    if [ "$all_ok" = true ]; then
        show_success "系统环境检查通过"
        
        # 显示版本信息
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        show_info "Docker $docker_version, Compose $compose_version"
    else
        show_error "系统环境检查未通过，请先解决上述问题"
        exit 1
    fi
}

# 配置容器目录和确认
setup_and_confirm_directories() {
    show_step "目录配置"
    
    # 设置默认Docker路径
    local default_docker_path="/volume1/docker"
    if [ -d "/volume2/docker" ]; then
        default_docker_path="/volume2/docker"
    fi
    
    echo -e "${YELLOW}请输入容器目录路径 (回车使用默认: $default_docker_path):${NC}"
    read -p "路径: " custom_dir
    
    if [ -z "$custom_dir" ]; then
        CONTAINER_DIR="$default_docker_path"
    else
        CONTAINER_DIR="${custom_dir%/}"
    fi
    
    # 创建目录
    mkdir -p "$CONTAINER_DIR"
    if [ $? -ne 0 ]; then
        show_error "无法创建容器目录: $CONTAINER_DIR"
        exit 1
    fi
    
    # 设置配置目录
    CONFIG_DIR="$CONTAINER_DIR/config"
    mkdir -p "$CONFIG_DIR"
    
    # 显示配置确认
    echo ""
    echo -e "${YELLOW}请确认配置信息:${NC}"
    echo -e "${GREEN}┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ 容器目录: $CONTAINER_DIR${NC}"
    echo -e "${GREEN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    
    read -p "确认开始部署? [Y/n]: " confirm_choice
    if [[ $confirm_choice =~ ^[Nn]$ ]]; then
        show_info "部署已取消"
        exit 0
    fi
}

# 获取远程索引
fetch_remote_index() {
    show_step "获取项目列表"
    
    local index_file="$CONFIG_DIR/install.txt"
    
    if curl -fsSL "$INDEX_URL" -o "$index_file"; then
        show_success "索引文件下载成功"
        
        # 检查并清理索引文件
        if cleanup_index_file "$index_file"; then
            show_success "索引文件清理完成"
        else
            show_warning "索引文件清理失败，但将继续处理"
        fi
    else
        show_error "索引文件下载失败"
        return 1
    fi
}

# 清理索引文件（移除BOM字符）
cleanup_index_file() {
    local index_file="$1"
    
    if [ ! -f "$index_file" ]; then
        return 1
    fi
    
    # 移除Windows换行符
    sed -i 's/\r$//' "$index_file"
    
    # 移除空白行和注释行
    sed -i '/^[[:space:]]*$/d' "$index_file"
    sed -i '/^[[:space:]]*#/d' "$index_file"
    
    # 检查文件是否为空
    if [ ! -s "$index_file" ]; then
        show_error "索引文件为空"
        return 1
    fi
    
    return 0
}

# 解析索引文件（修复格式问题）
parse_index_file() {
    local index_file="$CONFIG_DIR/install.txt"
    
    if [ ! -f "$index_file" ]; then
        show_error "索引文件不存在"
        return 1
    fi
    
    # 清空项目数组
    PROJECT_CONFIGS=()
    
    # 读取并解析索引文件
    local line_count=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        # 跳过空行
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # 处理包含BOM字符的行
        line=$(echo "$line" | sed 's/^\xEF\xBB\xBF//' | sed 's/\r$//')
        
        # 跳过注释行
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # 修复格式问题：使用 | 作为分隔符
        if [[ "$line" =~ ^([^|]+)\|([^|]*)\|([^|]+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local description="${BASH_REMATCH[2]}"
            local url="${BASH_REMATCH[3]}"
            
            # 清理字段
            name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            url=$(echo "$url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # 如果描述为空，设置默认描述
            if [ -z "$description" ]; then
                description="Docker应用服务"
            fi
            
            PROJECT_CONFIGS+=("$name|$description|$url")
            ((line_count++))
        # 处理旧格式（兼容性）
        elif [[ "$line" =~ ^([^:]+):([^:]*):([^:]+)$ ]]; then
            local name="${BASH_REMATCH[1]}"
            local description="${BASH_REMATCH[2]}"
            local url="${BASH_REMATCH[3]}"
            
            # 清理字段
            name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            description=$(echo "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            url=$(echo "$url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # 如果描述为空，设置默认描述
            if [ -z "$description" ]; then
                description="Docker应用服务"
            fi
            
            PROJECT_CONFIGS+=("$name|$description|$url")
            ((line_count++))
        else
            show_warning "忽略格式错误行: $line"
        fi
    done < "$index_file"
    
    if [ $line_count -eq 0 ]; then
        show_error "索引文件中未找到有效项目"
        return 1
    fi
    
    show_success "发现 $line_count 个可部署项目"
    return 0
}

# 获取主机IP地址
get_host_ip() {
    HOST_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    
    if [ -z "$HOST_IP" ]; then
        HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    if [ -z "$HOST_IP" ]; then
        HOST_IP="localhost"
    fi
    
    show_info "主机地址: $HOST_IP"
}

# 获取已占用端口
get_used_ports() {
    USED_PORTS=($(netstat -tuln 2>/dev/null | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -un))
    show_info "检测到 ${#USED_PORTS[@]} 个已占用端口"
}

# 检查端口冲突
check_port_conflict() {
    local port=$1
    for used_port in "${USED_PORTS[@]}"; do
        if [ "$used_port" == "$port" ]; then
            return 0
        fi
    done
    return 1
}

# 显示项目选择菜单（表格形式）
show_project_menu() {
    show_step "项目选择"
    
    echo -e "${YELLOW}请选择要部署的项目 (可多选，用空格分隔):${NC}"
    echo ""
    
    # 检查是否有项目
    if [ ${#PROJECT_CONFIGS[@]} -eq 0 ]; then
        show_error "没有可用的项目"
        exit 1
    fi
    
    # 显示表格头
    echo -e "${GREEN}┌──────┬──────────────────────┬─────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ 编号 │ 项目名称             │ 项目描述                            │${NC}"
    echo -e "${GREEN}├──────┼──────────────────────┼─────────────────────────────────────┤${NC}"
    
    local i=1
    local options=()
    
    # 显示项目列表
    for config in "${PROJECT_CONFIGS[@]}"; do
        IFS='|' read -r project_name project_description config_url <<< "$config"
        options[$i]="$project_name|$project_description|$config_url"
        
        # 格式化输出表格行
        printf "│ ${GREEN}%3d${NC}  │ ${GREEN}%-20s${NC}  ${CYAN}%-41s${NC} \n" "$i" "$project_name" "$project_description"
        ((i++))
    done
    
    local total_options=$((i-1))
    local all_option=$i
    local exit_option=0
    
    # 显示表格尾和选项
    echo -e "${GREEN}├──────┼──────────────────────┼─────────────────────────────────────┤${NC}"
    printf "│ ${TEAL}%3d${NC}  │ ${TEAL}%-24s${NC} │ ${TEAL}%-43s${NC} │\n" "$all_option" "全部部署" "部署所有可用项目"
    printf "│ ${RED}%3d${NC}  │ ${RED}%-24s${NC} │ ${RED}%-41s${NC} │\n" "$exit_option" "退出部署" "取消部署操作"
    echo -e "${GREEN}└──────┴──────────────────────┴─────────────────────────────────────┘${NC}"
    echo ""
    
    read -p "请输入选择 [0-$all_option]: " -a choices
    
    if [[ " ${choices[@]} " =~ "0" ]]; then
        show_info "部署已取消"
        exit 0
    fi
    
    if [[ " ${choices[@]} " =~ "$all_option" ]]; then
        SELECTED_PROJECTS=("${PROJECT_CONFIGS[@]}")
        show_success "选择全部 ${#PROJECT_CONFIGS[@]} 个项目"
        return
    fi
    
    for choice in "${choices[@]}"; do
        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ] 2>/dev/null; then
            SELECTED_PROJECTS+=("${options[$choice]}")
        fi
    done
    
    if [ ${#SELECTED_PROJECTS[@]} -eq 0 ]; then
        show_error "未选择任何项目"
        exit 1
    fi
    
    show_success "已选择 ${#SELECTED_PROJECTS[@]} 个项目"
}

# 下载项目配置（修复URL格式问题）
download_project_configs() {
    show_step "下载项目配置"
    
    local total=${#SELECTED_PROJECTS[@]}
    local current=0
    
    for project_config in "${SELECTED_PROJECTS[@]}"; do
        IFS='|' read -r project_name project_description config_url <<< "$project_config"
        local config_file="$CONFIG_DIR/$project_name.yml"
        
        ((current++))
        show_progress "下载 $project_name 配置... [$current/$total]"
        
        # 确保URL以http或https开头
        if [[ ! "$config_url" =~ ^https?:// ]]; then
            # 尝试修复URL格式
            if [[ "$config_url" =~ ^// ]]; then
                config_url="https:$config_url"
            else
                config_url="https://$config_url"
            fi
        fi
        
        # 清理URL中的空格
        config_url=$(echo "$config_url" | sed 's/[[:space:]]*$//')
        
        if curl -fsSL "$config_url" -o "$config_file"; then
            # 清理配置文件（移除BOM字符）
            sed -i 's/\xEF\xBB\xBF//' "$config_file" 2>/dev/null
            sed -i 's/\r$//' "$config_file" 2>/dev/null
            
            # 检查配置文件是否有效
            if [ -s "$config_file" ]; then
                show_success "$project_name 配置下载成功"
            else
                show_error "$project_name 配置文件为空或无效"
                rm -f "$config_file"
                return 1
            fi
        else
            show_error "$project_name 配置下载失败: $config_url"
            return 1
        fi
    done
    return 0
}

# 智能分析YAML文件中的存储路径（精确版）- 只处理以./开头的相对路径
analyze_yaml_directories() {
    local config_file="$1"
    local project_name="$2"
    local directories=()
    
    # 创建项目主目录（始终创建）
    local project_main_dir="$CONTAINER_DIR/$project_name"
    directories+=("$project_main_dir")
    
    # 从volumes部分提取目录路径（只处理以./开头的相对路径）
    if [ -f "$config_file" ]; then
        # 查找volumes部分
        local in_volumes=false
        while IFS= read -r line; do
            # 检查是否进入volumes部分
            if [[ "$line" =~ ^[[:space:]]*volumes: ]]; then
                in_volumes=true
                continue
            fi
            
            # 检查是否离开volumes部分
            if [[ "$in_volumes" = true && "$line" =~ ^[[:space:]]*[^[:space:]#-] ]]; then
                in_volumes=false
            fi
            
            # 处理volumes部分的内容 - 只关注以./开头的路径
            if [[ "$in_volumes" = true && "$line" =~ ^[[:space:]]*-[[:space:]]*\./([^:]+): ]]; then
                local relative_path="${BASH_REMATCH[1]}"
                
                # 清理路径
                relative_path=$(echo "$relative_path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                relative_path=$(echo "$relative_path" | sed 's/^"//;s/"$//')
                relative_path=$(echo "$relative_path" | sed "s|^'||;s|'$||")
                
                # 构建完整路径：项目主目录 + 相对路径（去掉./）
                local full_path="$project_main_dir/$relative_path"
                
                # 清理路径中的特殊字符和重复斜杠
                full_path=$(echo "$full_path" | sed 's|//|/|g')
                full_path=$(echo "$full_path" | sed 's|/$||')
                
                # 添加到目录列表
                if [[ -n "$full_path" && "$full_path" != *" "* ]]; then
                    directories+=("$full_path")
                fi
            fi
        done < "$config_file"
    fi
    
    # 去重并返回
    printf "%s\n" "${directories[@]}" | sort -u
}

# 创建精确目录结构 - 只处理项目主目录和./开头的相对路径
create_smart_directories() {
    show_step "创建目录结构"
    
    local total_created=0
    local total_dirs=0
    
    for project_config in "${SELECTED_PROJECTS[@]}"; do
        IFS='|' read -r project_name project_description config_url <<< "$project_config"
        local config_file="$CONFIG_DIR/$project_name.yml"
        
        show_progress "分析 $project_name 目录结构..."
        
        # 智能分析YAML文件中的目录（只处理./开头的相对路径）
        local directories=($(analyze_yaml_directories "$config_file" "$project_name"))
        
        # 创建目录
        for dir in "${directories[@]}"; do
            if [ ! -d "$dir" ]; then
                mkdir -p "$dir"
                if [ $? -eq 0 ]; then
                    ((total_created++))
                    echo -e "    ${GREEN}✓${NC} 创建: $dir"
                else
                    echo -e "    ${RED}✗${NC} 失败: $dir"
                fi
            else
                echo -e "    ${CYAN}ℹ${NC} 已存在: $dir"
            fi
            ((total_dirs++))
        done
    done
    
    if [ $total_created -gt 0 ]; then
        show_success "成功创建 $total_created/$total_dirs 个目录"
    else
        show_info "所有目录已存在"
    fi
}

# 处理端口冲突
handle_port_conflicts() {
    show_step "检查端口冲突"
    
    local conflict_found=0
    
    for project_config in "${SELECTED_PROJECTS[@]}"; do
        IFS='|' read -r project_name project_description config_url <<< "$project_config"
        local config_file="$CONFIG_DIR/$project_name.yml"
        
        if [ ! -f "$config_file" ]; then
            continue
        fi
        
        # 提取端口
        while IFS= read -r port_mapping; do
            local port=$(echo "$port_mapping" | awk -F: '{print $1}' | grep -E '^[0-9]+$')
            if [ -n "$port" ] && check_port_conflict "$port"; then
                show_warning "端口冲突: $port (项目: $project_name)"
                conflict_found=1
                
                # 自动分配新端口
                local new_port=$((port + 1000))
                while [ $new_port -le 65535 ] && check_port_conflict "$new_port"; do
                    ((new_port++))
                done
                
                if [ $new_port -le 65535 ]; then
                    sed -i "s|$port:|$new_port:|g" "$config_file"
                    show_success "自动分配新端口: $port → $new_port"
                else
                    show_error "无法为端口 $port 分配新端口，请手动解决"
                fi
            fi
        done < <(grep -E "ports:" -A 10 "$config_file" | grep -Eo '[0-9]+:[0-9]+')
    done
    
    if [ $conflict_found -eq 0 ]; then
        show_success "端口检查通过"
    fi
}

# 部署项目（使用原版docker compose进度显示）
deploy_projects() {
    show_step "部署项目"
    
    local success_count=0
    local total_count=${#SELECTED_PROJECTS[@]}
    local current=1
    
    for project_config in "${SELECTED_PROJECTS[@]}"; do
        IFS='|' read -r project_name project_description config_url <<< "$project_config"
        local project_dir="$CONTAINER_DIR/$project_name"
        
        echo -e "${CYAN}[$current/$total_count] 部署 $project_name ${NC}"
        
        # 创建项目目录
        mkdir -p "$project_dir"
        
        # 复制配置文件
        local config_file="$CONFIG_DIR/$project_name.yml"
        local deploy_file="$project_dir/docker-compose.yml"
        
        if [ ! -f "$config_file" ]; then
            show_error "$project_name 配置文件不存在"
            ((current++))
            continue
        fi
        
        # 替换路径变量
        sed "s|{STORAGE_PATH}|$CONTAINER_DIR|g" "$config_file" > "$deploy_file"
        sed -i "s|\${PWD}|$CONTAINER_DIR|g" "$deploy_file"
        
        # 切换到项目目录
        cd "$project_dir" || {
            show_error "无法进入项目目录: $project_dir"
            ((current++))
            continue
        }
        
        # 使用原版docker compose进度显示
        show_progress "拉取镜像并启动服务..."
        echo -e "    ${GREEN}正在部署...${NC}"
        
        # 直接使用docker-compose up -d，显示原生进度条
        if docker-compose up -d; then
            show_success "$project_name 部署成功"
            ((success_count++))
            
            # 提取登录信息
            extract_login_info "$config_file" "$project_name"
        else
            show_error "$project_name 部署失败"
            
            # 尝试使用静默模式重试
            show_progress "尝试使用静默模式重试..."
            if docker-compose up -d --quiet; then
                show_success "$project_name 静默模式部署成功"
                ((success_count++))
                
                # 提取登录信息
                extract_login_info "$config_file" "$project_name"
            else
                show_error "$project_name 最终部署失败"
            fi
        fi
        
        ((current++))
        echo ""
    done
    
    echo ""
    if [ $success_count -eq $total_count ]; then
        show_success "所有项目部署完成 ($success_count/$total_count)"
    else
        show_warning "部分项目部署完成 ($success_count/$total_count)"
    fi
}

# 从YAML文件提取登录信息
extract_login_info() {
    local config_file="$1"
    local project_name="$2"
    
    if [ ! -f "$config_file" ]; then
        return
    fi
    
    # 常见的环境变量模式
    local username_patterns=("USERNAME" "AUTH_USERNAME" "AUTH_USER" "ADMIN_USER")
    local password_patterns=("PASSWORD" "PASS" "AUTH_PASSWORD" "AUTH_PASS" "ADMIN_PASSWORD")
    
    local username=""
    local password=""
    
    # 查找用户名
    for pattern in "${username_patterns[@]}"; do
        username=$(grep -i "$pattern" "$config_file" | head -1 | grep -oE '[=:][[:space:]]*[^[:space:]#]+' | sed 's/^[=:[:space:]]*//' | head -1)
        if [ -n "$username" ]; then
            break
        fi
    done
    
    # 查找密码
    for pattern in "${password_patterns[@]}"; do
        password=$(grep -i "$pattern" "$config_file" | head -1 | grep -oE '[=:][[:space:]]*[^[:space:]#]+' | sed 's/^[=:[:space:]]*//' | head -1)
        if [ -n "$password" ]; then
            break
        fi
    done
    
    # 如果找到登录信息，添加到数组
    if [ -n "$username" ] && [ -n "$password" ]; then
        PASSWORD_INFO+=("$project_name|用户名: $username, 密码: $password")
    elif [ -n "$password" ]; then
        PASSWORD_INFO+=("$project_name|密码: $password")
    elif [ -n "$username" ]; then
        PASSWORD_INFO+=("$project_name|用户名: $username")
    fi
}

# 收集服务信息 - 修改为每个项目只显示前2个端口
collect_service_info() {
    for project_config in "${SELECTED_PROJECTS[@]}"; do
        IFS='|' read -r project_name project_description config_url <<< "$project_config"
        local config_file="$CONFIG_DIR/$project_name.yml"
        
        if [ ! -f "$config_file" ]; then
            continue
        fi
        
        # 提取端口信息，但只取前2个
        local port_count=0
        while IFS= read -r port_mapping; do
            local port=$(echo "$port_mapping" | awk -F: '{print $1}' | grep -E '^[0-9]+$')
            if [ -n "$port" ]; then
                SERVICES_INFO+=("$project_name|http://$HOST_IP:$port|$project_description")
                ((port_count++))
                
                # 每个项目只显示前2个端口
                if [ $port_count -ge 2 ]; then
                    break
                fi
            fi
        done < <(grep -E "ports:" -A 10 "$config_file" | grep -Eo '[0-9]+:[0-9]+')
        
        # 如果这个项目有端口但没有收集到（可能是其他格式），至少显示一个
        if [ $port_count -eq 0 ]; then
            # 尝试查找其他格式的端口
            local port=$(grep -E "ports:" -A 5 "$config_file" | grep -Eo '\"[0-9]+\:[0-9]+\"' | sed 's/\"//g' | awk -F: '{print $1}' | head -1)
            if [ -n "$port" ]; then
                SERVICES_INFO+=("$project_name|http://$HOST_IP:$port|$project_description")
            fi
        fi
    done
}

# 显示部署结果
show_deployment_result() {
    show_step "部署完成"
    
    echo ""
    echo -e "${GREEN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                   部署成功！所有服务已启动                  ║${NC}"
    echo -e "${GREEN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 显示服务访问信息
    if [ ${#SERVICES_INFO[@]} -gt 0 ]; then
        echo -e "${RED}服务访问地址:${NC}"
        echo -e "${MAGENTA}┌────────────────────────────────────────────────────────────┐${NC}"
        for service in "${SERVICES_INFO[@]}"; do
            IFS='|' read -r name url desc <<< "$service"
            echo -e "${MAGENTA}│${NC} ${GREEN}$name:${NC} $url"
            echo -e "${MAGENTA}│${NC} ${GREEN}描述:${NC} $desc"
            echo -e "${MAGENTA}│${NC}"
        done
        echo -e "${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
    
    # 显示登录信息
    if [ ${#PASSWORD_INFO[@]} -gt 0 ]; then
        echo -e "${RED}登录信息:${NC}"
        echo -e "${MAGENTA}┌────────────────────────────────────────────────────────────┐${NC}"
        for info in "${PASSWORD_INFO[@]}"; do
            IFS='|' read -r service password <<< "$info"
            echo -e "${MAGENTA}│${NC} ${GREEN}$service:${NC} $password"
        done
        echo -e "${MAGENTA}└────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
}

# 主执行流程
main() {
    show_banner
    
    # 第一阶段：系统检查和配置
    check_system
    setup_and_confirm_directories
    
    # 第二阶段：项目部署
    fetch_remote_index || exit 1
    parse_index_file || exit 1
    get_host_ip
    get_used_ports
    show_project_menu
    download_project_configs || exit 1
    handle_port_conflicts
    create_smart_directories
    deploy_projects
    collect_service_info
    
    # 第三阶段：显示结果
    show_deployment_result
}

# 信号处理
trap 'show_error "脚本被中断"; exit 1' INT TERM

# 执行主函数
main "$@"