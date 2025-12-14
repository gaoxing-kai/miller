#!/bin/bash

echo "开始网络速度测试..."
echo "=========================="

# 安装speedtest-cli
if ! command -v speedtest-cli &> /dev/null; then
    echo "正在安装speedtest-cli..."
    apt-get update && apt-get install -y speedtest-cli
fi

# 执行速度测试
echo "正在进行速度测试，请稍候..."
speedtest-cli --simple

echo "=========================="
echo "网络速度测试完成！"