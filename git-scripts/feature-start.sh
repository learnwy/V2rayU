#!/bin/bash

# 创建新功能分支脚本

set -e

if [ $# -lt 1 ]; then
  echo "用法: ./git-scripts/feature-start.sh <功能名称>"
  exit 1
fi

FEATURE_NAME=$1

# 确保我们有最新的开发分支代码
git checkout dev
git pull origin dev

# 创建新的功能分支
BRANCH_NAME="feature/${FEATURE_NAME}"
echo "创建新功能分支: ${BRANCH_NAME}"
git checkout -b ${BRANCH_NAME}

echo "功能分支已创建，现在您可以开始开发了"
echo "完成后，运行 ./git-scripts/feature-finish.sh ${FEATURE_NAME} 来准备PR"