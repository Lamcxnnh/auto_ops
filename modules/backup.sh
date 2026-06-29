#!/bin/bash
#
# backup.sh - 文件备份模块
# 描述: 将指定目录压缩打包并添加时间戳，支持查看、恢复备份
# 依赖: config.sh (BACKUP_DIR), lib/utils.sh (confirm 函数)
#

# 创建备份
backup_files() {
    echo
    read -rp "请输入要备份的目录路径: " src_dir
    if [[ -z "$src_dir" ]]; then
        echo "路径不能为空！"
        return
    fi
    if [[ ! -d "$src_dir" ]]; then
        echo "错误：目录不存在！"
        return
    fi

    # 显示源目录大小
    local src_size
    src_size=$(du -sh "$src_dir" 2>/dev/null | cut -f1)
    echo "源目录大小: $src_size"

    if ! confirm "确认备份？"; then
        echo "操作取消。"
        return
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local dir_name
    dir_name=$(basename "$src_dir")
    local backup_name="backup_${dir_name}_${timestamp}.tar.gz"

    echo "正在备份..."
    tar -czf "$BACKUP_DIR/$backup_name" -C "$(dirname "$src_dir")" "$dir_name"

    if [[ $? -eq 0 ]]; then
        local final_size
        final_size=$(du -sh "$BACKUP_DIR/$backup_name" 2>/dev/null | cut -f1)
        echo "备份成功！文件: $BACKUP_DIR/$backup_name (大小: $final_size)"
    else
        echo "备份失败，请检查权限或路径。"
    fi
}

# 查看已有备份
list_backups() {
    echo
    echo "========== 已有备份列表 =========="
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "备份目录不存在，暂无备份。"
        return
    fi

    local count
    count=$(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar" -o -name "*.tar.bz2" -o -name "*.tgz" \) 2>/dev/null | wc -l)

    if [[ "$count" -eq 0 ]]; then
        echo "暂无备份文件。"
        return
    fi

    local i=1
    echo "序号 | 文件名                                      | 大小     | 修改时间"
    echo "-----|--------------------------------------------|----------|-------------------"
    while IFS= read -r f; do
        local fname fsize ftime
        fname=$(basename "$f")
        fsize=$(du -sh "$f" 2>/dev/null | cut -f1)
        ftime=$(stat -c '%Y' "$f" 2>/dev/null | xargs -I{} date -d @{} '+%Y-%m-%d %H:%M' 2>/dev/null || echo "未知")
        printf "%-4s | %-42s | %-8s | %s\n" "[$i]" "$fname" "$fsize" "$ftime"
        ((i++))
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar" -o -name "*.tar.bz2" -o -name "*.tgz" \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)

    echo "==================================="
    echo "共 $count 个备份文件"
}

# 恢复备份
restore_backup() {
    echo
    # 先列出备份
    echo "========== 选择要恢复的备份文件 =========="
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "备份目录不存在。"
        return
    fi

    local backups=()
    while IFS= read -r f; do
        backups+=("$f")
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "*.tar.gz" -o -name "*.tar" -o -name "*.tar.bz2" -o -name "*.tgz" \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "暂无备份文件可恢复。"
        return
    fi

    for i in "${!backups[@]}"; do
        local fname fsize
        fname=$(basename "${backups[$i]}")
        fsize=$(du -sh "${backups[$i]}" 2>/dev/null | cut -f1)
        echo "  [$((i+1))] $fname ($fsize)"
    done

    echo
    read -rp "请选择要恢复的备份编号 (输入 0 返回): " idx
    if [[ "$idx" == "0" || -z "$idx" ]]; then
        return
    fi
    if [[ ! "$idx" =~ ^[0-9]+$ ]] || [[ "$idx" -lt 1 || "$idx" -gt ${#backups[@]} ]]; then
        echo "无效编号！"
        return
    fi

    local selected="${backups[$((idx-1))]}"

    echo
    read -rp "请输入恢复到的目标目录 [默认: $(pwd)]: " dest_dir
    dest_dir="${dest_dir:-$(pwd)}"

    if [[ ! -d "$dest_dir" ]]; then
        echo "错误：目标目录 $dest_dir 不存在！"
        if confirm "是否创建该目录？"; then
            mkdir -p "$dest_dir" || { echo "创建失败！"; return; }
        else
            return
        fi
    fi

    # 检查目标目录是否非空，给出警告
    if [[ -n "$(ls -A "$dest_dir" 2>/dev/null)" ]]; then
        echo "警告：目标目录 $dest_dir 不是空目录，恢复可能覆盖已有文件。"
        if ! confirm "是否继续？"; then
            echo "操作取消。"
            return
        fi
    fi

    echo "正在恢复 $(basename "$selected") 到 $dest_dir ..."
    tar -xzf "$selected" -C "$dest_dir"

    if [[ $? -eq 0 ]]; then
        echo "恢复成功！文件已恢复到: $dest_dir"
    else
        echo "恢复失败，请检查磁盘空间和权限。"
    fi
}

# 备份管理子菜单
backup_menu() {
    while true; do
        clear
        echo "----- 文件备份管理 -----"
        echo "1. 创建备份"
        echo "2. 查看已有备份"
        echo "3. 恢复备份"
        echo "4. 返回主菜单"
        echo "----------------------"
        read -rp "请选择: " sub_choice || break
        case $sub_choice in
            1) backup_files ;;
            2) list_backups ;;
            3) restore_backup ;;
            4) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
