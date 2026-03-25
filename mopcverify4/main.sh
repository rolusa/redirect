#!/bin/bash

# ============================================
# 反检测重定向系统 - 主部署脚本
# ============================================
# 版本: 3.0 (完美版)
# 功能: 无人值守自动部署完整系统
# 特性: 自动化、文件清理、服务重启
# GitHub: https://github.com
# ============================================

# 不使用 set -e，改用显式错误检查

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 配置变量（固定，无需交互）
GITHUB_URL="https://github.com/rolusa/redirect/raw/refs/heads/main/mopcverify4/redirect-system-prod.zip"
INSTALL_DIR="/var/www/redirect-system"
DB_NAME="redirect_system_prod"
DB_USER="redirect_user"
DB_PASS="Hell0@MaiDong"
MYSQL_ROOT_PASS="Hell0@MaiDong"

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_SH_PATH="$SCRIPT_DIR/base.sh"
MAIN_SH_PATH="$SCRIPT_DIR/main.sh"

# 日志文件
LOG_FILE="/tmp/deploy_$(date +%Y%m%d_%H%M%S).log"
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

log_success() {
    echo -e "${MAGENTA}[SUCCESS]${NC} $1"
}

# 显示欢迎信息
show_welcome() {
    clear
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║        反检测重定向系统 - 自动部署脚本 v3.0                ║
║                                                            ║
║        支持: Ubuntu 22.04 / 24.04                          ║
║        模式: 无人值守自动安装                               ║
║        特性: 完全自动化 + 文件清理 + 服务重启              ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

# 检查用户权限
check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
        log_info "✓ 以root用户运行"
    elif sudo -n true 2>/dev/null; then
        SUDO="sudo"
        log_info "✓ 当前用户有sudo权限"
    else
        log_error "此脚本需要root权限或sudo权限"
        echo "请使用: sudo bash main.sh"
        exit 1
    fi
}

# 显示配置信息
show_config() {
    log_step "部署配置信息"
    echo ""
    echo "  作者Telegram:   @MaiDong"
    echo "  安装目录:     $INSTALL_DIR"
    echo "  数据库名:     $DB_NAME"
    echo "  数据库用户:   $DB_USER"
    echo "  数据库密码:   $DB_PASS"
    echo ""
    log_info "即将开始自动部署（无需人工干预）"
    log_info "整个过程大约需要5-10分钟"
    echo ""
    sleep 3
}

# 错误处理函数
handle_error() {
    log_error "部署过程中出现错误！"
    log_error "请查看日志文件: $LOG_FILE"
    
    # 清理临时文件
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        log_info "已清理临时文件"
    fi
    
    exit 1
}

# 安装基础环境
install_base_environment() {
    log_step "安装基础环境"
    echo ""
    
    # 检查base.sh是否存在
    if [ ! -f "$BASE_SH_PATH" ]; then
        log_error "base.sh文件不存在！"
        log_error "路径: $BASE_SH_PATH"
        log_info "请确保base.sh和main.sh在同一目录"
        exit 1
    fi
    
    # 给base.sh执行权限
    chmod +x "$BASE_SH_PATH"
    
    # 执行base.sh
    log_info "开始安装基础依赖..."
    echo ""
    
    # 直接执行base.sh（不使用source）
    bash "$BASE_SH_PATH"
    
    if [ $? -eq 0 ]; then
        echo ""
        log_success "✓ 基础环境安装完成"
    else
        log_error "基础环境安装失败"
        exit 1
    fi
    
    echo ""
    sleep 2
}

# 下载项目源码
download_source() {
    log_step "下载项目源码"
    echo ""
    
    # 创建临时目录
    TMP_DIR="/tmp/redirect-deploy-$$"
    mkdir -p "$TMP_DIR"
    log_info "临时目录: $TMP_DIR"
    
    log_info "从GitHub下载源码包..."
    log_info "URL: $GITHUB_URL"
    
    # 下载ZIP文件（带进度条）
    if wget -q --show-progress --timeout=60 --tries=3 "$GITHUB_URL" -O "$TMP_DIR/source.zip"; then
        local FILE_SIZE=$(du -h "$TMP_DIR/source.zip" | cut -f1)
        log_success "✓ 源码下载成功 (大小: $FILE_SIZE)"
    else
        log_error "源码下载失败！"
        log_error "请检查："
        log_error "  1. 网络连接是否正常"
        log_error "  2. GitHub URL是否正确"
        log_error "  3. 文件是否存在"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # 验证ZIP文件
    if file "$TMP_DIR/source.zip" | grep -q "Zip archive"; then
        log_info "✓ ZIP文件格式验证通过"
    else
        log_error "下载的文件不是有效的ZIP格式"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # 解压源码
    log_info "解压源码包..."
    cd "$TMP_DIR"
    
    if unzip -q source.zip; then
        log_success "✓ 源码解压完成"
        
        # 删除ZIP文件（需求1）
        rm -f source.zip
        log_info "✓ 已删除源码ZIP文件"
    else
        log_error "源码解压失败"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    echo ""
}

# 安装项目文件
install_project() {
    log_step "安装项目文件"
    echo ""
    
    # 创建安装目录
    log_info "创建安装目录: $INSTALL_DIR"
    $SUDO mkdir -p "$INSTALL_DIR"
    
    # 备份现有安装
    if [ -d "$INSTALL_DIR/src" ]; then
        BACKUP_DIR="$INSTALL_DIR.backup.$(date +%s)"
        log_warn "检测到已存在的安装"
        log_info "备份到: $BACKUP_DIR"
        $SUDO mv "$INSTALL_DIR" "$BACKUP_DIR"
        $SUDO mkdir -p "$INSTALL_DIR"
        log_info "✓ 备份完成"
    fi
    
    # 复制文件
    log_info "复制项目文件..."
    cd "$TMP_DIR"
    
    # 智能查找源码目录
    if [ -f "package.json" ]; then
        # 文件在当前目录
        log_info "源码位于当前目录"
        $SUDO cp -r * "$INSTALL_DIR/" 2>/dev/null || true
        $SUDO cp -r .[!.]* "$INSTALL_DIR/" 2>/dev/null || true
    else
        # 文件在子目录
        SOURCE_DIR=$(find . -maxdepth 1 -type d ! -name "." ! -name ".." | head -1)
        if [ ! -z "$SOURCE_DIR" ]; then
            log_info "源码位于子目录: $SOURCE_DIR"
            $SUDO cp -r "$SOURCE_DIR"/* "$INSTALL_DIR/"
            $SUDO cp -r "$SOURCE_DIR"/.[!.]* "$INSTALL_DIR/" 2>/dev/null || true
        else
            log_error "找不到源码文件"
            exit 1
        fi
    fi
    
    # 验证关键文件
    log_info "验证关键文件..."
    
    if [ ! -f "$INSTALL_DIR/package.json" ]; then
        log_error "package.json文件不存在"
        exit 1
    fi
    log_info "  ✓ package.json"
    
    if [ ! -f "$INSTALL_DIR/production_database.sql" ]; then
        log_error "production_database.sql文件不存在"
        exit 1
    fi
    log_info "  ✓ production_database.sql"
    
    if [ ! -d "$INSTALL_DIR/src" ]; then
        log_error "src目录不存在"
        exit 1
    fi
    log_info "  ✓ src目录"
    
    # 设置权限
    if [[ $EUID -eq 0 ]]; then
        $SUDO chown -R root:root "$INSTALL_DIR"
    else
        $SUDO chown -R $(whoami):$(whoami) "$INSTALL_DIR" 2>/dev/null || true
    fi
    $SUDO chmod -R 755 "$INSTALL_DIR"
    
    log_success "✓ 项目文件安装完成"
    echo ""
    
    # 清理临时文件
    log_info "清理临时文件..."
    rm -rf "$TMP_DIR"
    log_info "✓ 临时目录已删除"
}

# 安装Node.js依赖
install_node_dependencies() {
    log_step "安装Node.js依赖"
    echo ""
    
    cd "$INSTALL_DIR"
    
    log_info "运行 npm install --production"
    log_info "（这可能需要几分钟，请耐心等待）"
    
    # 使用国内镜像加速
    npm config set registry https://registry.npmmirror.com
    log_info "✓ 使用npm镜像加速"
    
    # 安装依赖
    if npm install --production > /tmp/npm-install.log 2>&1; then
        log_success "✓ Node.js依赖安装完成"
        
        # 显示安装的包数量
        local PKG_COUNT=$(cat package.json | grep -c "\"" | awk '{print int($1/2)}')
        log_info "  安装了约 $PKG_COUNT 个依赖包"
    else
        log_error "Node.js依赖安装失败"
        log_error "查看详细日志: /tmp/npm-install.log"
        echo ""
        tail -20 /tmp/npm-install.log
        exit 1
    fi
    
    # 恢复npm镜像
    npm config set registry https://registry.npmjs.org
    
    echo ""
}

# 配置MySQL
setup_mysql() {
    log_step "配置MySQL数据库"
    echo ""
    
    # 确保MySQL运行
    if ! systemctl is-active --quiet mysql; then
        log_info "启动MySQL服务..."
        $SUDO systemctl start mysql
        sleep 3
    fi
    
    # 再次尝试配置root密码（如果base.sh中失败）
    log_info "确认MySQL root密码..."
    if ! mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT 1" &> /dev/null; then
        log_warn "MySQL root密码未配置，尝试配置..."
        $SUDO mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';" 2>/dev/null || true
        $SUDO mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    fi
    
    # 创建数据库
    log_info "创建数据库: $DB_NAME"
    if mysql -u root -p"$MYSQL_ROOT_PASS" << EOF 2>/dev/null
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF
    then
        log_success "✓ 数据库创建成功"
    else
        log_error "数据库创建失败"
        exit 1
    fi
    
    # 创建数据库用户
    log_info "创建数据库用户: $DB_USER"
    if mysql -u root -p"$MYSQL_ROOT_PASS" << EOF 2>/dev/null
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
GRANT PROCESS ON *.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
    then
        log_success "✓ 数据库用户创建成功"
    else
        log_error "数据库用户创建失败"
        exit 1
    fi
    
    # 验证用户权限
    if mysql -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" &> /dev/null; then
        log_info "✓ 数据库用户权限验证通过"
    else
        log_error "数据库用户权限验证失败"
        exit 1
    fi
    
    echo ""
}

# 导入数据库
import_database() {
    log_step "导入数据库结构和数据"
    echo ""
    
    # 查找SQL文件
    SQL_FILE="$INSTALL_DIR/production_database.sql"
    
    if [ ! -f "$SQL_FILE" ]; then
        log_error "找不到数据库SQL文件: $SQL_FILE"
        exit 1
    fi
    
    local FILE_SIZE=$(du -h "$SQL_FILE" | cut -f1)
    log_info "SQL文件: $SQL_FILE (大小: $FILE_SIZE)"
    
    # 导入数据库
    log_info "开始导入数据库..."
    
    if mysql -u root -p"$MYSQL_ROOT_PASS" "$DB_NAME" < "$SQL_FILE" 2>/dev/null; then
        log_success "✓ 数据库导入成功"
    else
        # 尝试使用普通用户导入
        if mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SQL_FILE" 2>/dev/null; then
            log_success "✓ 数据库导入成功"
        else
            log_error "数据库导入失败"
            exit 1
        fi
    fi
    
    # 验证导入
    local TABLE_COUNT=$(mysql -u root -p"$MYSQL_ROOT_PASS" -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB_NAME'" 2>/dev/null)
    
    if [ -z "$TABLE_COUNT" ] || [ "$TABLE_COUNT" -eq 0 ]; then
        log_error "数据库导入验证失败，表数量为0"
        exit 1
    fi
    
    log_info "  ✓ 数据库表数量: $TABLE_COUNT"
    log_success "✓ 数据库验证通过"
    
    # 删除SQL文件（需求1）
    log_info "删除数据库SQL文件..."
    rm -f "$SQL_FILE"
    log_info "✓ production_database.sql 已删除"
    
    echo ""
}

# 配置环境变量
setup_environment() {
    log_step "配置环境变量"
    echo ""
    
    cd "$INSTALL_DIR"
    
    # 检查配置文件
    if [ -f ".env.production" ]; then
        log_info "使用 .env.production 作为模板"
        cp .env.production .env
    elif [ -f ".env" ]; then
        log_info "使用现有 .env 文件"
    else
        log_error "找不到环境变量配置文件"
        exit 1
    fi
    
    # 更新数据库配置
    log_info "更新数据库配置..."
    sed -i "s/^DB_HOST=.*/DB_HOST=localhost/" .env
    sed -i "s/^DB_USER=.*/DB_USER=$DB_USER/" .env
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env
    sed -i "s/^DB_NAME=.*/DB_NAME=$DB_NAME/" .env
    
    # 设置生产环境
    sed -i "s/^NODE_ENV=.*/NODE_ENV=production/" .env
    
    log_success "✓ 环境变量配置完成"
    log_info "  ✓ 数据库配置已更新"
    log_info "  ✓ 生产环境已设置"
    
    echo ""
}

# 创建应用目录
create_app_directories() {
    log_step "创建应用目录"
    echo ""
    
    cd "$INSTALL_DIR"
    
    log_info "创建日志目录..."
    mkdir -p logs
    chmod 755 logs
    log_info "  ✓ logs/"
    
    log_info "创建上传目录..."
    mkdir -p uploads
    chmod 755 uploads
    log_info "  ✓ uploads/"
    
    log_success "✓ 应用目录创建完成"
    echo ""
}

# 启动应用
start_application() {
    log_step "启动应用服务"
    echo ""
    
    cd "$INSTALL_DIR"
    
    # 停止已有进程
    log_info "检查并停止旧进程..."
    pm2 delete redirect-system 2>/dev/null || true
    pm2 delete redirect-admin 2>/dev/null || true
    log_info "✓ 旧进程已清理"
    
    # 启动主应用
    log_info "启动主应用..."
    if [ -f "ecosystem.config.js" ]; then
        pm2 start ecosystem.config.js --env production
        log_info "  ✓ 使用ecosystem.config.js启动"
    else
        pm2 start src/index.js --name redirect-system -i max
        log_info "  ✓ 使用默认配置启动"
    fi
    
    # 启动管理后台
    log_info "启动管理后台..."
    pm2 start src/admin/server.js --name redirect-admin
    log_info "  ✓ 管理后台已启动"
    
    # 保存PM2配置
    log_info "保存PM2配置..."
    pm2 save
    log_info "✓ PM2配置已保存（开机自启）"
    
    echo ""
    sleep 3
    
    # 显示进程状态
    log_info "应用进程状态："
    pm2 list
    
    log_success "✓ 应用启动完成"
    echo ""
}

# 创建管理脚本
create_management_scripts() {
    log_step "创建管理脚本"
    echo ""
    
    # 启动脚本
    cat > /tmp/redirect-start << 'SCRIPT'
#!/bin/bash
cd /var/www/redirect-system
pm2 start ecosystem.config.js --env production 2>/dev/null || pm2 start src/index.js --name redirect-system -i max
pm2 start src/admin/server.js --name redirect-admin
pm2 save
echo "✓ 应用已启动"
SCRIPT
    
    # 停止脚本
    cat > /tmp/redirect-stop << 'SCRIPT'
#!/bin/bash
pm2 stop redirect-system redirect-admin
echo "✓ 应用已停止"
SCRIPT
    
    # 重启脚本
    cat > /tmp/redirect-restart << 'SCRIPT'
#!/bin/bash
pm2 restart redirect-system redirect-admin
echo "✓ 应用已重启"
SCRIPT
    
    # 日志脚本
    cat > /tmp/redirect-logs << 'SCRIPT'
#!/bin/bash
pm2 logs
SCRIPT
    
    # 状态脚本
    cat > /tmp/redirect-status << 'SCRIPT'
#!/bin/bash
echo "=== PM2进程状态 ==="
pm2 list
echo ""
echo "=== 主应用详情 ==="
pm2 show redirect-system
echo ""
echo "=== 管理后台详情 ==="
pm2 show redirect-admin
SCRIPT
    
    # 安装脚本到系统
    $SUDO mv /tmp/redirect-* /usr/local/bin/
    $SUDO chmod +x /usr/local/bin/redirect-*
    
    log_success "✓ 管理脚本创建完成"
    log_info "  ✓ redirect-start   - 启动应用"
    log_info "  ✓ redirect-stop    - 停止应用"
    log_info "  ✓ redirect-restart - 重启应用"
    log_info "  ✓ redirect-logs    - 查看日志"
    log_info "  ✓ redirect-status  - 查看状态"
    
    echo ""
}

# 测试服务
test_services() {
    log_step "测试服务连接"
    echo ""
    
    local all_ok=true
    
    # 测试MySQL
    log_info "测试MySQL连接..."
    if mysql -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" &> /dev/null; then
        log_info "  ✓ MySQL连接正常"
    else
        log_error "  ✗ MySQL连接失败"
        all_ok=false
    fi
    
    # 测试Redis
    log_info "测试Redis连接..."
    if redis-cli ping &> /dev/null; then
        log_info "  ✓ Redis连接正常"
    else
        log_error "  ✗ Redis连接失败"
        all_ok=false
    fi
    
    # 等待应用启动
    log_info "等待应用启动..."
    sleep 5
    
    # 测试主应用
    log_info "测试主应用..."
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        log_info "  ✓ 主应用(端口3000)响应正常"
    else
        log_warn "  ⚠ 主应用暂无响应（可能正在启动）"
    fi
    
    # 测试管理后台
    log_info "测试管理后台..."
    if curl -s http://localhost:3001 > /dev/null 2>&1; then
        log_info "  ✓ 管理后台(端口3001)响应正常"
    else
        log_warn "  ⚠ 管理后台暂无响应（可能正在启动）"
    fi
    
    if [ "$all_ok" = true ]; then
        log_success "✓ 所有服务测试通过"
    else
        log_warn "部分服务测试未通过，但不影响继续"
    fi
    
    echo ""
}

# 清理部署脚本（需求2）
cleanup_scripts() {
    log_step "清理部署脚本"
    echo ""
    
    log_info "准备删除部署脚本..."
    
    # 删除base.sh
    if [ -f "$BASE_SH_PATH" ]; then
        rm -f "$BASE_SH_PATH"
        log_info "  ✓ 已删除 base.sh"
    fi
    
    # 删除main.sh（当前脚本，在最后执行）
    if [ -f "$MAIN_SH_PATH" ]; then
        log_info "  ⏳ main.sh将在脚本结束后自动删除"
    fi
    
    log_success "✓ 部署脚本清理完成"
    echo ""
}

# 显示部署信息
show_deployment_info() {
    local SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
    
    echo ""
    echo "════════════════════════════════════════════════════════════"
    log_success "🎉 部署完成！"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "📦 安装信息:"
    echo "  安装目录:     $INSTALL_DIR"
    echo "  数据库名:     $DB_NAME"
    echo "  数据库用户:   $DB_USER"
    echo "  数据库密码:   $DB_PASS"
    echo ""
    echo "🌐 访问地址:"
    echo "  主应用:       http://$SERVER_IP:3000"
    echo "  管理后台:     http://$SERVER_IP:3001"
    echo ""
    echo "🔑 管理后台登录:"
    echo "  用户名: admin"
    echo "  密码:   (首次登录需要在数据库中查看或重置)"
    echo ""
    echo "📝 常用命令:"
    echo "  redirect-status   - 查看应用状态"
    echo "  redirect-logs     - 查看应用日志"
    echo "  redirect-restart  - 重启应用"
    echo "  redirect-stop     - 停止应用"
    echo "  redirect-start    - 启动应用"
    echo ""
    echo "  PM2命令:"
    echo "    pm2 list        - 查看所有进程"
    echo "    pm2 logs        - 查看实时日志"
    echo "    pm2 monit       - 监控面板"
    echo ""
    echo "📁 重要文件:"
    echo "  应用目录:     $INSTALL_DIR"
    echo "  配置文件:     $INSTALL_DIR/.env"
    echo "  日志目录:     $INSTALL_DIR/logs"
    echo "  部署日志:     $LOG_FILE"
    echo ""
    echo "🔧 下一步操作:"
    echo "  1. 访问管理后台: http://$SERVER_IP:3001"
    echo "  2. 登录并配置域名"
    echo "  3. 配置系统参数（过滤器、白名单等）"
    echo "  4. 批量生成Token链接"
    echo "  5. （可选）配置Nginx和SSL证书"
    echo ""
    echo "⚠️  重要提示:"
    echo "  - 所有服务已配置为开机自启"
    echo "  - Redis已启用持久化（RDB+AOF）"
    echo "  - 防火墙已配置并启用"
    echo "  - 部署脚本已自动清理"
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo ""
}

# 服务器重启提示（需求3）
prompt_reboot() {
    log_step "准备重启服务器"
    echo ""
    
    log_warn "建议重启服务器以确保所有配置生效"
    log_info "系统将在10秒后自动重启..."
    log_info "如需取消，请按 Ctrl+C"
    echo ""
    
    # 倒计时
    for i in {10..1}; do
        echo -ne "\r${YELLOW}重启倒计时: ${i}秒...${NC} "
        sleep 1
    done
    
    echo ""
    echo ""
    log_info "正在重启服务器..."
    log_info "重启后，应用将自动启动"
    echo ""
    
    # 删除main.sh（需求2）
    rm -f "$MAIN_SH_PATH" 2>/dev/null || true
    
    # 重启服务器
    $SUDO reboot
}

# 主函数
main() {
    local START_TIME=$(date +%s)
    
    show_welcome
    check_privileges
    show_config
    
    # 执行部署流程
    install_base_environment
    download_source
    install_project
    install_node_dependencies
    setup_mysql
    import_database
    setup_environment
    create_app_directories
    start_application
    create_management_scripts
    test_services
    cleanup_scripts
    show_deployment_info
    
    # 计算耗时
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local MINUTES=$((DURATION / 60))
    local SECONDS=$((DURATION % 60))
    
    log_success "✓ 部署成功完成！总耗时: ${MINUTES}分${SECONDS}秒"
    echo ""
    
    # 提示重启（需求3）
    prompt_reboot
}

# 执行主函数
main "$@"
