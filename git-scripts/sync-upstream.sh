#!/bin/bash

# 同步上游仓库脚本
# 用于从yanue/V2rayU同步代码到learnwy/V2rayU

set -e

echo "===== 开始同步上游仓库 ====="

# 确保我们有最新的上游代码
echo "1. 获取上游最新代码..."
git fetch upstream

# 获取当前分支
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
echo "当前分支: $CURRENT_BRANCH"

# 如果当前不在dev分支上，提示切换
if [ "$CURRENT_BRANCH" != "dev" ]; then
  echo "警告: 你当前不在dev分支上。建议切换到dev分支进行同步。"
  echo "你可以运行: git checkout dev"
  echo "然后再次运行此脚本。"
  echo "是否继续在当前分支($CURRENT_BRANCH)上同步? (y/n)"
  read answer
  if [ "$answer" != "y" ]; then
    echo "同步已取消。"
    exit 1
  fi
fi

# 确保本地工作区干净
if [[ -n $(git status --porcelain) ]]; then
  echo "错误: 工作区不干净，请先提交或暂存您的更改"
  exit 1
fi

echo "2. 从上游rebase当前分支..."
git rebase upstream/$CURRENT_BRANCH

echo "3. 同步完成!"
echo "   如果有冲突，请解决后运行 'git rebase --continue'"
echo "   完成后，可以推送到您的fork: 'git push origin $CURRENT_BRANCH --force-with-lease'"

echo "===== 同步脚本执行完毕 ====="