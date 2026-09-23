#!/usr/bin/env bash
# OpenCode 文件桥接助手 / File bridge helper
set -euo pipefail
case "${1:-help}" in
  info)
    cat .file_server_info.txt 2>/dev/null || echo "文件服务器未运行 (file server not running)"
    ;;
  events)
    tail -n 20 .hermes_file_events.jsonl 2>/dev/null || echo "暂无事件 (no events yet)"
    ;;
  recent)
    ls -lt --time-style=+'%Y-%m-%d %H:%M' | head -n 20
    ;;
  size)
    du -sh . 2>/dev/null || du -sh .
    ;;
  *)
    echo "用法/Usage: ./bridge.sh {info|events|recent|size}"
    ;;
esac
