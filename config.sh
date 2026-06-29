#!/bin/bash
#
# config.sh - 全局配置
# 描述: 定义所有模块共享的全局变量和路径
#

# 备份文件存储目录
BACKUP_DIR="/tmp/backup"

# 确保备份目录存在
mkdir -p "$BACKUP_DIR"
