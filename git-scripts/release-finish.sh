#!/bin/bash

# 完成发布分支脚本

set -e

if [ $# -lt 1 ]; then
  echo "用法: ./git-scripts/release-finish.sh <版本号>"
  exit 1
fi

VERSION=$1
BRANCH_NAME="release/${VERSION}"

# 确保我们在正确的分支上
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH_NAME" ]; then
  echo "切换到发布分支: ${BRANCH_NAME}"
  git checkout ${BRANCH_NAME}
fi

# 获取最新的开发分支代码并变基
echo "获取最新的开发分支代码..."
git fetch origin dev
echo "变基到最新的开发分支..."
git rebase origin/dev

echo "推送发布分支到远程仓库..."
git push origin ${BRANCH_NAME} --force-with-lease

echo "创建版本标签..."
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"

echo "发布分支已准备好，请前往GitHub创建Pull Request:"
echo "https://github.com/learnwy/V2rayU/compare/dev...${BRANCH_NAME}"
echo "并创建新的Release: https://github.com/learnwy/V2rayU/releases/new"