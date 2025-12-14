#!/bin/bash

echo "系统信息查看"
echo "=========================="

echo "主机名: $(hostname)"
echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "内核版本: $(uname -r)"
echo "CPU信息: $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)"
echo "内存总量: $(free -h | grep Mem | awk '{print $2}')"
echo "磁盘使用情况:"
df -h
echo "=========================="
echo "系统信息查看完成！"