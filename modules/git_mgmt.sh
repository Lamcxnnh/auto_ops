#!/bin/bash
#
# git_mgmt.sh - Git 仓库管理模块
# 描述: 引导式 Git 操作，适配不熟悉 Git 的用户
#        覆盖：配置身份 → 获取代码 → 查看状态 → 提交 → 推送/拉取
# 依赖: lib/utils.sh (confirm, pause 函数)
#

# -----------------------------------------------------------
# 辅助：检查 git 是否安装
# -----------------------------------------------------------
check_git() {
    if ! command -v git &>/dev/null; then
        echo "错误：系统未安装 Git，请先执行: sudo apt install git" >&2
        return 1
    fi
    return 0
}

# -----------------------------------------------------------
# 辅助：选择仓库目录（返回全局变量 SELECTED_REPO）
# -----------------------------------------------------------
select_repo() {
    local scan_dir="${1:-$(pwd)}"
    if [[ ! -d "$scan_dir" ]]; then
        echo "错误：目录 $scan_dir 不存在！"
        return 1
    fi

    echo "正在扫描 $scan_dir 下的 Git 仓库..."
    local repos=()
    while IFS= read -r gitdir; do
        repos+=("$(dirname "$gitdir")")
    done < <(find "$scan_dir" -maxdepth 5 -type d -name ".git" 2>/dev/null || true)

    if [[ ${#repos[@]} -eq 0 ]]; then
        echo "未找到任何 Git 仓库。"
        echo "提示：你可以使用菜单中的「初始化本地仓库」功能创建一个。"
        return 1
    fi

    echo
    echo "找到 ${#repos[@]} 个 Git 仓库:"
    for i in "${!repos[@]}"; do
        cd "${repos[$i]}" || continue
        local br
        br=$(git branch --show-current 2>/dev/null || echo "?")
        echo "  [$((i+1))] ${repos[$i]}  (分支: $br)"
    done
    echo
    read -rp "请选择仓库编号 (输入 0 返回): " idx

    if [[ "$idx" == "0" || -z "$idx" ]]; then
        return 1
    fi
    if [[ "$idx" -ge 1 && "$idx" -le ${#repos[@]} ]]; then
        SELECTED_REPO="${repos[$((idx-1))]}"
        return 0
    else
        echo "无效编号！"
        return 1
    fi
}

# -----------------------------------------------------------
# 1. 配置用户信息
# -----------------------------------------------------------
git_config_user() {
    check_git || return

    echo
    echo "========== Git 用户配置 =========="
    echo "说明: Git 需要知道你的名字和邮箱，每次提交都会记录这些信息。"
    echo

    local cur_name cur_email
    cur_name=$(git config --global user.name 2>/dev/null || echo "")
    cur_email=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -n "$cur_name" && -n "$cur_email" ]]; then
        echo "当前全局配置:"
        echo "  用户名: $cur_name"
        echo "  邮箱:   $cur_email"
        echo
        if ! confirm "是否修改当前配置？"; then
            echo "保持现有配置不变。"
            return
        fi
    else
        echo "Git 用户信息尚未配置（或配置不完整）。"
        echo
    fi

    # 输入用户名
    echo
    read -rp "请输入你的用户名（如: Zhang San）: " new_name
    if [[ -z "$new_name" ]]; then
        echo "用户名不能为空，操作取消。"
        return
    fi

    # 输入邮箱
    read -rp "请输入你的邮箱（如: zhangsan@example.com）: " new_email
    if [[ -z "$new_email" ]]; then
        echo "邮箱不能为空，操作取消。"
        return
    fi

    # 确认
    echo
    echo "即将设置:"
    echo "  用户名: $new_name"
    echo "  邮箱:   $new_email"
    if confirm "确认配置？"; then
        git config --global user.name "$new_name"
        git config --global user.email "$new_email"
        echo
        echo "配置完成！"
        echo "  用户名: $(git config --global user.name)"
        echo "  邮箱:   $(git config --global user.email)"
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 2. 克隆远程仓库
# -----------------------------------------------------------
git_clone() {
    check_git || return

    echo
    echo "========== 克隆远程仓库 =========="
    echo "说明: 将远程仓库完整下载到本地，包含所有历史记录。"
    echo

    read -rp "请输入远程仓库 URL: " clone_url
    if [[ -z "$clone_url" ]]; then
        echo "URL 不能为空，操作取消。"
        return
    fi

    read -rp "请输入本地目录名（留空使用默认名称）: " dir_name

    # 检查目标目录
    if [[ -n "$dir_name" && -d "$dir_name" ]]; then
        echo "警告：目录 $dir_name 已存在！"
        if ! confirm "是否继续？git clone 要求目标目录不存在或为空。"; then
            return
        fi
    fi

    echo
    echo "正在克隆 $clone_url ..."
    if [[ -n "$dir_name" ]]; then
        git clone "$clone_url" "$dir_name"
    else
        git clone "$clone_url"
    fi

    if [[ $? -eq 0 ]]; then
        echo
        echo "克隆成功！"
        local cloned_dir
        cloned_dir="${dir_name:-$(basename "$clone_url" .git)}"
        echo "仓库位置: $(pwd)/$cloned_dir"
    else
        echo "克隆失败，请检查 URL 是否正确以及网络是否连通。"
    fi
}

# -----------------------------------------------------------
# 3. 初始化本地仓库
# -----------------------------------------------------------
git_init() {
    check_git || return

    echo
    echo "========== 初始化本地仓库 =========="
    echo "说明: 将一个普通目录变成 Git 仓库，开始版本管理。"
    echo

    read -rp "请输入要初始化的目录路径 [默认: $(pwd)]: " init_dir
    init_dir="${init_dir:-$(pwd)}"

    if [[ ! -d "$init_dir" ]]; then
        echo "错误：目录 $init_dir 不存在！"
        if confirm "是否创建该目录？"; then
            mkdir -p "$init_dir" || { echo "创建失败！"; return; }
        else
            return
        fi
    fi

    # 检查是否已经是 git 仓库
    if [[ -d "$init_dir/.git" ]]; then
        echo "该目录已经是 Git 仓库，无需重复初始化。"
        return
    fi

    cd "$init_dir" || { echo "无法进入目录 $init_dir"; return; }
    git init

    if [[ $? -eq 0 ]]; then
        echo
        echo "初始化成功！目录 $init_dir 已成为 Git 仓库。"

        # 提示关联远程仓库
        echo
        if confirm "是否需要关联远程仓库？"; then
            read -rp "请输入远程仓库 URL: " remote_url
            if [[ -n "$remote_url" ]]; then
                git remote add origin "$remote_url" 2>/dev/null && \
                    echo "远程仓库已关联: origin → $remote_url"
            fi
        fi

        echo
        echo "下一步建议:"
        echo "  1. 创建或复制文件到该目录"
        echo "  2. 使用本工具的「提交更改」功能提交"
    else
        echo "初始化失败。"
    fi
}

# -----------------------------------------------------------
# 4. 查看仓库状态（通俗版）
# -----------------------------------------------------------
git_status() {
    check_git || return

    if ! select_repo; then
        return
    fi
    local repo="$SELECTED_REPO"

    echo
    echo "========== 仓库状态 =========="
    cd "$repo" || return

    # 基本信息
    local branch
    branch=$(git branch --show-current 2>/dev/null || echo "（无分支，处于 detached HEAD）")
    echo "仓库路径: $repo"
    echo "当前分支: $branch"

    # 远端信息
    local remote
    remote=$(git remote 2>/dev/null | head -1 || true)
    if [[ -n "$remote" ]]; then
        local remote_url
        remote_url=$(git remote get-url "$remote" 2>/dev/null || echo "?")
        echo "远程仓库: $remote → $remote_url"
    else
        echo "远程仓库: 未配置"
    fi
    echo

    # 工作区状态
    local staged modified untracked
    staged=$(git diff --cached --name-only 2>/dev/null | wc -l || echo 0)
    modified=$(git diff --name-only 2>/dev/null | wc -l || echo 0)
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l || echo 0)

    if [[ "$staged" -eq 0 && "$modified" -eq 0 && "$untracked" -eq 0 ]]; then
        echo "✅ 工作区干净，没有待提交的更改。"
    else
        echo "📋 更改摘要:"

        if [[ "$staged" -gt 0 ]]; then
            echo
            echo "  ▸ 已暂存（将提交以下文件）:"
            git diff --cached --name-status 2>/dev/null | head -20 | while IFS= read -r line; do
                echo "    $line"
            done
            local more_staged
            more_staged=$((staged - 20))
            [[ "$more_staged" -gt 0 ]] && echo "    ... 还有 $more_staged 个文件"
        fi

        if [[ "$modified" -gt 0 ]]; then
            echo
            echo "  ▸ 已修改但未暂存:"
            git diff --name-only 2>/dev/null | head -20 | while IFS= read -r line; do
                echo "    (修改) $line"
            done
            local more_mod
            more_mod=$((modified - 20))
            [[ "$more_mod" -gt 0 ]] && echo "    ... 还有 $more_mod 个文件"
        fi

        if [[ "$untracked" -gt 0 ]]; then
            echo
            echo "  ▸ 未跟踪的新文件:"
            git ls-files --others --exclude-standard 2>/dev/null | head -20 | while IFS= read -r line; do
                echo "    (新增) $line"
            done
            local more_untracked
            more_untracked=$((untracked - 20))
            [[ "$more_untracked" -gt 0 ]] && echo "    ... 还有 $more_untracked 个文件"
        fi
    fi

    echo "==============================="
}

# -----------------------------------------------------------
# 5. 引导式提交
# -----------------------------------------------------------
git_commit() {
    check_git || return

    echo
    echo "========== 引导式提交 =========="

    # 先检查是否有配置
    local cur_name cur_email
    cur_name=$(git config user.name 2>/dev/null || git config --global user.name 2>/dev/null || echo "")
    cur_email=$(git config user.email 2>/dev/null || git config --global user.email 2>/dev/null || echo "")
    if [[ -z "$cur_name" || -z "$cur_email" ]]; then
        echo "⚠ Git 用户信息未配置，提交前需要先设置身份。"
        echo "  请先使用菜单中的「配置用户信息」功能。"
        return
    fi
    echo "提交者: $cur_name <$cur_email>"
    echo

    if ! select_repo; then
        return
    fi
    local repo="$SELECTED_REPO"
    cd "$repo" || return

    # 显示当前状态
    echo
    echo ">>> 当前仓库状态:"
    git status --short 2>/dev/null || echo "  (无法获取状态)"

    local total_changes
    total_changes=$(git status --short 2>/dev/null | wc -l || echo 0)

    if [[ "$total_changes" -eq 0 ]]; then
        echo
        echo "没有需要提交的更改，工作区干净。"
        return
    fi

    echo
    echo "----- 提交方式 -----"
    echo "1. 提交所有更改 (git add -A)"
    echo "2. 手动输入要提交的文件"
    echo "3. 返回"
    echo "------------------"
    read -rp "请选择: " commit_way

    case $commit_way in
        1)
            echo "正在暂存所有更改..."
            git add -A
            ;;
        2)
            echo
            read -rp "请输入要提交的文件路径（多个文件用空格分隔）: " files
            if [[ -z "$files" ]]; then
                echo "文件路径不能为空，操作取消。"
                return
            fi
            echo "正在暂存指定文件: $files"
            # shellcheck disable=SC2086
            git add $files || { echo "暂存失败，请检查文件路径。"; return; }
            ;;
        3) return ;;
        *) echo "无效选项！"; return ;;
    esac

    # 再次显示即将提交的内容
    echo
    echo ">>> 即将提交的内容:"
    git diff --cached --stat 2>/dev/null || echo "  (无内容)"

    # 输入提交信息
    echo
    read -rp "请输入提交信息（简要描述你做了什么修改）: " commit_msg
    if [[ -z "$commit_msg" ]]; then
        echo "提交信息不能为空！操作取消。"
        echo "提示: 好的提交信息如「修复登录页面样式问题」「添加用户注册接口」"
        return
    fi

    # 确认并提交
    echo
    echo "提交信息: $commit_msg"
    if confirm "确认提交？"; then
        git commit -m "$commit_msg"
        if [[ $? -eq 0 ]]; then
            echo
            echo "✅ 提交成功！"
            echo "提示: 使用「推送到远程」将本地提交同步到远程仓库。"
        else
            echo "提交失败。"
        fi
    else
        echo "操作取消。"
        echo "提示: 已暂存的文件可以通过再次选择「提交更改」来提交。"
    fi
}

# -----------------------------------------------------------
# 6. 推送到远程
# -----------------------------------------------------------
git_push() {
    check_git || return

    echo
    echo "========== 推送到远程仓库 =========="
    if ! select_repo; then
        return
    fi
    local repo="$SELECTED_REPO"
    cd "$repo" || return

    local branch
    branch=$(git branch --show-current 2>/dev/null || echo "")
    if [[ -z "$branch" ]]; then
        echo "错误：当前不处于任何分支（detached HEAD），无法推送。"
        return
    fi

    local remote
    remote=$(git remote 2>/dev/null | head -1 || true)
    if [[ -z "$remote" ]]; then
        echo "错误：该仓库未配置远程仓库。"
        echo "提示: 如果你有远程仓库 URL，可以手动执行:"
        echo "  git remote add origin <URL>"
        echo "  git push -u origin $branch"
        return
    fi

    # 显示推送信息
    local ahead
    ahead=$(git rev-list --count "${remote}/${branch}..HEAD" 2>/dev/null || echo "?")
    echo "远程仓库: $remote ($(git remote get-url "$remote" 2>/dev/null))"
    echo "当前分支: $branch"
    echo "本地领先远程: $ahead 个提交"

    if [[ "$ahead" == "0" ]]; then
        echo
        echo "没有需要推送的内容，本地已与远程同步。"
        return
    fi

    git log --oneline "${remote}/${branch}..HEAD" 2>/dev/null | head -10 || true

    echo
    if confirm "确认推送以上 $ahead 个提交到 $remote/$branch？"; then
        echo "正在推送..."
        git push -u "$remote" "$branch"
        if [[ $? -eq 0 ]]; then
            echo
            echo "✅ 推送成功！"
        else
            echo
            echo "推送失败。可能的原因:"
            echo "  - 远程仓库有新的提交，请先使用「拉取远程更新」"
            echo "  - 没有推送权限"
            echo "  - 网络不通"
        fi
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 7. 拉取远程更新
# -----------------------------------------------------------
git_pull() {
    check_git || return

    echo
    echo "========== 拉取远程更新 =========="
    if ! select_repo; then
        return
    fi
    local repo="$SELECTED_REPO"
    cd "$repo" || return

    local branch
    branch=$(git branch --show-current 2>/dev/null || echo "")

    local remote
    remote=$(git remote 2>/dev/null | head -1 || true)
    if [[ -z "$remote" ]]; then
        echo "错误：该仓库未配置远程仓库。"
        return
    fi

    echo "远程仓库: $remote ($(git remote get-url "$remote" 2>/dev/null))"
    [[ -n "$branch" ]] && echo "当前分支: $branch"

    # 检查工作区是否干净
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo
        echo "⚠ 警告: 工作区有未提交的更改！"
        echo "  拉取前建议先提交更改，否则可能导致冲突。"
        if ! confirm "是否仍然尝试拉取（建议选择 n，先提交再拉取）？"; then
            echo "操作取消。建议先使用「提交更改」功能。"
            return
        fi
    fi

    echo
    echo "正在拉取..."
    if [[ -n "$branch" ]]; then
        git pull "$remote" "$branch" 2>&1
    else
        git pull "$remote" 2>&1
    fi

    if [[ $? -eq 0 ]]; then
        echo
        echo "✅ 拉取成功！"
    else
        echo
        echo "拉取失败。可能的原因:"
        echo "  - 网络不通"
        echo "  - 本地有冲突，需要手动解决（git status 查看详情）"
    fi
}

# -----------------------------------------------------------
# 8. 查看提交历史
# -----------------------------------------------------------
git_log() {
    check_git || return

    if ! select_repo; then
        return
    fi
    local repo="$SELECTED_REPO"

    while true; do
        clear
        echo "----- 提交历史 -----"
        echo "1. 查看最近 10 条"
        echo "2. 查看最近 20 条"
        echo "3. 查看最近 50 条"
        echo "4. 按作者筛选"
        echo "5. 返回上级菜单"
        echo "------------------"
        read -rp "请选择: " log_choice

        case $log_choice in
            1)
                echo
                cd "$repo" || continue
                echo "========== 最近 10 条提交 =========="
                git log --oneline -10 2>/dev/null || echo "暂无提交记录。"
                ;;
            2)
                echo
                cd "$repo" || continue
                echo "========== 最近 20 条提交 =========="
                git log --oneline -20 2>/dev/null || echo "暂无提交记录。"
                ;;
            3)
                echo
                cd "$repo" || continue
                echo "========== 最近 50 条提交 =========="
                git log --oneline -50 2>/dev/null || echo "暂无提交记录。"
                ;;
            4)
                echo
                read -rp "请输入作者名称: " author
                if [[ -n "$author" ]]; then
                    cd "$repo" || continue
                    echo "========== $author 的提交 =========="
                    git log --oneline --author="$author" -20 2>/dev/null || echo "未找到匹配的提交。"
                fi
                ;;
            5) break ;;
            *) echo "无效选项！" ;;
        esac
        pause
    done
}

# -----------------------------------------------------------
# Git 管理主菜单
# -----------------------------------------------------------
git_menu() {
    # 首次进入时检查 git 是否安装
    if ! command -v git &>/dev/null; then
        echo
        echo "⚠ 系统未安装 Git。"
        echo "  安装命令: sudo apt install git"
        echo
        pause
        return
    fi

    while true; do
        clear
        echo "----- Git 仓库管理 -----"
        echo "1. 配置用户信息（用户名/邮箱）"
        echo "2. 克隆远程仓库"
        echo "3. 初始化本地仓库"
        echo "4. 查看仓库状态"
        echo "5. 提交更改"
        echo "6. 推送到远程"
        echo "7. 拉取远程更新"
        echo "8. 查看提交历史"
        echo "9. 返回主菜单"
        echo "----------------------"
        read -rp "请选择: " choice || break
        case $choice in
            1) git_config_user ;;
            2) git_clone ;;
            3) git_init ;;
            4) git_status ;;
            5) git_commit ;;
            6) git_push ;;
            7) git_pull ;;
            8) git_log ;;
            9) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
