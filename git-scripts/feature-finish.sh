#!/bin/bash

# 完成功能分支脚本

set -e

if [ $# -lt 1 ]; then
  echo "用法: ./git-scripts/feature-finish.sh <功能名称>"
  exit 1
fi

FEATURE_NAME=$1
BRANCH_NAME="feature/${FEATURE_NAME}"

# 确保我们在正确的分支上
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  echo "切换到功能分支: ${BRANCH_NAME}"
  git checkout ${BRANCH_NAME}
fi

# 获取最新的开发分支代码并变基
echo "获取最新的开发分支代码..."
git fetch origin dev
echo "变基到最新的开发分支..."
git rebase origin/dev

echo "推送功能分支到远程仓库..."
git push origin ${BRANCH_NAME} --force-with-lease

echo "功能分支已准备好，请前往GitHub创建Pull Request:"
echo "https://github.com/learnwy/V2rayU/compare/dev...${BRANCH_NAME}"