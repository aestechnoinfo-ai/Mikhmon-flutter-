# OpenCode 文件桥接 / File Bridge

本项目目录（/root/mikhmon）与手机、局域网实时互通。在这里创建或修改的文件，
手机应用和电脑立刻可见。
This project directory (/root/mikhmon) is shared live with the phone and LAN.

## 目录 / Folders
- inbox/：手机分享/导入的文件会出现在这里（files shared from other apps land here）
- links/：已关联的 Android 文件夹同步到这里（linked Android folder syncs）
- BRIDGE.md：本说明（this guide）

## Agent 常用命令 / Skill commands
```bash
python3 "$OPENCODE_CONFIG_HOME/skills/android-device/android_device.py" file-list --path .
python3 "$OPENCODE_CONFIG_HOME/skills/android-device/android_device.py" file-events
python3 "$OPENCODE_CONFIG_HOME/skills/android-device/android_device.py" file-capture --target-dir inbox
```
（file-pick / file-save / file-share 详见 skill 文档）

## 手机/电脑入口 / Entry points
- 手机：安卓菜单 → 文件管理 / 双向 / 文件设置
- 电脑：局域网/WebDAV `http://<手机IP>:8123/`（用户名 opencode，
  密码见手机「文件设置」）

## 文件事件 / File events
tail -f .hermes_file_events.jsonl
