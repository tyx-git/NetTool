# NetTool - Linux网络诊断与配置工具

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-green.svg)](#)
[![Language](https://img.shields.io/badge/language-Bash-yellow.svg)](#)

## 简介

NetTool 是一个功能强大的 Linux 网络诊断和配置工具，专为系统管理员和开发人员设计。它提供了一站式的网络问题检测、诊断和修复功能，帮助用户快速识别和解决各种网络相关问题。

通过直观的菜单界面和丰富的命令行选项，NetTool 可以帮助您：
- 检测网络接口状态和配置问题
- 优化 DNS 解析性能
- 配置 Docker 国内镜像源加速
- 诊断网络连通性和性能问题
- 修复常见的网络配置错误

## 核心功能

### 🔍 检测类功能
- **全面系统检测** - 一键检测网络接口、DNS配置、网络连通性等多项指标
- **网络接口状态检查** - 自动检测系统中的所有网络接口状态
- **网络信息查看** - 显示详细的网络接口信息、路由表、DNS配置
- **Docker镜像源检测** - 检测Docker是否配置了国内镜像源

### 🛠️ 修复类功能
- **DNS配置修复** - 自动修复DNS配置问题，支持多种预设DNS服务器
- **Docker镜像源配置** - 一键配置国内镜像源提高Docker拉取速度
- **网络工具安装** - 自动检测并安装缺失的网络工具
- **网络接口修复** - 修复网络接口状态问题

### ⚙️ 配置类功能
- **临时DNS更新** - 快速更新临时DNS解析地址
- **永久DNS更新** - 根据不同Linux发行版永久更新DNS配置
- **GPG密钥配置** - 完整的GPG密钥管理功能

### 📊 诊断类功能
- **网络连通性检查** - 检查指定目标地址的网络连通性
- **路由跟踪** - 使用traceroute进行路由路径跟踪
- **端口连通性测试** - 测试指定主机和端口的连通性

## 安装与使用

### 系统要求
- Linux系统（支持Ubuntu、Debian、CentOS、RHEL、Rocky Linux、AlmaLinux等）
- Root权限
- Bash 4.0或更高版本

### 安装步骤
```bash
# 克隆仓库
git clone https://github.com/tyx-git/NetTool.git
cd NetTool

# 添加执行权限
chmod +x NetTool.sh

# 运行脚本
sudo ./NetTool.sh
```

### 使用方法

#### 交互式使用
```bash
sudo ./NetTool.sh
```

#### 命令行直接调用
```bash
# 全面系统检测
sudo ./NetTool.sh --comprehensive-check

# 修复DNS配置
sudo ./NetTool.sh --repair-dns

# 配置Docker国内镜像源
sudo ./NetTool.sh --repair-docker

# 安装缺失的网络工具
sudo ./NetTool.sh --install-tools

# 静默模式
sudo ./NetTool.sh -s --comprehensive-check

# JSON格式输出
sudo ./NetTool.sh -j --comprehensive-check
```

## 功能详解

### 全面系统检测
提供一键式网络健康检查，包括：
- 网络接口状态检测
- DNS配置验证
- 网络连通性测试
- Docker服务状态检查
- 网络工具可用性检查
- 防火墙状态检测

检测结果采用彩色输出，绿色表示正常，红色表示异常，便于快速识别问题。

### Docker镜像源优化
自动检测Docker是否配置了国内镜像源，支持一键配置以下国内镜像源：
- 网易云镜像源 (hub-mirror.c.163.com)
- 百度云镜像源 (mirror.baidubce.com)
- 中科大镜像源 (docker.mirrors.ustc.edu.cn)

### 网络接口管理
- 自动识别系统中所有网络接口
- 支持检查指定接口状态
- 提供接口修复功能
- 显示详细接口信息

### DNS配置管理
- 支持多种预设DNS服务器（谷歌、腾讯、阿里、百度、Cloudflare、OpenDNS）
- 临时和永久DNS配置选项
- DNS服务器有效性验证
- 配置文件自动备份

## 支持的Linux发行版

- **Debian/Ubuntu系列**：Ubuntu 18.04+、Debian 10+
- **RHEL/CentOS系列**：CentOS 7+、RHEL 7+、Rocky Linux、AlmaLinux
- **其他发行版**：Fedora、Arch Linux（部分功能）

## 关键词

`linux` `network` `networking` `bash` `shell` `network-diagnosis` `dns` `docker` `network-tools` `system-administration` `devops` `network-troubleshooting` `network-configuration` `gpg` `network-monitoring` `linux-networking` `network-security` `network-performance`

## 贡献

欢迎提交Issue和Pull Request来改进NetTool。请确保：

1. 遵循现有的代码风格
2. 添加适当的注释和文档
3. 测试您的更改
4. 遵守MIT许可证

## 许可证

本项目采用MIT许可证，详情请见[LICENSE](LICENSE)文件。

## 免责声明

本工具仅供学习和参考使用，请在使用前确保了解其功能和影响。作者不对因使用本工具而造成的任何损失负责。
