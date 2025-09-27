# Git 工作流脚本

这个目录包含了一系列Git工作流脚本，用于简化V2rayU项目的开发流程。

## 设置说明

已将您的fork仓库 `learnwy/V2rayU` 设置为默认远程仓库（origin），原始仓库 `yanue/V2rayU` 设置为上游仓库（upstream）。

## 可用脚本

### 功能开发

- `feature-start.sh` - 创建新功能分支
- `feature-finish.sh` - 完成功能开发并准备PR

### 热修复

- `hotfix-start.sh` - 创建热修复分支
- `hotfix-finish.sh` - 完成热修复并准备PR

### 版本发布

- `release-start.sh` - 创建发布分支
- `release-finish.sh` - 完成发布并创建标签

### 同步上游

- `sync-upstream.sh` - 从原始仓库同步最新代码

## 使用示例

### 开发新功能

```bash
# 开始新功能开发
./git-scripts/feature-start.sh 新功能名称

# 完成功能开发
./git-scripts/feature-finish.sh 新功能名称
```

### 修复紧急问题

```bash
# 开始热修复
./git-scripts/hotfix-start.sh 1.2.1

# 完成热修复
./git-scripts/hotfix-finish.sh 1.2.1
```

### 发布新版本

```bash
# 开始发布
./git-scripts/release-start.sh 1.3.0

# 完成发布
./git-scripts/release-finish.sh 1.3.0
```

### 同步上游代码

```bash
# 同步上游仓库代码
./sync-upstream.sh
```