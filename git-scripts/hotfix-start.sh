#!/bin/bash

# 创建热修复分支脚本

set -e

if [ $# -lt 1 ]; then
  echo "用法: ./git-scripts/hotfix-start.sh <版本号>"
  exit 1
fi

VERSION=$1

# 确保我们有最新的开发分支代码
git checkout dev
git pull origin dev

# 创建新的热修复分支
BRANCH_NAME="hotfix/${VERSION}"
echo "创建热修复分支: ${BRANCH_NAME}"
git checkout -b ${BRANCH_NAME}

echo "热修复分支已创建，现在您可以开始修复了"
echo "完成后，运行 ./git-scripts/hotfix-finish.sh ${VERSION} 来准备PR"