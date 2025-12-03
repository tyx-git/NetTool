#!/bin/bash

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 全局变量
declare -g SILENT_MODE=false
declare -g OUTPUT_FORMAT="text"  # text, json

# 网络接口缓存
declare -a CACHED_INTERFACES=()
declare -i CACHE_TIMESTAMP=0
readonly CACHE_TIMEOUT=60  # 缓存超时时间（秒）

# 系统信息缓存
declare -A SYSTEM_INFO_CACHE=()
declare -i SYSTEM_INFO_CACHE_TIME=0
readonly SYSTEM_INFO_CACHE_TIMEOUT=300  # 5分钟缓存超时

# 命令缓存
declare -A COMMAND_CACHE=()
declare -A COMMAND_PATHS=()

# 预定义的DNS服务器列表
declare -A PRESET_DNS_SERVERS=(
    ["谷歌DNS"]="8.8.8.8 8.8.4.4"
    ["腾讯DNS"]="119.29.29.29 182.254.116.116"
    ["阿里DNS"]="223.5.5.5 223.6.6.6"
    ["百度DNS"]="180.76.76.76"
    ["Cloudflare"]="1.1.1.1 1.0.0.1"
    ["OpenDNS"]="208.67.222.222 208.67.220.220"
)

# 初始化函数
initialize() {
    # 设置脚本退出时的清理函数
    trap cleanup EXIT
    
    # 设置脚本在遇到错误时退出
    set -e
    
    # 设置脚本在使用未定义变量时退出
    set -u
    
    # 设置管道中任何一个命令失败时整个管道失败
    set -o pipefail
    
    # 检查终端是否支持颜色
    if [[ -t 1 ]]; then
        # 终端支持颜色
        :
    else
        # 重置颜色变量为空，以便在不支持颜色的环境中正常工作
        RED=''
        GREEN=''
        YELLOW=''
        BLUE=''
        PURPLE=''
        CYAN=''
        WHITE=''
        NC=''
    fi
}

# 清理函数
cleanup() {
    # 在脚本退出时执行清理工作
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
            log_success "脚本执行完成，感谢使用网络工具套件！"
        fi
    else
        if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
            log_error "脚本执行出现错误，退出码: $exit_code"
        fi
    fi
    
    # 返回原始退出码
    exit $exit_code
}

# 显示版本信息
show_version() {
    echo "网络工具套件 v2.0"
    echo "适用于Linux系统的网络诊断和配置工具"
    echo "作者: 网络工具开发团队"
    echo "许可证: MIT License"
}

# 显示帮助信息
show_help() {
    show_version
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -v, --version           显示版本信息"
    echo "  -s, --silent            静默模式，减少输出信息"
    echo "  -j, --json              JSON格式输出"
    echo "  --comprehensive-check   全面系统检测"
    echo "  --repair-dns            修复DNS配置"
    echo "  --repair-docker         配置Docker国内镜像源"
    echo "  --install-tools         安装缺失的网络工具"
    echo ""
    echo "交互模式菜单:"
    echo "  1. 检测类功能"
    echo "    1.1 检查网络接口状态"
    echo "    1.2 全面系统检测"
    echo "    1.3 显示网络信息"
    echo "    1.4 检查Docker镜像源"
    echo "  2. 修复类功能"
    echo "    2.1 修复DNS配置"
    echo "    2.2 配置Docker国内镜像源"
    echo "    2.3 安装缺失的网络工具"
    echo "    2.4 修复网络接口问题"
    echo "  3. 暂时更新DNS解析地址"
    echo "  4. 永久更新DNS解析地址"
    echo "  5. 配置GPG密钥"
    echo "  6. 网络诊断工具"
    echo "  0. 退出脚本"
    echo ""
    echo "示例:"
    echo "  $0                      启动交互式菜单"
    echo "  $0 --comprehensive-check 全面系统检测"
    echo "  $0 --repair-dns         修复DNS配置"
    echo "  $0 --repair-docker      配置Docker国内镜像源"
    echo "  $0 -s --comprehensive-check 静默模式全面检测"
    echo "  $0 -j --comprehensive-check JSON格式输出检测结果"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -s|--silent)
                SILENT_MODE=true
                shift
                ;;
            -j|--json)
                OUTPUT_FORMAT="json"
                shift
                ;;
            --comprehensive-check)
                comprehensive_check
                exit 0
                ;;
            --repair-dns)
                repair_dns_configuration
                exit 0
                ;;
            --repair-docker)
                repair_docker_mirror
                exit 0
                ;;
            --install-tools)
                install_missing_network_tools
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 静默模式的日志函数
log_silent() {
    if [ "$SILENT_MODE" = false ]; then
        echo -e "$1"
    fi
}

# 重写日志函数以支持静默模式
log_info() {
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{\"level\": \"info\", \"message\": \"$1\"}"
    else
        log_silent "${BLUE}[信息]${NC} $1"
    fi
}

log_warn() {
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{\"level\": \"warn\", \"message\": \"$1\"}"
    else
        log_silent "${YELLOW}[警告]${NC} $1"
    fi
}

log_error() {
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{\"level\": \"error\", \"message\": \"$1\"}" >&2
    else
        log_silent "${RED}[错误]${NC} $1" >&2
    fi
}

log_success() {
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "{\"level\": \"success\", \"message\": \"$1\"}"
    else
        log_silent "${GREEN}[成功]${NC} $1"
    fi
}

log_debug() {
    if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        echo -e "${CYAN}[调试]${NC} $1"
    fi
}

log_header() {
    if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        echo -e "${PURPLE}==============================${NC}"
        echo -e "${PURPLE}$1${NC}"
        echo -e "${PURPLE}==============================${NC}"
    fi
}

# 显示标题（静默模式下不显示）
show_header() {
    if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        clear
        echo -e "${CYAN}"
        echo "    _   _____________(_)___  / /_"
        echo "   / | / / ___/ ___/ / __ \\/ __/"
        echo "  /  |/ / /  / /__/ / /_/ / /_  "
        echo " /_/|_/_/   \\___/_/ .___/\\__/  "
        echo "                 /_/           "
        echo -e "${NC}"
        echo -e "${WHITE}网络工具套件 v2.0${NC}"
        echo -e "${WHITE}适用于Linux系统的网络诊断和配置工具${NC}"
        echo ""
    fi
}

# 性能优化：检查root权限（减少系统调用）
check_root() {
    # 使用UID而不是id命令减少系统调用
    if (( EUID != 0 )); then
        log_error "此脚本需要以root权限运行。请使用sudo执行。"
        exit 1
    fi
}

# 性能优化：预加载常用命令路径
declare -A COMMAND_PATHS=()

preload_commands() {
    local cmds=("ip" "sed" "cp" "date" "ping" "gpg" "ss" "netstat" "hostname" "whoami")
    
    for cmd in "${cmds[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            COMMAND_PATHS["$cmd"]="$(command -v "$cmd")"
        fi
    done
}

# 性能优化：使用预加载的命令路径
run_command() {
    local cmd="$1"
    shift
    
    if [[ -n "${COMMAND_PATHS[$cmd]+isset}" ]]; then
        "${COMMAND_PATHS[$cmd]}" "$@"
    else
        # 如果未预加载，则直接执行
        "$cmd" "$@"
    fi
}

# 性能优化：检查命令是否存在（带缓存）
declare -A COMMAND_CACHE=()

# 性能优化：优化检查命令函数
check_command() {
    local cmd="$1"
    
    # 检查缓存
    if [[ -n "${COMMAND_CACHE[$cmd]+isset}" ]]; then
        if [[ "${COMMAND_CACHE[$cmd]}" == "found" ]]; then
            return 0
        else
            log_error "命令 '$cmd' 未找到，请先安装。"
            exit 1
        fi
    fi
    
    # 检查命令是否存在并缓存结果
    if command -v "$cmd" >/dev/null 2>&1; then
        COMMAND_CACHE[$cmd]="found"
        # 预加载命令路径
        COMMAND_PATHS[$cmd]="$(command -v "$cmd")"
        return 0
    else
        COMMAND_CACHE[$cmd]="not_found"
        log_error "命令 '$cmd' 未找到，请先安装。"
        exit 1
    fi
}

# 性能优化：缓存网络接口列表
declare -a CACHED_INTERFACES=()
declare -i CACHE_TIMESTAMP=0
CACHE_TIMEOUT=60  # 缓存超时时间（秒）

# 性能优化：优化网络接口获取
get_network_interfaces() {
    local current_time
    current_time=$(date +%s)
    
    # 检查缓存是否有效
    if (( ${#CACHED_INTERFACES[@]} > 0 )) && (( current_time - CACHE_TIMESTAMP < CACHE_TIMEOUT )); then
        # 使用缓存的数据
        printf '%s\n' "${CACHED_INTERFACES[@]}"
        return 0
    fi
    
    # 重新获取数据并更新缓存
    # 减少awk使用，使用纯Bash处理
    if command -v ip >/dev/null 2>&1; then
        # 使用mapfile和纯Bash处理替代awk
        local lines
        mapfile -t lines < <(run_command ip link show 2>/dev/null)
        
        # 清空缓存数组
        CACHED_INTERFACES=()
        
        # 使用Bash内建功能处理每一行
        for line in "${lines[@]}"; do
            # 使用正则表达式匹配网络接口行
            if [[ $line =~ ^[0-9]+:\ ([a-zA-Z][a-zA-Z0-9:@._-]*) ]]; then
                local interface="${BASH_REMATCH[1]}"
                # 排除回环接口和虚拟接口
                if [[ $interface != "lo" ]] && [[ $interface != *@* ]]; then
                    CACHED_INTERFACES+=("$interface")
                fi
            fi
        done
    else
        # 备用方案
        mapfile -t CACHED_INTERFACES < <(ls /sys/class/net/ 2>/dev/null | grep -v lo)
    fi
    
    CACHE_TIMESTAMP=$current_time
    
    # 返回结果
    printf '%s\n' "${CACHED_INTERFACES[@]}"
}

# 性能优化：系统信息缓存
declare -A SYSTEM_INFO_CACHE=()
declare -i SYSTEM_INFO_CACHE_TIME=0
SYSTEM_INFO_CACHE_TIMEOUT=300  # 5分钟缓存超时

# 获取系统信息（带缓存）
get_system_info() {
    local key="$1"
    local current_time
    current_time=$(date +%s)
    
    # 检查缓存是否有效
    if [[ -n "${SYSTEM_INFO_CACHE[$key]+isset}" ]] && (( current_time - SYSTEM_INFO_CACHE_TIME < SYSTEM_INFO_CACHE_TIMEOUT )); then
        echo "${SYSTEM_INFO_CACHE[$key]}"
        return 0
    fi
    
    # 更新缓存
    SYSTEM_INFO_CACHE_TIME=$current_time
    
    case $key in
        os_release)
            if [[ -f /etc/os-release ]]; then
                SYSTEM_INFO_CACHE["$key"]=$(cat /etc/os-release)
            else
                SYSTEM_INFO_CACHE["$key"]=""
            fi
            ;;
        hostname)
            SYSTEM_INFO_CACHE["$key"]=$(hostname)
            ;;
        username)
            SYSTEM_INFO_CACHE["$key"]=$(whoami)
            ;;
        *)
            return 1
            ;;
    esac
    
    echo "${SYSTEM_INFO_CACHE[$key]}"
}

)

# 性能优化：使用更高效的数组处理
# 显示预设DNS服务器选项
show_preset_dns() {
    log_header "DNS服务器选择"
    echo -e "\n${WHITE}预设DNS服务器选项:${NC}"
    
    local i=1
    # 使用更高效的遍历方式
    for name in "${!PRESET_DNS_SERVERS[@]}"; do
        printf "  ${YELLOW}%d.${NC} %s: ${GREEN}%s${NC}\n" "$i" "$name" "${PRESET_DNS_SERVERS[$name]}"
        ((i++))
    done
    echo -e "  ${YELLOW}0.${NC} ${CYAN}自定义DNS服务器${NC}"
}

# 性能优化：优化字符串验证
# 获取用户输入的DNS地址（使用现代Bash特性）
get_dns_servers() {
    show_preset_dns
    read -p "请选择DNS服务器 (0-${#PRESET_DNS_SERVERS[@]}) 或直接回车使用默认(谷歌DNS+腾讯DNS): " dns_choice
    
    local dns_servers
    
    if [[ -z "$dns_choice" ]]; then
        # 默认使用谷歌DNS和腾讯DNS
        dns_servers="${PRESET_DNS_SERVERS[谷歌DNS]} ${PRESET_DNS_SERVERS[腾讯DNS]}"
        log_info "使用默认DNS服务器: $dns_servers"
        echo "$dns_servers"
        return 0
    elif (( dns_choice == 0 )); then
        # 自定义DNS服务器
        read -p "请输入DNS地址(用空格分隔): " dns_servers
        if [[ -z "$dns_servers" ]]; then
            log_error "DNS服务器地址不能为空"
            return 1
        fi
    elif (( dns_choice >= 1 )) && (( dns_choice <= ${#PRESET_DNS_SERVERS[@]} )); then
        # 选择预设DNS服务器
        local keys=("${!PRESET_DNS_SERVERS[@]}")
        local selected_key="${keys[$((dns_choice-1))]}"
        dns_servers="${PRESET_DNS_SERVERS[$selected_key]}"
        log_info "选择预设DNS服务器 $selected_key: $dns_servers"
    else
        log_error "无效选择"
        return 1
    fi
    
    # 使用更高效的IP地址验证方法
    validate_ip_addresses "$dns_servers" || return 1
    
    echo "$dns_servers"
}

# 性能优化：专门的IP地址验证函数
validate_ip_addresses() {
    local servers="$1"
    
    # 一次性的正则表达式编译
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    for server in $servers; do
        # 基本格式验证
        if [[ ! "$server" =~ $ip_regex ]]; then
            log_error "无效的IP地址格式: $server"
            return 1
        fi
        
        # 数值范围验证（0-255）
        local valid_range=true
        IFS='.' read -ra octets <<< "$server"
        for octet in "${octets[@]}"; do
            if (( octet > 255 )); then
                valid_range=false
                break
            fi
        done
        
        if [[ "$valid_range" == false ]]; then
            log_error "无效的IP地址数值范围: $server"
            return 1
        fi
    done
    
    return 0
}

# 性能优化：更高效的网络接口状态检查
check_interface_status_quiet() {
    local interface=$1
    
    # 检查接口是否存在
    if ! ip link show "$interface" >/dev/null 2>&1; then
        echo "error:接口不存在"
        return 1
    fi
    
    status=$(ip -o link show "$interface" 2>/dev/null)
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "error:无法获取状态"
        return 1
    fi
    
    # 使用正则表达式匹配接口状态
    if [[ $status =~ state\ ([[:upper:]]+) ]]; then
        interface_state="${BASH_REMATCH[1]}"
        echo "$interface_state"
        return 0
    else
        echo "error:无法确定状态"
        return 1
    fi
}

# 性能优化：优化网络接口状态检查函数，使其只返回状态而不直接输出
check_interface_status() {
    local interface="$1"
    
    log_info "正在检查网络接口 $interface 状态..."
    
    # 使用预加载的命令路径
    local status
    status=$(run_command ip -o link show "$interface" 2>/dev/null) || {
        log_error "网络接口 $interface 不存在"
        return 1
    }
    
    # 使用shell内建功能进行字符串匹配
    if [[ $status =~ state\ ([[:upper:]]+) ]]; then
        local interface_state="${BASH_REMATCH[1]}"
        if [[ $interface_state == "UP" ]]; then
            log_success "$interface 状态: UP"
        else
            log_warn "$interface 状态: $interface_state"
        fi
    else
        log_error "无法确定 $interface 状态"
        return 1
    fi
}

# 性能优化：优化网络接口选择
select_interface() {
    log_header "网络接口选择"
    log_info "正在检测系统中的网络接口..."
    
    # 一次性获取所有接口
    mapfile -t interfaces < <(get_network_interfaces)
    
    if (( ${#interfaces[@]} == 0 )); then
        log_error "未检测到可用的网络接口"
        return 1
    fi
    
    echo -e "\n${WHITE}检测到以下网络接口:${NC}"
    for i in "${!interfaces[@]}"; do
        printf "  ${YELLOW}%d.${NC} ${GREEN}%s${NC}\n" "$((i+1))" "${interfaces[$i]}"
    done
    
    while true; do
        echo ""
        read -p "请选择接口编号 (1-${#interfaces[@]}) 或输入接口名称: " choice
        
        # 使用更高效的数字验证
        if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 )) && (( choice <= ${#interfaces[@]} )); then
            selected_interface="${interfaces[$((choice-1))]}"
            log_info "已选择接口: $selected_interface"
            break
        # 字符串匹配优化
        elif [[ " ${interfaces[*]} " =~ " $choice " ]]; then
            selected_interface="$choice"
            log_info "已选择接口: $selected_interface"
            break
        else
            log_error "无效选择，请重新输入"
        fi
    done
    
    echo "$selected_interface"
}

# 性能优化：DNS服务器有效性验证（并发）
validate_dns_server() {
    local server=$1
    log_debug "正在验证DNS服务器 $server 的有效性..."
    
    # 使用超时机制避免长时间等待
    if timeout 3 ping -c 1 -W 1 "$server" >/dev/null 2>&1; then
        log_debug "DNS服务器 $server 可达"
        echo "valid:$server"
        return 0
    else
        log_debug "DNS服务器 $server 不可达"
        echo "invalid:$server"
        return 1
    fi
}

# 性能优化：并发验证所有DNS服务器的有效性
validate_all_dns_servers() {
    local servers=$1
    local all_valid=true
    local results=()
    local pids=()
    
    log_info "正在并发验证DNS服务器有效性..."
    
    # 并发启动所有验证任务
    for server in $servers; do
        validate_dns_server "$server" &
        pids+=($!)
    done
    
    # 等待所有任务完成并收集结果
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 重新验证每个服务器（因为并行执行后需要收集实际结果）
    local valid_count=0
    local invalid_count=0
    
    for server in $servers; do
        if timeout 3 ping -c 1 -W 1 "$server" >/dev/null 2>&1; then
            ((valid_count++))
        else
            ((invalid_count++))
            all_valid=false
        fi
    done
    
    if $all_valid; then
        log_success "所有DNS服务器验证通过 ($valid_count/$valid_count)"
    else
        log_warn "部分DNS服务器验证失败 ($valid_count/$(($valid_count + $invalid_count)))"
        if [ "$SILENT_MODE" = false ]; then
            read -p "是否继续使用这些DNS服务器? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    fi
    
    return 0
}

# 临时DNS配置
temp_dns() {
    log_header "临时DNS配置"
    log_info "开始临时DNS配置..."
    
    # 获取DNS服务器地址
    local dns_servers
    dns_servers=$(get_dns_servers)
    if (( $? != 0 )); then
        return 1
    fi
    
    # 确认操作
    if ! confirm_action "临时DNS配置"; then
        return 0
    fi
    
    # 检查resolv.conf文件是否存在
    if [[ ! -f /etc/resolv.conf ]]; then
        log_error "/etc/resolv.conf 文件不存在"
        return 1
    fi
    
    # 使用预加载的命令路径进行备份
    local backup_file
    backup_file=$(backup_file "/etc/resolv.conf")
    if (( $? != 0 )); then
        return 1
    fi
    
    log_info "已备份 /etc/resolv.conf 到 $backup_file"
    
    # 使用原子操作一次性写入，而不是多次追加
    {
        for server in $dns_servers; do
            echo "nameserver $server"
        done
    } > /etc/resolv.conf
    
    log_success "临时DNS已设置为: $dns_servers"
}

# 性能优化：高效的文件备份函数
backup_file() {
    local source_file=$1
    local backup_suffix=${2:-".bak.$(date +%s)"}
    
    # 检查源文件是否存在
    if [ ! -f "$source_file" ]; then
        log_error "源文件不存在: $source_file"
        return 1
    fi
    
    local backup_file="${source_file}${backup_suffix}"
    
    # 使用更高效的复制方法
    if cp "$source_file" "$backup_file"; then
        log_debug "已备份 $source_file 到 $backup_file"
        echo "$backup_file"
        return 0
    else
        log_error "备份 $source_file 失败，请检查权限"
        return 1
    fi
}

# 永久DNS配置
dns() {
    log_header "永久DNS配置"
    log_info "开始永久DNS配置..."
    
    # 获取DNS服务器地址
    dns_servers=$(get_dns_servers)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 确认操作
    if ! confirm_action "永久DNS配置"; then
        return 0
    fi
    
    if [ -f /etc/os-release ]; then
        # 使用source而不是.来提高可读性
        source /etc/os-release
        case $ID in
            debian|ubuntu)
                if [ -d /etc/netplan ]; then
                    # 使用 netplan 的系统
                    config_file=$(find /etc/netplan -name "*.yaml" | head -n 1)
                    if [ -z "$config_file" ]; then
                        log_error "未找到 netplan 配置文件"
                        return 1
                    fi
                    
                    backup_file="$config_file.bak.$(date +%s)"
                    cp "$config_file" "$backup_file"
                    if [ $? -ne 0 ]; then
                        log_error "备份 $config_file 失败，请检查权限"
                        return 1
                    fi
                    
                    log_info "已备份 $config_file 到 $backup_file"
                    
                    # 清除现有DNS设置
                    sed -i '/nameservers:/,+1 d' "$config_file"
                    if [ $? -ne 0 ]; then
                        log_error "清除 $config_file 中的DNS设置失败，请检查权限"
                        return 1
                    fi
                    
                    # 添加新DNS设置
                    dns_list=$(echo "$dns_servers" | sed 's/ /, /g')
                    cat << EOF >> "$config_file"
      nameservers:
        addresses: [$dns_list]
EOF
                    netplan apply
                    log_success "永久DNS已设置为: $dns_servers (配置文件已备份到 $backup_file)"
                else
                    # 传统的 Debian/Ubuntu 配置
                    config_file="/etc/network/interfaces"
                    backup_file="/etc/network/interfaces.bak.$(date +%s)"
                    if [ ! -f "$config_file" ]; then
                        log_error "/etc/network/interfaces 文件不存在，可能使用 netplan 管理网络，请检查。"
                        return 1
                    fi
                    
                    cp "$config_file" "$backup_file"
                    if [ $? -ne 0 ]; then
                        log_error "备份 $config_file 失败，请检查权限"
                        return 1
                    fi
                    
                    log_info "已备份 $config_file 到 $backup_file"
                    
                    # 清除现有DNS设置
                    sed -i '/^dns-nameservers/d' "$config_file"
                    if [ $? -ne 0 ]; then
                        log_error "清除 $config_file 中的DNS设置失败，请检查权限"
                        return 1
                    fi
                    
                    # 添加新DNS设置
                    echo -e "\ndns-nameservers $dns_servers" >> "$config_file"
                    systemctl restart networking
                    log_success "永久DNS已设置为: $dns_servers (配置文件已备份到 $backup_file)"
                fi
                ;;
            rhel|centos|rocky|almalinux)
                # RHEL/CentOS
                config_file="/etc/sysconfig/network-scripts/ifcfg-ens33"
                backup_file="/etc/sysconfig/network-scripts/ifcfg-ens33.bak.$(date +%s)"
                
                if [ ! -f "$config_file" ]; then
                    log_error "$config_file 文件不存在"
                    return 1
                fi
                
                cp "$config_file" "$backup_file"
                if [ $? -ne 0 ]; then
                    log_error "备份 $config_file 失败，请检查权限"
                    return 1
                fi
                
                log_info "已备份 $config_file 到 $backup_file"
                
                # 清除现有DNS设置
                sed -i '/^DNS/d' "$config_file"
                if [ $? -ne 0 ]; then
                    log_error "清除 $config_file 中的DNS设置失败，请检查权限"
                    return 1
                fi
                
                # 添加新DNS设置
                counter=1
                for server in $dns_servers; do
                    echo "DNS$counter=$server" >> "$config_file"
                    ((counter++))
                done
                
                systemctl restart network
                log_success "永久DNS已设置为: $dns_servers (配置文件已备份到 $backup_file)"
                ;;
            *)
                log_error "不支持的系统类型: $ID"
                return 1
                ;;
        esac
    else
        log_error "无法判断系统类型"
        return 1
    fi
}

# GPG密钥配置
gpg_key() {
    echo -e "\n[+] GPG密钥配置选项:"
    echo "1. 自动生成密钥"
    echo "2. 手动生成密钥"
    echo "3. 查看密钥列表"
    echo "4. 导出密钥"
    echo "5. 导入密钥"
    echo "6. 删除密钥"
    while true; do
        read -p "请选择(1-6): " gpg_choice
        if [[ "$gpg_choice" =~ ^[1-6]$ ]]; then
            break
        else
            log_error "无效选项，请输入 1-6"
        fi
    done
    
    case $gpg_choice in
        1)
            auto_generate_gpg_key
            ;;
        2)
            manual_generate_gpg_key
            ;;
        3)
            list_gpg_keys
            ;;
        4)
            export_gpg_key
            ;;
        5)
            import_gpg_key
            ;;
        6)
            delete_gpg_key
            ;;
        *)
            log_error "无效选项"
            return 1
            ;;
    esac
}

# 自动生成GPG密钥
auto_generate_gpg_key() {
    log_header "自动生成GPG密钥"
    log_info "正在自动生成GPG密钥..."
    
    # 检查GPG命令是否存在
    check_command "gpg"
    
    # 备份现有配置
    if [ -d ~/.gnupg ]; then
        backup_dir=~/.gnupg.bak.$(date +%s)
        cp -r ~/.gnupg "$backup_dir"
        if [ $? -ne 0 ]; then
            log_error "备份现有GPG配置失败，请检查权限"
            return 1
        fi
        log_info "已备份现有GPG配置到 $backup_dir"
    fi
    
    # 重启 gpg-agent
    gpgconf --kill gpg-agent >/dev/null 2>&1
    gpg-agent --daemon >/dev/null 2>&1
    
    # 显式设置 GPG_TTY 环境变量
    export GPG_TTY=$(tty)
    
    # 优化GPG批处理生成，减少不必要的选项
    local username
    local hostname
    username=$(get_system_info "username")
    hostname=$(get_system_info "hostname")
    
    gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: $username Auto Generated
Name-Email: $username@$hostname
Expire-Date: 0
%no-protection
%commit
EOF
    
    if [ $? -ne 0 ]; then
        log_error "生成GPG密钥失败，请检查GPG配置"
        return 1
    fi
    
    log_success "GPG密钥自动配置完成"
    gpg --list-keys
}

# 手动生成GPG密钥
manual_generate_gpg_key() {
    log_header "手动生成GPG密钥"
    log_info "手动生成GPG密钥..."
    check_command "gpg"
    gpg --full-generate-key
}

# 优化GPG密钥列表显示
list_gpg_keys() {
    log_header "GPG密钥列表"
    log_info "正在获取GPG密钥列表..."
    check_command "gpg"
    
    # 使用更高效的输出方式
    gpg --list-keys --with-colons 2>/dev/null | \
    awk -F: '
        /^pub:/ { 
            key_id = $5
            created = $6
            algo = $4
            printf "公钥: %s (%s)\n", key_id, algo
        }
        /^uid:/ { 
            user_id = $10
            printf "  用户: %s\n", user_id
        }
        /^sub:/ { 
            sub_key = $5
            printf "  子钥: %s\n", sub_key
        }
    ' || {
        log_error "获取密钥列表失败"
        return 1
    }
}

# 导出GPG密钥
export_gpg_key() {
    log_header "导出GPG密钥"
    log_info "导出GPG密钥..."
    check_command "gpg"
    
    # 显示可用的密钥
    list_gpg_keys
    
    read -p "请输入要导出的密钥ID或邮箱: " key_id
    if [ -z "$key_id" ]; then
        log_error "密钥ID不能为空"
        return 1
    fi
    
    read -p "请输入导出文件路径 (默认: ~/public_key.asc): " export_path
    export_path=${export_path:-~/public_key.asc}
    
    if gpg --export --armor "$key_id" > "$export_path"; then
        log_success "公钥已导出到: $export_path"
    else
        log_error "导出公钥失败"
        return 1
    fi
    
    read -p "是否同时导出私钥? (y/N): " export_private
    if [[ "$export_private" =~ ^[Yy]$ ]]; then
        read -p "请输入私钥导出文件路径 (默认: ~/private_key.asc): " private_export_path
        private_export_path=${private_export_path:-~/private_key.asc}
        
        if gpg --export-secret-keys --armor "$key_id" > "$private_export_path"; then
            log_success "私钥已导出到: $private_export_path"
            log_warn "请妥善保管私钥文件，不要泄露给他人"
        else
            log_error "导出私钥失败"
            return 1
        fi
    fi
}

# 导入GPG密钥
import_gpg_key() {
    log_header "导入GPG密钥"
    log_info "导入GPG密钥..."
    check_command "gpg"
    
    read -p "请输入要导入的密钥文件路径: " import_path
    if [ -z "$import_path" ]; then
        log_error "文件路径不能为空"
        return 1
    fi
    
    if [ ! -f "$import_path" ]; then
        log_error "文件不存在: $import_path"
        return 1
    fi
    
    if gpg --import "$import_path"; then
        log_success "密钥导入成功"
    else
        log_error "密钥导入失败"
        return 1
    fi
}

# 删除GPG密钥
delete_gpg_key() {
    log_header "删除GPG密钥"
    log_info "删除GPG密钥..."
    check_command "gpg"
    
    # 显示可用的密钥
    list_gpg_keys
    
    read -p "请输入要删除的密钥ID或邮箱: " key_id
    if [ -z "$key_id" ]; then
        log_error "密钥ID不能为空"
        return 1
    fi
    
    log_warn "删除操作不可恢复，请确认是否继续"
    read -p "是否确认删除密钥 $key_id? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消删除操作"
        return 0
    fi
    
    # 删除公钥
    if gpg --delete-keys "$key_id"; then
        log_success "公钥删除成功"
    else
        log_error "公钥删除失败"
        return 1
    fi
    
    # 询问是否删除私钥
    read -p "是否同时删除对应的私钥? (y/N): " delete_private
    if [[ "$delete_private" =~ ^[Yy]$ ]]; then
        if gpg --delete-secret-keys "$key_id"; then
            log_success "私钥删除成功"
        else
            log_error "私钥删除失败"
            return 1
        fi
    fi
}

# 网络诊断工具
network_diagnostics() {
    echo -e "\n[+] 网络诊断工具选项:"
    echo "1. 连通性检查 (Ping)"
    echo "2. 路由跟踪 (Traceroute)"
    echo "3. 端口连通性测试"
    while true; do
        read -p "请选择(1-3): " diag_choice
        if [[ "$diag_choice" =~ ^[1-3]$ ]]; then
            break
        else
            log_error "无效选项，请输入 1-3"
        fi
    done
    
    case $diag_choice in
        1)
            check_ping
            ;;
        2)
            traceroute_test
            ;;
        3)
            port_connectivity_test
            ;;
        *)
            log_error "无效选项"
            return 1
            ;;
    esac
}

# 网络连通性检查（使用现代Bash特性）
check_ping() {
    log_header "网络连通性检查"
    local target
    read -p "输入测试地址(默认www.baidu.com): " target
    target=${target:-www.baidu.com}
    
    log_info "正在检查 $target 的连通性..."
    
    # 检查host命令是否存在
    check_command "host"
    
    # 检查DNS解析
    if ! host "$target" &>/dev/null; then
        log_error "网络不可达: DNS无法解析"
        return 1
    fi
    
    # 检查ping命令是否存在
    check_command "ping"
    
    # 执行ping测试
    local ping_result
    ping_result=$(ping -c 4 -W 2 "$target" 2>&1)
    if echo "$ping_result" | grep -q "100% packet loss"; then
        log_error "网络不可达: 100%丢包"
        return 1
    fi
    
    # 提取平均延迟
    local avg_ttl
    avg_ttl=$(echo "$ping_result" | grep -oP 'rtt min/avg/max/mdev = .*?/\K[0-9.]+')
    if [[ -z "$avg_ttl" ]]; then
        log_error "网络不可达: 无法获取延迟"
        return 1
    fi
    
    # 判断网络状态
    if (( $(echo "$avg_ttl > 128" | bc -l) )); then
        log_warn "网络不稳定: 平均延迟 ${avg_ttl}ms"
    else
        log_success "网络畅通: 平均延迟 ${avg_ttl}ms"
    fi
}

# Traceroute路由跟踪
traceroute_test() {
    log_header "路由跟踪测试"
    log_info "路由跟踪测试..."
    
    # 检查traceroute命令是否存在
    if ! command -v traceroute >/dev/null 2>&1 && ! command -v tracepath >/dev/null 2>&1; then
        log_error "系统中未找到 traceroute 或 tracepath 命令，请先安装 traceroute 包"
        return 1
    fi
    
    read -p "请输入目标地址(默认www.baidu.com): " target
    target=${target:-www.baidu.com}
    
    read -p "请输入最大跳数(默认30): " max_hops
    max_hops=${max_hops:-30}
    
    log_info "正在执行路由跟踪到 $target (最大跳数: $max_hops)..."
    
    # 根据系统选择合适的命令
    if command -v traceroute >/dev/null 2>&1; then
        traceroute -m "$max_hops" "$target"
    elif command -v tracepath >/dev/null 2>&1; then
        tracepath -m "$max_hops" "$target"
    else
        log_error "无法执行路由跟踪"
        return 1
    fi
}

# 性能优化：优化端口连通性测试
port_connectivity_test() {
    log_header "端口连通性测试"
    log_info "端口连通性测试..."
    
    local host
    read -p "请输入目标主机地址: " host
    if [[ -z "$host" ]]; then
        log_error "主机地址不能为空"
        return 1
    fi
    
    local port
    read -p "请输入端口号: " port
    if [[ -z "$port" ]] || ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 )) || (( port > 65535 )); then
        log_error "无效的端口号 (1-65535)"
        return 1
    fi
    
    log_info "正在测试 $host:$port 的连通性..."
    
    # 优先使用bash内置功能进行快速测试
    if timeout 3 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
        exec 3<&-
        exec 3>&-
        log_success "端口 $host:$port 可达"
    else
        # 如果bash内置方法失败，再尝试其他方法
        if command -v nc >/dev/null 2>&1; then
            if nc -z -w 3 "$host" "$port"; then
                log_success "端口 $host:$port 可达"
            else
                log_error "端口 $host:$port 不可达"
                return 1
            fi
        elif command -v telnet >/dev/null 2>&1; then
            log_warn "使用telnet进行测试，可能需要手动中断..."
            telnet "$host" "$port"
        else
            log_error "没有可用的工具进行端口测试"
            return 1
        fi
    fi
}

# 性能优化：优化网络信息收集
show_network_info() {
    log_header "网络信息"
    log_info "正在收集网络信息..."
    
    echo -e "\n=== 网络接口信息 ==="
    # 使用ip命令和Bash内建处理替代复杂管道
    local interfaces
    mapfile -t interfaces < <(get_network_interfaces)
    
    for interface in "${interfaces[@]}"; do
        echo "--- 接口: $interface ---"
        ip addr show "$interface" 2>/dev/null || echo "无法获取接口信息"
        echo ""
    done
    
    echo -e "\n=== 路由表信息 ==="
    # 分行显示路由信息，提高可读性
    ip route show 2>/dev/null | head -20 || echo "无法获取路由信息"
    
    echo -e "\n=== DNS配置 ==="
    if [[ -f /etc/resolv.conf ]]; then
        # 使用Bash内建读取文件
        while IFS= read -r line; do
            if [[ -n "$line" ]] && ! [[ "$line" =~ ^[[:space:]]*# ]]; then
                echo "$line"
            fi
        done < /etc/resolv.conf
    else
        echo "/etc/resolv.conf 文件不存在"
    fi
    
    echo -e "\n=== 网络连接状态 ==="
    # 优先使用ss，备选netstat
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | head -20 || echo "无法获取连接状态"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln 2>/dev/null | head -20 || echo "无法获取连接状态"
    else
        echo "无法获取连接状态"
    fi
    
    # 添加Docker信息
    echo -e "\n=== Docker信息 ==="
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active --quiet docker; then
            echo "Docker版本: $(docker --version 2>/dev/null || echo '无法获取')"
            echo "Docker信息:"
            docker info 2>/dev/null | grep -E "Registry Mirrors:|Username:|Server Version:" | head -5 || echo "无法获取详细信息"
        else
            echo "Docker服务未运行"
        fi
    else
        echo "Docker未安装"
    fi
    
    # 自动检测Docker镜像源（不提示用户）
    if [[ "$SILENT_MODE" == false ]] && [[ "$OUTPUT_FORMAT" != "json" ]]; then
        echo -e "\n=== Docker镜像源检测 ==="
        check_docker_registry true  # 自动检查模式
    fi
}

# 显示进度指示器
show_progress() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    local i=0
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 全面检测功能（使用现代Bash特性）
comprehensive_check() {
    log_header "全面系统检测"
    log_info "正在进行全面系统检测..."
    
    # 使用关联数组存储检测结果
    declare -a normal_results=()
    declare -a abnormal_results=()
    
    # 1. 检查网络接口
    log_info "正在检测网络接口..."
    local interfaces
    mapfile -t interfaces < <(get_network_interfaces)
    
    if (( ${#interfaces[@]} > 0 )); then
        normal_results+=("网络接口检测: 正常 (发现 ${#interfaces[@]} 个接口)")
        for interface in "${interfaces[@]}"; do
            local status
            status=$(check_interface_status_quiet "$interface")
            if [[ $status != error:* ]]; then
                if [[ $status == "UP" ]]; then
                    normal_results+=("  - 接口 $interface: UP")
                else
                    abnormal_results+=("  - 接口 $interface: $status")
                fi
            else
                abnormal_results+=("  - 接口 $interface: ${status#error:}")
            fi
        done
    else
        abnormal_results+=("网络接口检测: 未检测到可用网络接口")
    fi
    
    # 2. 检查DNS配置
    log_info "正在检测DNS配置..."
    if [[ -f /etc/resolv.conf ]]; then
        local dns_count
        dns_count=$(grep -c "^nameserver" /etc/resolv.conf)
        if (( dns_count > 0 )); then
            normal_results+=("DNS配置检测: 正常 (配置了 $dns_count 个DNS服务器)")
            local dns_servers
            dns_servers=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
            while IFS= read -r server; do
                # 验证DNS服务器是否可达
                if timeout 3 ping -c 1 -W 1 "$server" >/dev/null 2>&1; then
                    normal_results+=("  - DNS服务器 $server: 可达")
                else
                    abnormal_results+=("  - DNS服务器 $server: 不可达")
                fi
            done <<< "$dns_servers"
        else
            abnormal_results+=("DNS配置检测: /etc/resolv.conf 中未配置DNS服务器")
        fi
    else
        abnormal_results+=("DNS配置检测: /etc/resolv.conf 文件不存在")
    fi
    
    # 3. 检查网络连通性
    log_info "正在检测网络连通性..."
    # 测试多个公共DNS服务器
    local test_servers=("8.8.8.8" "114.114.114.114" "223.5.5.5")
    local reachable_count=0
    
    for server in "${test_servers[@]}"; do
        if timeout 3 ping -c 1 -W 1 "$server" >/dev/null 2>&1; then
            ((reachable_count++))
            normal_results+=("  - 网络连通性测试 $server: 可达")
        else
            abnormal_results+=("  - 网络连通性测试 $server: 不可达")
        fi
    done
    
    if (( reachable_count > 0 )); then
        normal_results=("网络连通性检测: 正常 ($reachable_count/${#test_servers[@]} 个测试服务器可达)" "${normal_results[@]}")
    else
        abnormal_results=("网络连通性检测: 异常 (所有测试服务器均不可达)" "${abnormal_results[@]}")
    fi
    
    # 4. 检查HTTP连通性
    log_info "正在检测HTTP连通性..."
    if command -v curl >/dev/null 2>&1; then
        if timeout 5 curl -s -o /dev/null -w "%{http_code}" "https://www.baidu.com" | grep -q "200"; then
            normal_results+=("HTTP连通性检测: 正常 (可访问 https://www.baidu.com)")
        else
            abnormal_results+=("HTTP连通性检测: 异常 (无法访问 https://www.baidu.com)")
        fi
    elif command -v wget >/dev/null 2>&1; then
        if timeout 5 wget --spider -q "https://www.baidu.com" 2>/dev/null; then
            normal_results+=("HTTP连通性检测: 正常 (可访问 https://www.baidu.com)")
        else
            abnormal_results+=("HTTP连通性检测: 异常 (无法访问 https://www.baidu.com)")
        fi
    else
        abnormal_results+=("HTTP连通性检测: 无法测试 (缺少 curl 或 wget)")
    fi
    
    # 5. 检查Docker状态
    log_info "正在检测Docker状态..."
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active --quiet docker; then
            normal_results+=("Docker服务检测: 正常 (运行中)")
            
            # 检查Docker镜像源
            local daemon_config="/etc/docker/daemon.json"
            if [[ -f "$daemon_config" ]]; then
                if grep -q "registry-mirrors" "$daemon_config"; then
                    local mirror_count
                    mirror_count=$(grep -c "http" "$daemon_config")
                    if grep -q "registry.docker-cn.com\|mirror.aliyuncs.com\|hub-mirror.c.163.com\|mirrors.ustc.edu.cn\|mirror.baidubce.com" "$daemon_config"; then
                        normal_results+=("Docker镜像源检测: 正常 (已配置 $mirror_count 个镜像源，包含国内镜像源)")
                    else
                        abnormal_results+=("Docker镜像源检测: 已配置 $mirror_count 个镜像源但可能不是国内源")
                    fi
                else
                    abnormal_results+=("Docker镜像源检测: 未配置镜像源")
                fi
            else
                abnormal_results+=("Docker镜像源检测: 未配置镜像源 (/etc/docker/daemon.json 不存在)")
            fi
        else
            abnormal_results+=("Docker服务检测: 异常 (未运行)")
        fi
    else
        abnormal_results+=("Docker服务检测: 未安装")
    fi
    
    # 6. 检查常用网络工具
    log_info "正在检测网络工具..."
    local tools=("ip" "ping" "nslookup" "dig")
    local missing_tools=()
    local available_tools=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            available_tools+=("$tool")
        else
            missing_tools+=("$tool")
        fi
    done
    
    if (( ${#available_tools[@]} > 0 )); then
        normal_results+=("网络工具检测: 可用工具 (${available_tools[*]})")
    fi
    
    if (( ${#missing_tools[@]} > 0 )); then
        abnormal_results+=("网络工具检测: 缺少以下工具: ${missing_tools[*]}")
    fi
    
    # 7. 检查防火墙状态
    log_info "正在检测防火墙状态..."
    if systemctl is-active --quiet firewalld; then
        normal_results+=("防火墙检测: Firewalld 运行中")
    elif systemctl is-active --quiet ufw; then
        normal_results+=("防火墙检测: UFW 运行中")
    elif command -v iptables >/dev/null 2>&1 && iptables -L >/dev/null 2>&1; then
        normal_results+=("防火墙检测: iptables 可用")
    else
        abnormal_results+=("防火墙检测: 未检测到活动的防火墙")
    fi
    
    # 输出检测结果
    log_header "检测结果摘要"
    
    # 先输出正常功能
    if (( ${#normal_results[@]} > 0 )); then
        echo -e "${GREEN}>>> 功能正常的项目:${NC}"
        for result in "${normal_results[@]}"; do
            echo -e "${GREEN}✓${NC} $result"
        done
        echo ""
    fi
    
    # 再输出异常功能
    if (( ${#abnormal_results[@]} > 0 )); then
        echo -e "${RED}>>> 功能异常的项目:${NC}"
        for result in "${abnormal_results[@]}"; do
            echo -e "${RED}✗${NC} $result"
        done
        echo ""
    fi
    
    # 输出总体状态
    if (( ${#abnormal_results[@]} == 0 )); then
        log_success "所有检测项目均正常"
    else
        log_warn "检测到 ${#abnormal_results[@]} 个异常项目"
        log_info "建议根据异常项目进行相应处理"
    fi
}

# 检测类功能菜单
detection_menu() {
    while true; do
        show_detection_menu
        read -rp "[+] 请输入选项数字：" choice

        case $choice in
            1)
                if selected_interface=$(select_interface) && [ -n "$selected_interface" ]; then
                    check_interface_status "$selected_interface"
                fi
                ;;
            2)
                comprehensive_check
                ;;
            3)
                show_network_info
                ;;
            4)
                check_docker_registry
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选项，请重试"
                sleep 1
                ;;
        esac
        
        if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
            echo -e "\n按回车键继续..."
            read -r
        fi
    done
}

# 修复类功能菜单
repair_menu() {
    while true; do
        show_repair_menu
        read -rp "[+] 请输入选项数字：" choice

        case $choice in
            1)
                repair_dns_configuration
                ;;
            2)
                repair_docker_mirror
                ;;
            3)
                install_missing_network_tools
                ;;
            4)
                repair_network_interface
                ;;
            0)
                break
                ;;
            *)
                log_error "无效选项，请重试"
                sleep 1
                ;;
        esac
        
        if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
            echo -e "\n按回车键继续..."
            read -r
        fi
    done
}

# 显示检测类功能菜单
show_detection_menu() {
    show_header
    log_header "检测类功能菜单"
    echo -e "${WHITE}请选择要执行的检测操作:${NC}"
    echo -e "  ${YELLOW}1.${NC} ${CYAN}检查网络接口状态${NC}"
    echo -e "  ${YELLOW}2.${NC} ${CYAN}全面系统检测${NC}"
    echo -e "  ${YELLOW}3.${NC} ${CYAN}显示网络信息${NC}"
    echo -e "  ${YELLOW}4.${NC} ${CYAN}检查Docker镜像源${NC}"
    echo -e "  ${YELLOW}0.${NC} ${RED}返回主菜单${NC}"
    echo ""
}

# 显示修复类功能菜单
show_repair_menu() {
    show_header
    log_header "修复类功能菜单"
    echo -e "${WHITE}请选择要执行的修复操作:${NC}"
    echo -e "  ${YELLOW}1.${NC} ${CYAN}修复DNS配置${NC}"
    echo -e "  ${YELLOW}2.${NC} ${CYAN}配置Docker国内镜像源${NC}"
    echo -e "  ${YELLOW}3.${NC} ${CYAN}安装缺失的网络工具${NC}"
    echo -e "  ${YELLOW}4.${NC} ${CYAN}修复网络接口问题${NC}"
    echo -e "  ${YELLOW}0.${NC} ${RED}返回主菜单${NC}"
    echo ""
}

# 主菜单
show_menu() {
    show_header
    log_header "主菜单"
    echo -e "${WHITE}请选择要执行的操作:${NC}"
    echo -e "  ${YELLOW}1.${NC} ${CYAN}检测类功能${NC}"
    echo -e "  ${YELLOW}2.${NC} ${CYAN}修复类功能${NC}"
    echo -e "  ${YELLOW}3.${NC} ${CYAN}暂时更新DNS解析地址${NC}"
    echo -e "  ${YELLOW}4.${NC} ${CYAN}永久更新DNS解析地址${NC}"
    echo -e "  ${YELLOW}5.${NC} ${CYAN}配置GPG密钥${NC}"
    echo -e "  ${YELLOW}6.${NC} ${CYAN}网络诊断工具${NC}"
    echo -e "  ${YELLOW}0.${NC} ${RED}退出脚本${NC}"
    echo ""
}

# 性能优化：优化主程序入口
main() {
    # 初始化脚本环境
    initialize
    
    # 预加载常用命令以提高性能
    preload_commands
    
    # 解析命令行参数
    parse_arguments "$@"
    
    # 检查root权限
    check_root
    
    # 检查必要命令
    check_command "ip"
    check_command "sed"
    check_command "cp"
    check_command "date"
    
    if [[ "$SILENT_MODE" == false ]] && [[ "$OUTPUT_FORMAT" != "json" ]]; then
        log_success "网络工具已启动"
    fi
    
    # 如果没有命令行参数，则进入交互模式
    if (( $# == 0 )); then
        interactive_mode
    fi
}

# 优化主循环
interactive_mode() {
    while true; do
        show_menu
        read -rp "[+] 请输入选项数字：" choice

        case $choice in
            1)
                detection_menu
                ;;
            2)
                repair_menu
                ;;
            3)
                temp_dns
                ;;
            4)
                dns
                ;;
            5)
                gpg_key
                ;;
            6)
                network_diagnostics
                ;;
            0)
                log_info "您已退出脚本!"
                exit 0
                ;;
            *)
                log_error "无效选项，请重试"
                sleep 1
                ;;
        esac
        
        if [ "$SILENT_MODE" = false ] && [ "$OUTPUT_FORMAT" != "json" ]; then
            echo -e "\n按回车键继续..."
            read -r
        fi
    done
}

# 用户确认函数（使用现代Bash特性）
confirm_action() {
    local action_desc="$1"
    if [[ "$SILENT_MODE" == false ]]; then
        read -p "确认执行 $action_desc 操作? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "已取消操作"
            return 1
        fi
    fi
    return 0
}

# Docker镜像源检测和配置（使用现代Bash特性）
check_docker_registry() {
    local auto_check=${1:-false}  # 是否自动检查（不提示用户）
    
    log_header "Docker镜像源检测"
    log_info "正在检测Docker镜像源配置..."
    
    # 检查Docker是否安装
    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker未安装，跳过镜像源检测"
        return 0
    fi
    
    # 检查Docker服务是否运行
    if ! systemctl is-active --quiet docker; then
        log_warn "Docker服务未运行，跳过镜像源检测"
        return 0
    fi
    
    # 检查Docker镜像源配置文件
    local daemon_config="/etc/docker/daemon.json"
    local has_mirror=false
    local has_china_mirror=false
    
    if [[ -f "$daemon_config" ]]; then
        # 检查是否配置了镜像源
        if grep -q "registry-mirrors" "$daemon_config"; then
            has_mirror=true
            # 检查是否配置了国内镜像源
            if grep -q "registry.docker-cn.com\|mirror.aliyuncs.com\|hub-mirror.c.163.com\|mirrors.ustc.edu.cn\|mirror.baidubce.com" "$daemon_config"; then
                has_china_mirror=true
            fi
        fi
    fi
    
    if [[ "$has_china_mirror" == true ]]; then
        log_success "Docker已配置国内镜像源"
        if [[ "$SILENT_MODE" == false ]] && [[ "$OUTPUT_FORMAT" != "json" ]]; then
            echo "配置详情:"
            if command -v jq >/dev/null 2>&1; then
                jq '.' "$daemon_config" 2>/dev/null || cat "$daemon_config"
            else
                cat "$daemon_config"
            fi
        fi
        return 0
    elif [[ "$has_mirror" == true ]]; then
        log_warn "Docker已配置镜像源，但可能不是国内镜像源"
        if [[ "$SILENT_MODE" == false ]] && [[ "$OUTPUT_FORMAT" != "json" ]]; then
            echo "当前配置:"
            if command -v jq >/dev/null 2>&1; then
                jq '.' "$daemon_config" 2>/dev/null || cat "$daemon_config"
            else
                cat "$daemon_config"
            fi
        fi
    else
        log_warn "Docker未配置镜像源"
    fi
    
    # 如果是自动检查模式，不提示用户
    if [[ "$auto_check" == true ]]; then
        log_info "如需配置国内镜像源，请选择菜单项7或使用 --check-docker-mirror 参数"
        return 0
    fi
    
    # 询问用户是否配置国内镜像源
    if [[ "$SILENT_MODE" == false ]]; then
        read -p "是否配置国内镜像源以提高拉取速度? (y/N): " configure_mirror
        if [[ "$configure_mirror" =~ ^[Yy]$ ]]; then
            configure_docker_china_mirror
        else
            log_info "已跳过Docker镜像源配置"
        fi
    else
        log_info "在静默模式下跳过Docker镜像源配置"
    fi
}

# 配置Docker国内镜像源
configure_docker_china_mirror() {
    log_info "正在配置Docker国内镜像源..."
    
    local daemon_config="/etc/docker/daemon.json"
    local backup_file
    
    # 备份原配置文件
    if [ -f "$daemon_config" ]; then
        backup_file=$(backup_file "$daemon_config" ".bak.$(date +%s)")
        if [ $? -ne 0 ]; then
            log_error "备份原配置文件失败"
            return 1
        fi
        log_info "原配置文件已备份到: $backup_file"
    fi
    
    # 创建新的配置内容
    cat > "$daemon_config" << EOF
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Docker国内镜像源配置完成"
        
        # 重启Docker服务
        log_info "正在重启Docker服务..."
        if systemctl restart docker; then
            log_success "Docker服务重启成功"
        else
            log_error "Docker服务重启失败，请手动重启"
            return 1
        fi
    else
        log_error "Docker镜像源配置失败"
        return 1
    fi
}

# 检测ens33状态（向后兼容）
check_ens33() {
    check_interface_status "ens33"
}

# DNS配置修复功能
repair_dns_configuration() {
    log_header "DNS配置修复"
    log_info "正在修复DNS配置..."
    
    # 检查/etc/resolv.conf是否存在
    if [ ! -f /etc/resolv.conf ]; then
        log_warn "/etc/resolv.conf 文件不存在，正在创建..."
        touch /etc/resolv.conf
        if [ $? -eq 0 ]; then
            log_success "已创建 /etc/resolv.conf 文件"
        else
            log_error "创建 /etc/resolv.conf 文件失败"
            return 1
        fi
    fi
    
    # 备份当前配置
    local backup_file
    backup_file=$(backup_file "/etc/resolv.conf")
    if [ $? -ne 0 ]; then
        log_error "备份原配置文件失败"
        return 1
    fi
    log_info "原配置文件已备份到: $backup_file"
    
    # 提供DNS服务器选择
    log_info "请选择要配置的DNS服务器:"
    show_preset_dns
    
    read -p "请选择DNS服务器 (1-${#PRESET_DNS_SERVERS[@]}) 或输入自定义DNS: " dns_choice
    
    local dns_servers
    
    if [[ "$dns_choice" =~ ^[0-9]+$ ]] && [ "$dns_choice" -ge 1 ] && [ "$dns_choice" -le ${#PRESET_DNS_SERVERS[@]} ]; then
        # 选择预设DNS服务器
        local keys=("${!PRESET_DNS_SERVERS[@]}")
        local selected_key="${keys[$((dns_choice-1))]}"
        dns_servers="${PRESET_DNS_SERVERS[$selected_key]}"
        log_info "选择预设DNS服务器 $selected_key: $dns_servers"
    else
        # 自定义DNS服务器
        dns_servers="$dns_choice"
        # 验证IP地址格式
        validate_ip_addresses "$dns_servers" || return 1
    fi
    
    # 写入新的DNS配置
    {
        for server in $dns_servers; do
            echo "nameserver $server"
        done
    } > /etc/resolv.conf
    
    if [ $? -eq 0 ]; then
        log_success "DNS配置已更新为: $dns_servers"
        
        # 验证配置
        log_info "正在验证DNS配置..."
        if nslookup www.baidu.com >/dev/null 2>&1; then
            log_success "DNS配置验证成功"
        else
            log_warn "DNS配置可能存在问题，请手动检查网络连接"
        fi
    else
        log_error "DNS配置更新失败"
        return 1
    fi
}

# Docker镜像源修复功能
repair_docker_mirror() {
    log_header "Docker镜像源修复"
    log_info "正在配置Docker国内镜像源..."
    
    # 检查Docker是否安装
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker未安装，无法配置镜像源"
        read -p "是否尝试安装Docker? (y/N): " install_docker
        if [[ "$install_docker" =~ ^[Yy]$ ]]; then
            install_docker_engine
        fi
        return 0
    fi
    
    # 配置国内镜像源
    configure_docker_china_mirror
}

# 安装Docker引擎
install_docker_engine() {
    log_info "正在尝试安装Docker引擎..."
    
    # 检测系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                # Ubuntu/Debian安装
                log_info "检测到 $ID 系统，正在安装Docker..."
                apt-get update
                apt-get install -y docker.io
                ;;
            centos|rhel|rocky|almalinux)
                # RHEL/CentOS安装
                log_info "检测到 $ID 系统，正在安装Docker..."
                yum install -y docker
                ;;
            *)
                log_error "不支持的系统类型: $ID"
                return 1
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            log_success "Docker安装成功"
            systemctl enable docker
            systemctl start docker
            log_info "Docker服务已启动并设置为开机自启"
        else
            log_error "Docker安装失败"
            return 1
        fi
    else
        log_error "无法识别系统类型"
        return 1
    fi
}

# 配置Docker国内镜像源
configure_docker_china_mirror() {
    log_info "正在配置Docker国内镜像源..."
    
    local daemon_config="/etc/docker/daemon.json"
    local backup_file
    
    # 创建Docker配置目录（如果不存在）
    mkdir -p /etc/docker
    
    # 备份原配置文件
    if [ -f "$daemon_config" ]; then
        backup_file=$(backup_file "$daemon_config" ".bak.$(date +%s)")
        if [ $? -ne 0 ]; then
            log_error "备份原配置文件失败"
            return 1
        fi
        log_info "原配置文件已备份到: $backup_file"
    fi
    
    # 创建新的配置内容
    cat > "$daemon_config" << EOF
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://docker.mirrors.ustc.edu.cn"
  ]
}
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Docker国内镜像源配置完成"
        
        # 重启Docker服务
        log_info "正在重启Docker服务..."
        if systemctl restart docker; then
            log_success "Docker服务重启成功"
        else
            log_error "Docker服务重启失败，请手动重启"
            return 1
        fi
    else
        log_error "Docker镜像源配置失败"
        return 1
    fi
}

# 安装缺失的网络工具
install_missing_network_tools() {
    log_header "安装缺失的网络工具"
    log_info "正在检查并安装缺失的网络工具..."
    
    # 定义需要的网络工具
    local tools=("ip" "ping" "curl" "wget" "nslookup" "dig" "traceroute" "netstat" "ss")
    local missing_tools=()
    local to_install=()
    
    # 检查哪些工具缺失
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_success "所有网络工具均已安装"
        return 0
    fi
    
    log_warn "检测到缺失的工具: ${missing_tools[*]}"
    
    # 询问用户是否安装
    read -p "是否安装缺失的网络工具? (y/N): " install_confirm
    if [[ ! "$install_confirm" =~ ^[Yy]$ ]]; then
        log_info "已取消安装"
        return 0
    fi
    
    # 根据系统类型安装工具
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu|debian)
                log_info "正在安装缺失的工具..."
                # 构建安装命令
                local install_cmd="apt-get update && apt-get install -y"
                
                # 映射工具到包名
                for tool in "${missing_tools[@]}"; do
                    case $tool in
                        nslookup|dig)
                            install_cmd+=" dnsutils"
                            ;;
                        traceroute)
                            install_cmd+=" traceroute"
                            ;;
                        netstat)
                            install_cmd+=" net-tools"
                            ;;
                        ss)
                            install_cmd+=" iproute2"
                            ;;
                        *)
                            install_cmd+=" $tool"
                            ;;
                    esac
                done
                
                eval $install_cmd
                ;;
            centos|rhel|rocky|almalinux)
                log_info "正在安装缺失的工具..."
                local install_cmd="yum install -y"
                
                # 映射工具到包名
                for tool in "${missing_tools[@]}"; do
                    case $tool in
                        nslookup|dig)
                            install_cmd+=" bind-utils"
                            ;;
                        traceroute)
                            install_cmd+=" traceroute"
                            ;;
                        netstat|ss)
                            install_cmd+=" iproute"
                            ;;
                        *)
                            install_cmd+=" $tool"
                            ;;
                    esac
                done
                
                eval $install_cmd
                ;;
            *)
                log_error "不支持的系统类型: $ID"
                return 1
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            log_success "缺失的网络工具安装完成"
            
            # 验证安装
            log_info "正在验证安装..."
            local still_missing=()
            for tool in "${missing_tools[@]}"; do
                if ! command -v "$tool" >/dev/null 2>&1; then
                    still_missing+=("$tool")
                fi
            done
            
            if [ ${#still_missing[@]} -eq 0 ]; then
                log_success "所有工具均已成功安装"
            else
                log_warn "以下工具安装可能失败: ${still_missing[*]}"
            fi
        else
            log_error "工具安装失败"
            return 1
        fi
    else
        log_error "无法识别系统类型"
        return 1
    fi
}

# 修复网络接口问题
repair_network_interface() {
    log_header "网络接口修复"
    log_info "正在检查网络接口问题..."
    
    # 获取网络接口列表
    mapfile -t interfaces < <(get_network_interfaces)
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        log_error "未检测到网络接口"
        return 1
    fi
    
    log_info "检测到以下网络接口:"
    for i in "${!interfaces[@]}"; do
        status=$(check_interface_status_quiet "${interfaces[$i]}")
        if [[ $status != error:* ]] && [[ $status == "UP" ]]; then
            echo -e "  ${GREEN}${interfaces[$i]}: UP${NC}"
        elif [[ $status != error:* ]]; then
            echo -e "  ${YELLOW}${interfaces[$i]}: $status${NC}"
        else
            echo -e "  ${RED}${interfaces[$i]}: ${status#error:}${NC}"
        fi
    done
    
    # 询问用户选择要修复的接口
    echo ""
    read -p "请选择要修复的网络接口 (输入接口名称或 'all' 修复所有接口): " selected_interface
    
    if [ "$selected_interface" = "all" ]; then
        # 修复所有接口
        for interface in "${interfaces[@]}"; do
            repair_single_interface "$interface"
        done
    elif [[ " ${interfaces[*]} " =~ " $selected_interface " ]]; then
        # 修复单个接口
        repair_single_interface "$selected_interface"
    else
        log_error "无效的接口名称: $selected_interface"
        return 1
    fi
}

# 修复单个网络接口
repair_single_interface() {
    local interface=$1
    
    log_info "正在修复网络接口: $interface"
    
    # 检查接口状态
    status=$(check_interface_status_quiet "$interface")
    if [[ $status == error:* ]]; then
        log_error "无法获取接口状态: ${status#error:}"
        return 1
    fi
    
    if [[ $status == "UP" ]]; then
        log_success "接口 $interface 已处于UP状态，无需修复"
        return 0
    fi
    
    # 尝试启用接口
    log_info "正在启用接口 $interface..."
    if ip link set "$interface" up; then
        log_success "接口 $interface 已启用"
        
        # 验证状态
        new_status=$(check_interface_status_quiet "$interface")
        if [[ $new_status == "UP" ]]; then
            log_success "接口 $interface 状态验证成功"
        else
            log_warn "接口 $interface 启用后状态仍为: $new_status"
        fi
    else
        log_error "启用接口 $interface 失败"
        return 1
    fi
}

# 程序入口点
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
