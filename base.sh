#!/bin/bash

# ============================================
# 反检测重定向系统 - 基础环境安装脚本
# ============================================
# 版本: 3.0 (完美版)
# 功能: 无人值守自动安装所有依赖
# 支持: Ubuntu 22.04 / 24.04
# 特性: 自动化、持久化、开机自启
# ============================================

# 不使用 set -e，改用显式错误检查

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量（固定，无需交互）
MYSQL_ROOT_PASSWORD="Hell0@MaiDong"
export DEBIAN_FRONTEND=noninteractive

# 日志文件
LOG_FILE="/tmp/base_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "============================================"
}

# 错误处理函数
handle_error() {
    log_error "安装过程中出现错误！"
    log_error "请查看日志文件: $LOG_FILE"
    exit 1
}

# 检查用户权限
check_privileges() {
    log_step "检查用户权限"
    
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
        CURRENT_USER="root"
        USER_HOME="/root"
        log_info "✓ 以root用户运行"
    elif sudo -n true 2>/dev/null; then
        SUDO="sudo"
        CURRENT_USER=$USER
        USER_HOME=$HOME
        log_info "✓ 当前用户 $USER 有sudo权限"
    else
        log_error "此脚本需要root权限或sudo权限"
        echo "请使用: sudo bash base.sh"
        exit 1
    fi
}

# 检测系统版本
detect_system() {
    log_step "检测系统环境"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
        log_info "操作系统: $OS_NAME $OS_VERSION"
        log_info "架构: $(uname -m)"
        
        if [[ "$ID" != "ubuntu" ]]; then
            log_warn "此脚本专为Ubuntu优化，当前系统: $ID"
            log_warn "继续执行可能会遇到兼容性问题"
        fi
        
        if [[ "$OS_VERSION" != "22.04" && "$OS_VERSION" != "24.04" ]]; then
            log_warn "推荐使用Ubuntu 22.04或24.04"
            log_warn "当前版本: $OS_VERSION"
        fi
    else
        log_error "无法检测系统版本"
        exit 1
    fi
}

# 更新系统
update_system() {
    log_step "更新系统包列表"
    
    log_info "执行 apt update..."
    $SUDO apt update -qq
    
    log_info "✓ 系统包列表已更新"
}

# 安装基础工具
install_basic_tools() {
    log_step "安装基础工具"
    
    local packages=(
        curl wget git unzip nano vim
        net-tools software-properties-common
        build-essential apt-transport-https
        ca-certificates gnupg lsb-release
    )
    
    log_info "准备安装 ${#packages[@]} 个基础软件包"
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            log_info "  ✓ $package 已安装"
        else
            log_info "  安装 $package..."
            $SUDO apt install -y $package > /dev/null 2>&1
            log_info "  ✓ $package 安装完成"
        fi
    done
    
    log_info "✓ 基础工具安装完成"
}

# 安装Node.js 18.x
install_nodejs() {
    log_step "安装Node.js 18.x"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log_info "✓ Node.js $(node -v) 已安装且版本满足要求"
            log_info "✓ npm $(npm -v) 已安装"
            return 0
        else
            log_warn "Node.js版本过低: $(node -v)，需要升级到18.x"
            log_info "移除旧版本Node.js..."
            $SUDO apt remove -y nodejs > /dev/null 2>&1 || true
        fi
    fi
    
    log_info "添加NodeSource官方仓库..."
    
    # 下载NodeSource安装脚本
    if curl -fsSL https://deb.nodesource.com/setup_18.x -o /tmp/nodesource_setup.sh; then
        log_info "  ✓ NodeSource脚本下载成功"
    else
        log_error "NodeSource脚本下载失败"
        log_error "请检查网络连接"
        exit 1
    fi
    
    # 执行安装脚本
    log_info "  配置NodeSource仓库..."
    if $SUDO bash /tmp/nodesource_setup.sh > /tmp/nodesource_setup.log 2>&1; then
        log_info "  ✓ NodeSource仓库配置完成"
    else
        log_error "NodeSource仓库配置失败"
        cat /tmp/nodesource_setup.log
        exit 1
    fi
    
    # 清理临时文件
    rm -f /tmp/nodesource_setup.sh
    
    log_info "安装Node.js 18.x..."
    if $SUDO apt-get install -y nodejs > /tmp/nodejs_install.log 2>&1; then
        log_info "  ✓ Node.js软件包安装完成"
    else
        log_error "Node.js软件包安装失败"
        tail -20 /tmp/nodejs_install.log
        exit 1
    fi
    
    # 验证安装
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        log_info "✓ Node.js $(node -v) 安装成功"
        log_info "✓ npm $(npm -v) 安装成功"
    else
        log_error "Node.js安装失败"
        log_error "node命令: $(which node 2>&1)"
        log_error "npm命令: $(which npm 2>&1)"
        exit 1
    fi
}

# 安装PM2
install_pm2() {
    log_step "安装PM2进程管理器"
    
    if command -v pm2 &> /dev/null; then
        log_info "✓ PM2 $(pm2 -v) 已安装"
        return 0
    fi
    
    log_info "全局安装PM2..."
    $SUDO npm install -g pm2 > /dev/null 2>&1
    
    if command -v pm2 &> /dev/null; then
        log_info "✓ PM2 $(pm2 -v) 安装成功"
        
        # 配置PM2开机自启
        log_info "配置PM2开机自启..."
        
        if [[ $EUID -eq 0 ]]; then
            # root用户
            pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true
            log_info "✓ PM2已配置为root用户开机自启"
        else
            # 普通用户
            STARTUP_CMD=$(pm2 startup systemd -u $USER --hp $HOME 2>&1 | grep "sudo env" | head -1)
            if [ ! -z "$STARTUP_CMD" ]; then
                eval "$STARTUP_CMD" > /dev/null 2>&1 || true
                log_info "✓ PM2已配置为$USER用户开机自启"
            fi
        fi
        
        log_info "✓ PM2配置完成"
    else
        log_error "PM2安装失败"
        exit 1
    fi
}

# 安装MySQL 8.0
install_mysql() {
    log_step "安装MySQL 8.0"
    
    # 检查MySQL是否已安装
    if command -v mysql &> /dev/null; then
        MYSQL_VERSION=$(mysql -V | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "MySQL $MYSQL_VERSION 已安装"
        
        # 检查密码是否已配置
        if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &> /dev/null; then
            log_info "✓ MySQL root密码已正确配置"
            $SUDO systemctl enable mysql > /dev/null 2>&1
            log_info "✓ MySQL已配置为开机自启"
            return 0
        else
            log_warn "MySQL root密码未配置或不正确，将重新配置"
        fi
    else
        log_info "开始安装MySQL 8.0..."
        
        # 预设root密码（非交互式）
        $SUDO debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
        $SUDO debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"
        
        # 安装MySQL
        log_info "执行apt install mysql-server..."
        $SUDO apt install -y mysql-server > /dev/null 2>&1
        log_info "✓ MySQL软件包安装完成"
    fi
    
    # 启动MySQL服务
    log_info "启动MySQL服务..."
    $SUDO systemctl start mysql
    $SUDO systemctl enable mysql > /dev/null 2>&1
    
    # 等待MySQL启动
    sleep 3
    
    if systemctl is-active --quiet mysql; then
        log_info "✓ MySQL服务运行正常"
        log_info "✓ MySQL已配置为开机自启"
    else
        log_error "MySQL启动失败"
        $SUDO systemctl status mysql
        exit 1
    fi
    
    # 配置MySQL root密码
    log_info "配置MySQL root密码..."
    
    # 方法1: 使用ALTER USER
    $SUDO mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';" 2>/dev/null || true
    $SUDO mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    # 方法2: 使用mysqladmin（如果方法1失败）
    $SUDO mysqladmin -u root password "$MYSQL_ROOT_PASSWORD" 2>/dev/null || true
    
    # 验证密码配置
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &> /dev/null; then
        log_info "✓ MySQL root密码配置成功"
    else
        log_warn "MySQL密码配置可能失败，但继续执行"
        log_warn "稍后会在主脚本中再次尝试配置"
    fi
}

# 安装Redis
install_redis() {
    log_step "安装Redis服务器"
    
    if command -v redis-server &> /dev/null; then
        REDIS_VERSION=$(redis-server --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "Redis $REDIS_VERSION 已安装"
    else
        log_info "开始安装Redis..."
        $SUDO apt install -y redis-server > /dev/null 2>&1
        log_info "✓ Redis软件包安装完成"
    fi
    
    # 配置Redis持久化
    log_info "配置Redis持久化（RDB + AOF）..."
    
    # 备份原配置
    $SUDO cp /etc/redis/redis.conf /etc/redis/redis.conf.backup.$(date +%s) 2>/dev/null || true
    
    # 启用RDB持久化（快照）
    $SUDO sed -i 's/^# save 900 1/save 900 1/' /etc/redis/redis.conf
    $SUDO sed -i 's/^# save 300 10/save 300 10/' /etc/redis/redis.conf
    $SUDO sed -i 's/^# save 60 10000/save 60 10000/' /etc/redis/redis.conf
    
    # 启用AOF持久化（追加日志）
    $SUDO sed -i 's/^appendonly no/appendonly yes/' /etc/redis/redis.conf
    
    # 确保AOF配置存在
    if ! $SUDO grep -q "^appendonly yes" /etc/redis/redis.conf; then
        echo "appendonly yes" | $SUDO tee -a /etc/redis/redis.conf > /dev/null
    fi
    
    if ! $SUDO grep -q "^appendfsync everysec" /etc/redis/redis.conf; then
        echo "appendfsync everysec" | $SUDO tee -a /etc/redis/redis.conf > /dev/null
    fi
    
    # 确保数据目录存在且权限正确
    $SUDO mkdir -p /var/lib/redis
    $SUDO chown redis:redis /var/lib/redis
    $SUDO chmod 750 /var/lib/redis
    
    # 启动Redis服务
    log_info "启动Redis服务..."
    $SUDO systemctl start redis-server
    $SUDO systemctl enable redis-server > /dev/null 2>&1
    
    # 等待Redis启动
    sleep 2
    
    if systemctl is-active --quiet redis-server; then
        log_info "✓ Redis服务运行正常"
        log_info "✓ Redis已配置为开机自启"
        log_info "✓ Redis持久化已配置（RDB每900秒 + AOF每秒同步）"
        
        # 验证Redis连接
        if redis-cli ping &> /dev/null; then
            log_info "✓ Redis连接测试成功"
        fi
    else
        log_error "Redis启动失败"
        $SUDO systemctl status redis-server
        exit 1
    fi
}

# 安装Nginx
install_nginx() {
    log_step "安装Nginx Web服务器"
    
    if command -v nginx &> /dev/null; then
        NGINX_VERSION=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        log_info "Nginx $NGINX_VERSION 已安装"
    else
        log_info "开始安装Nginx..."
        $SUDO apt install -y nginx > /dev/null 2>&1
        log_info "✓ Nginx软件包安装完成"
    fi
    
    # 启动Nginx服务
    log_info "启动Nginx服务..."
    $SUDO systemctl start nginx
    $SUDO systemctl enable nginx > /dev/null 2>&1
    
    if systemctl is-active --quiet nginx; then
        log_info "✓ Nginx服务运行正常"
        log_info "✓ Nginx已配置为开机自启"
    else
        log_warn "Nginx未运行（不影响主程序，可选服务）"
    fi
    
    # 创建webroot目录（用于SSL证书验证）
    log_info "创建SSL验证目录..."
    $SUDO mkdir -p /var/www/html/.well-known/acme-challenge
    $SUDO chown -R www-data:www-data /var/www/html
    log_info "✓ Webroot目录已创建"
}

# 安装SSL证书工具
install_ssl_tools() {
    log_step "安装SSL证书工具"
    
    if command -v certbot &> /dev/null; then
        CERTBOT_VERSION=$(certbot --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "Certbot $CERTBOT_VERSION 已安装"
        return 0
    fi
    
    log_info "安装Certbot和Nginx插件..."
    $SUDO apt install -y certbot python3-certbot-nginx > /dev/null 2>&1
    
    if command -v certbot &> /dev/null; then
        CERTBOT_VERSION=$(certbot --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "✓ Certbot $CERTBOT_VERSION 安装成功"
        log_info "✓ Certbot位置: $(which certbot)"
        log_info "✓ Nginx插件已安装"
    else
        log_warn "Certbot安装失败（不影响主程序，可选工具）"
    fi
}

# 配置UFW防火墙
install_ufw() {
    log_step "配置UFW防火墙"
    
    if ! command -v ufw &> /dev/null; then
        log_info "安装UFW..."
        $SUDO apt install -y ufw > /dev/null 2>&1
    fi
    
    log_info "配置防火墙规则..."
    
    # 先允许SSH，防止锁死
    $SUDO ufw --force allow 22/tcp > /dev/null 2>&1
    log_info "  ✓ 已开放SSH端口 (22)"
    
    # 允许HTTP/HTTPS
    $SUDO ufw --force allow 80/tcp > /dev/null 2>&1
    $SUDO ufw --force allow 443/tcp > /dev/null 2>&1
    log_info "  ✓ 已开放HTTP/HTTPS端口 (80, 443)"
    
    # 允许应用端口
    $SUDO ufw --force allow 3000/tcp > /dev/null 2>&1
    $SUDO ufw --force allow 3001/tcp > /dev/null 2>&1
    log_info "  ✓ 已开放应用端口 (3000, 3001)"
    
    # 配置默认策略但不立即启用
    $SUDO ufw default deny incoming > /dev/null 2>&1
    $SUDO ufw default allow outgoing > /dev/null 2>&1
    
    # 使用yes命令自动确认，避免交互
    yes | $SUDO ufw enable > /dev/null 2>&1 || $SUDO ufw --force enable > /dev/null 2>&1
    
    log_info "✓ 防火墙已配置并启用"
    log_info "  开放端口: 22(SSH), 80(HTTP), 443(HTTPS), 3000(主应用), 3001(管理后台)"
    
    # 给SSH连接一点恢复时间
    sleep 2
}

# 优化系统参数
optimize_system() {
    log_step "优化系统参数"
    
    # 增加文件描述符限制
    if ! grep -q "* soft nofile 65535" /etc/security/limits.conf; then
        log_info "优化文件描述符限制..."
        cat << 'LIMITS' | $SUDO tee -a /etc/security/limits.conf > /dev/null

# Optimization for Redis and Node.js
* soft nofile 65535
* hard nofile 65535
LIMITS
        log_info "✓ 文件描述符限制已优化 (65535)"
    else
        log_info "✓ 文件描述符限制已配置"
    fi
    
    # 优化内核参数
    if ! grep -q "vm.overcommit_memory" /etc/sysctl.conf; then
        log_info "优化内核参数..."
        cat << 'SYSCTL' | $SUDO tee -a /etc/sysctl.conf > /dev/null

# Redis and system optimization
vm.overcommit_memory = 1
net.core.somaxconn = 65535
SYSCTL
        $SUDO sysctl -p > /dev/null 2>&1
        log_info "✓ 内核参数已优化"
        log_info "  vm.overcommit_memory = 1 (Redis优化)"
        log_info "  net.core.somaxconn = 65535 (网络连接优化)"
    else
        log_info "✓ 内核参数已配置"
    fi
}

# 创建必要目录
create_directories() {
    log_step "创建系统目录"
    
    log_info "创建/var/www目录..."
    $SUDO mkdir -p /var/www
    
    log_info "创建备份目录..."
    $SUDO mkdir -p /root/backups
    
    # 设置权限
    if [[ $EUID -ne 0 ]]; then
        log_info "调整/var/www权限..."
        $SUDO chown $USER:$USER /var/www 2>/dev/null || true
    fi
    
    log_info "✓ 目录结构已创建"
}

# 验证所有服务
verify_services() {
    log_step "验证服务状态"
    
    local all_ok=true
    local services_status=""
    
    # Node.js
    if command -v node &> /dev/null; then
        log_info "✓ Node.js $(node -v) - 正常"
        services_status+="Node.js: $(node -v)\n"
    else
        log_error "✗ Node.js未安装"
        all_ok=false
    fi
    
    # npm
    if command -v npm &> /dev/null; then
        log_info "✓ npm $(npm -v) - 正常"
        services_status+="npm: $(npm -v)\n"
    else
        log_error "✗ npm未安装"
        all_ok=false
    fi
    
    # PM2
    if command -v pm2 &> /dev/null; then
        log_info "✓ PM2 $(pm2 -v) - 正常"
        services_status+="PM2: $(pm2 -v)\n"
    else
        log_error "✗ PM2未安装"
        all_ok=false
    fi
    
    # MySQL
    if systemctl is-active --quiet mysql; then
        MYSQL_VER=$(mysql -V | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "✓ MySQL $MYSQL_VER - 运行中，已配置开机自启"
        services_status+="MySQL: $MYSQL_VER (运行中)\n"
    else
        log_error "✗ MySQL未运行"
        all_ok=false
    fi
    
    # Redis
    if systemctl is-active --quiet redis-server; then
        REDIS_VER=$(redis-server --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        log_info "✓ Redis $REDIS_VER - 运行中，已配置开机自启"
        services_status+="Redis: $REDIS_VER (运行中)\n"
    else
        log_error "✗ Redis未运行"
        all_ok=false
    fi
    
    # Nginx
    if systemctl is-active --quiet nginx; then
        NGINX_VER=$(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')
        log_info "✓ Nginx $NGINX_VER - 运行中，已配置开机自启"
        services_status+="Nginx: $NGINX_VER (运行中)\n"
    else
        log_warn "⚠ Nginx未运行（可选服务）"
    fi
    
    # Certbot
    if command -v certbot &> /dev/null; then
        log_info "✓ Certbot - 已安装"
        services_status+="Certbot: 已安装\n"
    else
        log_warn "⚠ Certbot未安装（可选工具）"
    fi
    
    # UFW
    if command -v ufw &> /dev/null; then
        UFW_STATUS=$($SUDO ufw status | head -1)
        log_info "✓ UFW防火墙 - $UFW_STATUS"
        services_status+="UFW: $UFW_STATUS\n"
    fi
    
    if [ "$all_ok" = false ]; then
        log_error "部分核心服务安装失败！"
        log_error "请检查上面的错误信息"
        exit 1
    fi
    
    log_info "✓ 所有核心服务验证通过"
}

# 显示安装总结
show_summary() {
    echo ""
    echo "============================================"
    log_info "基础环境安装完成"
    echo "============================================"
    echo ""
    echo "📦 已安装软件:"
    echo "  ✓ Node.js:   $(node -v)"
    echo "  ✓ npm:       $(npm -v)"
    echo "  ✓ PM2:       $(pm2 -v)"
    echo "  ✓ MySQL:     $(mysql -V | grep -oP '\d+\.\d+\.\d+' | head -1)"
    echo "  ✓ Redis:     $(redis-server --version | grep -oP '\d+\.\d+\.\d+' | head -1)"
    
    if command -v nginx &> /dev/null; then
        echo "  ✓ Nginx:     $(nginx -v 2>&1 | grep -oP '\d+\.\d+\.\d+')"
    fi
    
    if command -v certbot &> /dev/null; then
        echo "  ✓ Certbot:   已安装"
    fi
    
    echo ""
    echo "🔧 配置信息:"
    echo "  MySQL Root密码: $MYSQL_ROOT_PASSWORD"
    echo "  Redis持久化:     RDB + AOF"
    echo "  防火墙:          已启用（UFW）"
    echo "  开机自启:        所有服务已配置"
    echo ""
    echo "📝 日志文件:"
    echo "  $LOG_FILE"
    echo ""
}

# 主函数
main() {
    local START_TIME=$(date +%s)
    
    echo ""
    echo "============================================"
    echo "  反检测重定向系统 - 基础环境安装"
    echo "  版本: 3.0 (完美版)"
    echo "  模式: 无人值守自动安装"
    echo "============================================"
    echo ""
    
    check_privileges
    detect_system
    update_system
    install_basic_tools
    install_nodejs
    install_pm2
    install_mysql
    install_redis
    install_nginx
    install_ssl_tools
    install_ufw
    optimize_system
    create_directories
    verify_services
    show_summary
    
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    
    log_info "✓ 基础环境安装成功！耗时: ${DURATION}秒"
    echo ""
}

# 如果直接运行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
