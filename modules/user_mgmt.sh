#!/bin/bash
#
# user_mgmt.sh - 用户管理模块
# 描述: 提供添加用户、删除用户、列出用户、锁定解锁、组成员管理等功能
# 依赖: lib/utils.sh (confirm 函数)
#

# 添加用户（含密码设置）
add_user() {
    echo
    read -rp "请输入新用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if id "$username" &>/dev/null; then
        echo "用户 $username 已存在！"
        return
    fi
    sudo useradd -m "$username" && echo "用户 $username 创建成功！"

    # 设置密码
    echo
    if confirm "是否现在为用户 $username 设置密码？"; then
        sudo passwd "$username"
    else
        echo "用户 $username 未设置密码，稍后可用 sudo passwd $username 设置。"
    fi
}

# 删除用户
del_user() {
    echo
    read -rp "请输入要删除的用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if id "$username" &>/dev/null; then
        if confirm "确认删除用户 $username 及其家目录？"; then
            sudo userdel -r "$username" && echo "用户 $username 已删除！"
        else
            echo "操作取消。"
        fi
    else
        echo "用户 $username 不存在！"
    fi
}

# 列出所有用户
list_users() {
    echo
    echo "系统所有用户（UID>=1000）:"
    awk -F: '$3>=1000 {print $1}' /etc/passwd | sort
}

# 锁定用户
lock_user() {
    echo
    read -rp "请输入要锁定的用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在！"
        return
    fi
    if confirm "确认锁定用户 $username？锁定后该用户将无法登录。"; then
        sudo usermod -L "$username" && echo "用户 $username 已锁定。"
    else
        echo "操作取消。"
    fi
}

# 解锁用户
unlock_user() {
    echo
    read -rp "请输入要解锁的用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在！"
        return
    fi
    if confirm "确认解锁用户 $username？"; then
        sudo usermod -U "$username" && echo "用户 $username 已解锁。"
    else
        echo "操作取消。"
    fi
}

# 查看用户所属组
show_user_groups() {
    echo
    read -rp "请输入要查询的用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在！"
        return
    fi
    echo
    echo "用户 $username 的信息:"
    id "$username"
    echo
    echo "所属组列表:"
    groups "$username"
}

# 将用户加入组
add_to_group() {
    echo
    read -rp "请输入用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在！"
        return
    fi
    echo "用户 $username 当前所属组: $(groups "$username" 2>/dev/null)"
    echo
    read -rp "请输入要加入的组名: " groupname
    if [[ -z "$groupname" ]]; then
        echo "组名不能为空！"
        return
    fi
    if ! getent group "$groupname" &>/dev/null; then
        echo "组 $groupname 不存在！"
        return
    fi
    if confirm "确认将用户 $username 加入组 $groupname？"; then
        sudo usermod -aG "$groupname" "$username" && echo "用户 $username 已加入组 $groupname。"
    else
        echo "操作取消。"
    fi
}

# 将用户移出组
remove_from_group() {
    echo
    read -rp "请输入用户名: " username
    if [[ -z "$username" ]]; then
        echo "用户名不能为空！"
        return
    fi
    if ! id "$username" &>/dev/null; then
        echo "用户 $username 不存在！"
        return
    fi
    echo "用户 $username 当前所属组: $(groups "$username" 2>/dev/null)"
    echo
    read -rp "请输入要移出的组名: " groupname
    if [[ -z "$groupname" ]]; then
        echo "组名不能为空！"
        return
    fi
    if confirm "确认将用户 $username 从组 $groupname 移出？"; then
        sudo gpasswd -d "$username" "$groupname" && echo "用户 $username 已从组 $groupname 移出。"
    else
        echo "操作取消。"
    fi
}

# 用户管理子菜单
user_menu() {
    while true; do
        clear
        echo "----- 用户管理 -----"
        echo "1. 添加用户"
        echo "2. 删除用户"
        echo "3. 列出所有用户"
        echo "4. 锁定用户"
        echo "5. 解锁用户"
        echo "6. 查看用户所属组"
        echo "7. 将用户加入组"
        echo "8. 将用户移出组"
        echo "9. 返回主菜单"
        echo "------------------"
        read -rp "请选择: " sub_choice || break
        case $sub_choice in
            1) add_user ;;
            2) del_user ;;
            3) list_users ;;
            4) lock_user ;;
            5) unlock_user ;;
            6) show_user_groups ;;
            7) add_to_group ;;
            8) remove_from_group ;;
            9) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
