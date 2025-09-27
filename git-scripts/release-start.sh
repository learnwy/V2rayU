#!/bin/bash

# 创建发布分支脚本

set -e

if [ $# -lt 1 ]; then
  echo "用法: ./git-scripts/release-start.sh <版本号>"
  exit 1
fi

VERSION=$1

# 确保我们有最新的开发分支代码
git checkout dev
git pull origin dev

# 创建新的发布分支
BRANCH_NAME="release/${VERSION}"
echo "创建发布分支: ${BRANCH_NAME}"
git checkout -b ${BRANCH_NAME}

echo "发布分支已创建，现在您可以准备发布了"
echo "完成后，运行 ./git-scripts/release-finish.sh ${VERSION} 来完成发布"