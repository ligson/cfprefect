#!/usr/bin/env bash
set -euo pipefail

if [[ -n "$(git status --short)" ]]; then
  echo "工作区有未提交改动，请先提交或清理后再发版。" >&2
  exit 1
fi

current=$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)(\+.*)?$/\1/p' pubspec.yaml)
if [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "无法读取 pubspec.yaml 中的三段式版本号。" >&2
  exit 1
fi

IFS=. read -r major minor patch <<< "$current"
next="${major}.${minor}.$((patch + 1))"
tag="v${next}"

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag $tag 已存在。" >&2
  exit 1
fi

if [[ "${1:-}" == "--version" ]]; then
  next="${2:?请提供版本号，例如 1.0.1}"
  [[ "$next" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "版本号必须是 X.Y.Z。" >&2; exit 1; }
  tag="v${next}"
fi

sed -i.bak -E "s/^version: [0-9]+\.[0-9]+\.[0-9]+/version: ${next}/" pubspec.yaml
rm -f pubspec.yaml.bak

git add pubspec.yaml
git commit -m "Release ${tag}"
git tag -a "$tag" -m "Release ${tag}"
git push origin HEAD:main
git push origin "$tag"

echo "已创建并推送 ${tag}。GitHub Actions 将仅针对该 Tag 构建并发布 Release。"
