#!/bin/bash
#
# network_test.sh - 网络检测模块
# 描述: 提供 Ping 检测、DNS 解析、本机网络信息查看
#

# Ping 连通性检测
network_ping() {
    echo
    read -rp "请输入要 ping 的主机（IP 或域名）: " host
    if [[ -z "$host" ]]; then
        echo "主机地址不能为空！"
        return
    fi
    echo "正在 ping $host ..."
    ping -c 4 "$host"
    if [[ $? -eq 0 ]]; then
        echo "网络连通正常。"
    else
        echo "网络无法连通，请检查网络或主机名。"
    fi
}

# DNS 解析
dns_resolve() {
    echo
    read -rp "请输入要解析的域名: " domain
    if [[ -z "$domain" ]]; then
        echo "域名不能为空！"
        return
    fi

    echo
    echo "========== DNS 解析: $domain =========="

    # 尝试 dig
    if command -v dig &>/dev/null; then
        echo
        echo ">>> dig 查询结果:"
        dig +short "$domain" 2>/dev/null || echo "  解析失败"
        echo
        echo ">>> dig 详细查询:"
        dig "$domain" ANY +noall +answer 2>/dev/null | grep -v '^;' | grep -v '^$' || echo "  无详细记录"
        echo
        echo ">>> NS 记录:"
        dig "$domain" NS +short 2>/dev/null || echo "  无 NS 记录"
    elif command -v nslookup &>/dev/null; then
        echo ">>> nslookup 查询结果:"
        nslookup "$domain" 2>/dev/null
    elif command -v host &>/dev/null; then
        echo ">>> host 查询结果:"
        host "$domain" 2>/dev/null
    else
        # 使用 getent 作为最终备选
        echo ">>> getent 查询结果:"
        getent hosts "$domain" 2>/dev/null || echo "  未找到 dig/nslookup/host 命令，且 getent 解析失败。"
        echo "  建议安装: sudo apt install dnsutils"
    fi

    echo "========================================"
}

# 本机网络信息
show_netinfo() {
    echo
    echo "========== 本机网络信息 =========="

    # 主机名
    echo
    echo ">>> 主机名: $(hostname)"

    # 默认网关
    echo
    echo ">>> 默认网关:"
    ip route show default 2>/dev/null | awk '{print "  " $3}' || echo "  无法获取"

    # DNS 服务器
    echo
    echo ">>> DNS 服务器:"
    if [[ -f /etc/resolv.conf ]]; then
        grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print "  " $2}' || echo "  未配置"
    else
        # systemd-resolved
        if command -v resolvectl &>/dev/null; then
            resolvectl dns 2>/dev/null | grep -v '^$' || echo "  无法获取"
        else
            echo "  无法获取"
        fi
    fi

    # 网络接口
    echo
    echo ">>> 网卡信息:"
    echo "  接口          状态    IP 地址                       MAC 地址"
    echo "  ------------  ------  ----------------------------  -------------------"

    local status ip mac
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        # 状态
        if [[ "$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)" == "up" ]]; then
            status="UP  "
        else
            status="DOWN"
        fi
        # IP
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d./]+' | head -1)
        [[ -z "$ip" ]] && ip="-"
        # MAC
        mac=$(cat "/sys/class/net/$iface/address" 2>/dev/null || echo "-")
        printf "  %-12s  %-6s  %-28s  %s\n" "$iface" "$status" "$ip" "$mac"
    done

    # 公网 IP
    echo
    echo ">>> 公网出口 IP:"
    if command -v curl &>/dev/null; then
        local pub_ip
        pub_ip=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null || \
                 curl -s --max-time 3 https://icanhazip.com 2>/dev/null || \
                 curl -s --max-time 3 https://api.ipify.org 2>/dev/null || \
                 echo "  无法获取（网络不可达或超时）")
        echo "  $pub_ip"
    else
        echo "  未安装 curl，无法检测"
    fi

    echo "==================================="
}

# 网络检测子菜单
network_menu() {
    while true; do
        clear
        echo "----- 网络检测 -----"
        echo "1. Ping 连通性检测"
        echo "2. DNS 解析查询"
        echo "3. 本机网络信息"
        echo "4. 返回主菜单"
        echo "------------------"
        read -rp "请选择: " sub_choice || break
        case $sub_choice in
            1) network_ping ;;
            2) dns_resolve ;;
            3) show_netinfo ;;
            4) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
