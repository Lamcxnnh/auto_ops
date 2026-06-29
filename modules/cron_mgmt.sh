#!/bin/bash
#
# cron_mgmt.sh - 定时任务管理模块
# 描述: 查看、添加、删除、备份、恢复当前用户 crontab
# 依赖: lib/utils.sh (confirm, pause 函数)
#

# -----------------------------------------------------------
# 辅助：解析 crontab 时间表达式
# -----------------------------------------------------------
parse_cron_time() {
    local min="$1" hour="$2" dom="$3" month="$4" dow="$5"
    # 返回中文描述
    if [[ "$min" == "*" && "$hour" == "*" && "$dom" == "*" && "$month" == "*" && "$dow" == "*" ]]; then
        echo "每分钟"
    elif [[ "$min" =~ ^\*/([0-9]+)$ ]]; then
        echo "每${BASH_REMATCH[1]}分钟"
    elif [[ "$min" == "0" && "$hour" == "*" && "$dom" == "*" && "$month" == "*" && "$dow" == "*" ]]; then
        echo "每小时整点"
    elif [[ "$min" == "0" && "$hour" =~ ^([0-9]+)$ && "$dom" == "*" && "$month" == "*" && "$dow" == "*" ]]; then
        echo "每天 ${BASH_REMATCH[1]}:00"
    elif [[ "$min" == "0" && "$hour" == "0" && "$dom" == "*" && "$month" == "*" && "$dow" == "*" ]]; then
        echo "每天 00:00"
    elif [[ "$dom" =~ ^[0-9]+$ && "$month" == "*" && "$dow" == "*" ]]; then
        echo "每月 ${dom} 号 ${hour}:${min}"
    elif [[ "$dow" =~ ^[0-7]$ && "$dom" == "*" && "$month" == "*" ]]; then
        local day_names=("日" "一" "二" "三" "四" "五" "六" "日")
        echo "每周${day_names[$dow]} ${hour}:${min}"
    else
        echo "$min $hour $dom $month $dow"
    fi
}

# -----------------------------------------------------------
# 1. 查看 crontab
# -----------------------------------------------------------
cron_list() {
    echo
    echo "========== 当前用户定时任务 ($USER) =========="

    local cron_content
    cron_content=$(crontab -l 2>/dev/null || true)

    if [[ -z "$cron_content" ]]; then
        echo "当前没有定时任务。"
        return
    fi

    local i=1
    while IFS= read -r line; do
        # 跳过空行和注释
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            echo "  # ${line#\#}"
            continue
        fi
        # 解析 cron 条目
        if [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
            local m h d mo w cmd
            m="${BASH_REMATCH[1]}"; h="${BASH_REMATCH[2]}"; d="${BASH_REMATCH[3]}"
            mo="${BASH_REMATCH[4]}"; w="${BASH_REMATCH[5]}"; cmd="${BASH_REMATCH[6]}"
            local desc
            desc=$(parse_cron_time "$m" "$h" "$d" "$mo" "$w")
            printf "  [%d] %-20s → %s\n" "$i" "$desc" "$cmd"
            printf "      表达式: %s %s %s %s %s\n" "$m" "$h" "$d" "$mo" "$w"
        else
            echo "  [?] $line (格式异常)"
        fi
        ((i++))
    done <<< "$cron_content"

    echo "========================================="
}

# -----------------------------------------------------------
# 2. 添加定时任务
# -----------------------------------------------------------
cron_add() {
    echo
    echo "========== 添加定时任务 =========="
    echo
    echo "选择执行频率:"
    echo "  1. 每分钟"
    echo "  2. 每小时（整点）"
    echo "  3. 每天（凌晨 02:00）"
    echo "  4. 每周（周日 03:00）"
    echo "  5. 每月（1号 04:00）"
    echo "  6. 自定义"
    echo "  7. 返回"
    read -rp "请选择: " freq || return

    local cron_time
    case $freq in
        1) cron_time="* * * * *" ;;
        2) cron_time="0 * * * *" ;;
        3) cron_time="0 2 * * *" ;;
        4) cron_time="0 3 * * 0" ;;
        5) cron_time="0 4 1 * *" ;;
        6)
            echo
            echo "输入 cron 表达式（分 时 日 月 周）:"
            echo "  示例: */5 * * * *  (每5分钟)"
            echo "  示例: 30 8 * * 1  (每周一早8:30)"
            read -rp "请输入: " cron_time
            [[ -z "$cron_time" ]] && return
            ;;
        7) return ;;
        *) echo "无效选择！"; return ;;
    esac

    echo
    read -rp "请输入要执行的命令: " cmd
    if [[ -z "$cmd" ]]; then
        echo "命令不能为空！"
        return
    fi

    echo
    echo "即将添加:"
    echo "  频率: $cron_time"
    echo "  命令: $cmd"
    if confirm "确认添加？"; then
        # 先获取当前 crontab，追加，再写回
        local tmpfile
        tmpfile=$(mktemp)
        crontab -l 2>/dev/null > "$tmpfile" || true
        echo "$cron_time $cmd" >> "$tmpfile"
        crontab "$tmpfile" && rm -f "$tmpfile"
        echo
        echo "✅ 定时任务已添加。"
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 3. 删除定时任务
# -----------------------------------------------------------
cron_remove() {
    echo

    local cron_content
    cron_content=$(crontab -l 2>/dev/null || true)

    if [[ -z "$cron_content" ]]; then
        echo "当前没有定时任务可删除。"
        return
    fi

    # 收集非注释、非空的任务行
    local lines=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        lines+=("$line")
    done <<< "$cron_content"

    if [[ ${#lines[@]} -eq 0 ]]; then
        echo "当前没有定时任务可删除。"
        return
    fi

    echo "========== 删除定时任务 =========="
    local i=1
    for line in "${lines[@]}"; do
        printf "  [%d] %s\n" "$i" "$line"
        ((i++))
    done
    echo "  [0] 返回"

    echo
    read -rp "请选择要删除的任务编号: " idx
    [[ "$idx" == "0" || -z "$idx" ]] && return
    if [[ ! "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 || "$idx" -gt ${#lines[@]} ]]; then
        echo "无效编号！"
        return
    fi

    local target="${lines[$((idx-1))]}"
    echo
    echo "即将删除: $target"
    if confirm "确认删除此任务？"; then
        local tmpfile
        tmpfile=$(mktemp)
        crontab -l 2>/dev/null | grep -vF "$target" > "$tmpfile" || true
        crontab "$tmpfile" && rm -f "$tmpfile"
        echo
        echo "✅ 定时任务已删除。"
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 定时任务管理主菜单
# -----------------------------------------------------------
cron_menu() {
    while true; do
        clear
        echo "----- 定时任务管理 -----"
        echo "1. 查看当前 crontab"
        echo "2. 添加定时任务"
        echo "3. 删除定时任务"
        echo "4. 返回主菜单"
        echo "----------------------"
        read -rp "请选择: " choice || break
        case $choice in
            1) cron_list ;;
            2) cron_add ;;
            3) cron_remove ;;
            4) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
