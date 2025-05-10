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
        echo "2. 执行dkn-compute-launcher referrals"
        read -p "请输入选项 (1-2): " choice
        case $choice in
            1)
                deploy_dria_node
                ;;
            2)
                run_referrals
                ;;
            *)
                echo "无效选项，请输入 1 或 2"
                sleep 2
                ;;
        esac
    done
}

# 部署dria节点函数
function deploy_dria_node() {
    # 定义关键变量
    ENV_DIR="/root/.dria/dkn-compute-launcher"
    ENV_FILE="$ENV_DIR/.env"
    DKN_INSTALL_DIR="/root/.dria"
    DKN_BIN_DIR="$DKN_INSTALL_DIR/bin"

    # 确保以 root 权限运行
    if [ "$EUID" -ne 0 ]; then
        echo "请以 root 权限运行此脚本 (sudo)"
        exit 1
    fi

    # 限制为 Linux 系统
    if [ "$(uname -s)" != "Linux" ]; then
        echo "错误：此脚本仅支持 Linux 系统"
        exit 1
    fi

    # 获取用户输入
    echo "请输入钱包密钥 (DKN_WALLET_SECRET_KEY):"
    read -s DKN_WALLET_SECRET_KEY
    if [ -z "$DKN_WALLET_SECRET_KEY" ]; then
        echo "错误：未提供钱包密钥"
        exit 1
    fi

    echo "请输入模型列表 (DKN_MODELS, 用逗号分隔，默认为 gemini-2.0-flash):"
    read DKN_MODELS
    DKN_MODELS=${DKN_MODELS:-"gemini-2.0-flash"}

    echo "请输入端口号 (默认 4090):"
    read port
    port=${port:-"4090"}

    echo "请输入 Gemini API 密钥 (必填，留空跳过):"
    read -s GEMINI_API_KEY

    # 创建必要目录
    mkdir -p "$DKN_INSTALL_DIR" "$DKN_BIN_DIR" "$ENV_DIR" || { echo "错误：无法创建目录"; exit 1; }

    # 检查并安装基本依赖
    for cmd in curl bash unzip ss lsof screen; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "正在安装 $cmd..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update
                apt-get install -y "$cmd"
            elif command -v yum >/dev/null 2>&1; then
                yum install -y "$cmd"
            elif command -v dnf >/dev/null 2>&1; then
                dnf install -y "$cmd"
            else
                echo "错误：不支持的包管理器，请手动安装 $cmd"
                exit 1
            fi
        fi
    done

    # 检查网络连接
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        echo "错误：无法连接到网络"
        exit 1
    fi

    # 检查并安装 Ollama
    if ! command -v ollama >/dev/null 2>&1; then
        echo "安装 Ollama..."
        curl -fsSL https://ollama.com/install.sh | bash
    fi

    # 检查并安装 dkn-compute-launcher
    if ! command -v "$DKN_BIN_DIR/dkn-compute-launcher" >/dev/null 2>&1; then
        echo "安装 dkn-compute-launcher..."
        curl -fsSL https://dria.co/launcher | bash
    fi

    # 设置环境变量
    export DKN_INSTALL="$DKN_INSTALL_DIR"
    export PATH="$DKN_BIN_DIR:$HOME/.cargo/bin:$PATH"
    if ! grep -q "$DKN_BIN_DIR" /root/.bashrc; then
        echo "export PATH=\"$DKN_BIN_DIR:\$PATH\"" >> /root/.bashrc
    fi
    if ! grep -q ".cargo/bin" /root/.bashrc; then
        echo "export PATH=\"$HOME/.cargo/bin:\$PATH\"" >> /root/.bashrc
    fi
    source /root/.bashrc

    # 检查端口
    if ss -tuln | grep ":$port" >/dev/null 2>&1 || lsof -i :$port >/dev/null 2>&1; then
        echo "错误：端口 $port 已被占用"
        exit 1
    fi

    # 设置 P2P 地址
    DKN_P2P_LISTEN_ADDR="/ip4/0.0.0.0/tcp/$port"

    # 验证并拉取 Ollama 模型
    IFS=',' read -ra MODELS <<< "$DKN_MODELS"
    for model in "${MODELS[@]}"; do
        if [[ "$model" == *"phi3"* || "$model" == *"llama"* || "$model" == *"gemini"* ]]; then
            if ! ollama list | grep -q "$model"; then
                echo "拉取模型 $model..."
                ollama pull "$model"
            fi
        fi
    done

    # 写入 .env 文件
    cat > "$ENV_FILE" << EOL
DKN_WALLET_SECRET_KEY=$DKN_WALLET_SECRET_KEY
DKN_MODELS=$DKN_MODELS
DKN_P2P_LISTEN_ADDR=$DKN_P2P_LISTEN_ADDR
OLLAMA_HOST=http://127.0.0.1
OLLAMA_PORT=11434
OLLAMA_AUTO_PULL=true
$( [ -n "$GEMINI_API_KEY" ] && echo "GEMINI_API_KEY=$GEMINI_API_KEY" || echo "#GEMINI_API_KEY=" )
RUST_LOG=debug
EOL

    chmod 600 "$ENV_FILE"

    # 启动 dkn-compute-launcher
    screen -dmS dria bash -c "$DKN_BIN_DIR/dkn-compute-launcher start; exec bash"
    echo "dkn-compute-launcher 已启动，使用 'screen -r dria' 查看"

    # 清理敏感变量
    unset DKN_WALLET_SECRET_KEY
    unset GEMINI_API_KEY

    # 显示安装总结
    echo "安装总结："
    echo "- Ollama：$(command -v ollama >/dev/null && echo '已安装' || echo '未安装')"
    echo "- dkn-compute-launcher：$(command -v $DKN_BIN_DIR/dkn-compute-launcher >/dev/null && echo '已安装' || echo '未安装')"
    echo "- unzip：$(command -v unzip >/dev/null && echo '已安装' || echo '未安装')"
    echo "如需帮助，请访问：https://github.com/firstbatchxyz/dkn-compute-launcher"
    echo "按任意键返回主菜单..."
    read -n 1
}

# 执行 referrals 函数
function run_referrals() {
    # 确保环境变量已设置
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! grep -q ".cargo/bin" /root/.bashrc; then
        echo "export PATH=\"$HOME/.cargo/bin:\$PATH\"" >> /root/.bashrc
    fi
    source /root/.bashrc

    # 检查 dkn-compute-launcher 是否存在
    if ! command -v dkn-compute-launcher >/dev/null 2>&1; then
        echo "错误：dkn-compute-launcher 未安装，请先运行选项 1 部署dria节点"
        echo "按任意键返回主菜单..."
        read -n 1
        return
    fi

    # 执行 referrals 命令
    echo "正在执行 dkn-compute-launcher referrals..."
    dkn-compute-launcher referrals
    if [ $? -eq 0 ]; then
        echo "referrals 命令执行成功"
    else
        echo "错误：referrals 命令执行失败"
    fi

    echo "按任意键返回主菜单..."
    read -n 1
}

# 执行主菜单
main_menu
