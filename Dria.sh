#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/dria.sh"

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "tg频道：https://t.me/Sdohua"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 部署dria节点"
        echo "2. 退出"
        
        read -p "请输入选项 (1/2): " choice
        
        case $choice in
            1)
                run_dkn_compute_launcher
                ;;
            2)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请重试。"
                sleep 2
                ;;
        esac
    done
}

# 运行 dkn-compute-launcher 的函数
function run_dkn_compute_launcher() {
    # 检查是否以 root 用户运行脚本
    if [ "$(id -u)" != "0" ]; then
        echo "此脚本需要以 root 用户权限运行。"
        echo "请尝试使用 'sudo -i' 命令切换到 root 用户，然后再次运行此脚本。"
        exit 1
    fi

    # 定义文件名
    FILE="dkn-compute-node"

    # 检查文件是否存在
    if [ -e "$FILE" ]; then
        echo "$FILE 存在，正在删除..."
        rm -rf "$FILE"  # 使用 -rf 以确保删除目录及其内容
        echo "$FILE 已成功删除。"
    else
        echo "$FILE 不存在，无需删除。"
    fi

    # 下载最新版本的 dkn-compute-launcher
    echo "正在下载 dkn-compute-node.zip..."
    curl -L -o dkn-compute-node.zip https://github.com/firstbatchxyz/dkn-compute-launcher/releases/latest/download/dkn-compute-launcher-linux-amd64.zip

    # 解压缩下载的文件
    echo "正在解压 dkn-compute-node.zip..."
    unzip dkn-compute-node.zip

    # 进入解压后的目录
    cd dkn-compute-node || { echo "进入目录失败"; exit 1; }

    # 创建一个新的 screen 会话并运行 ./dkn-compute-launcher
    echo "正在创建 screen 会话并运行 ./dkn-compute-launcher..."
    screen -S dria -dm ./dkn-compute-launcher

    echo "操作完成，当前目录为: $(pwd)"
    echo "dkn-compute-launcher 已在 screen 会话 'dria' 中运行。"
    echo "使用 'screen -r dria' 命令查看运行状态。"
}

# 调用主菜单函数
main_menu
