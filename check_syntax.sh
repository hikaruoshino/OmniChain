#!/usr/bin/env bash
# =============================================================================
# check_syntax.sh : Lua 構文チェック (luac -p)
#   使い方: ./check_syntax.sh [ファイル...]
#   引数なしの場合は OmniChain.lua を検査する (CHECK_ALL=1 で *.lua すべて)
#   使用する Lua は環境変数 LUAC で指定可能 (例: LUAC=/c/lua/luac5.1.exe)
# =============================================================================

cd "$(dirname "$0")" || exit 2

# 使用する構文チェッカーを決定 (Windower 4 に近い Lua 5.1 系を優先)
mode=""
if [ -n "$LUAC" ]; then
    checker="$LUAC"; mode="luac"
else
    for c in luac5.1 luac51 luac; do
        if command -v "$c" >/dev/null 2>&1; then checker="$c"; mode="luac"; break; fi
    done
    if [ -z "$mode" ] && [ -x "$HOME/lua51/luac5.1.exe" ]; then
        checker="$HOME/lua51/luac5.1.exe"; mode="luac"
    fi
    if [ -z "$mode" ] && command -v luajit >/dev/null 2>&1; then
        checker="luajit"; mode="luajit"
    fi
fi

if [ -z "$mode" ]; then
    echo "エラー: luac / luajit が見つかりません。PATH に追加するか LUAC=パス で指定してください。" >&2
    exit 2
fi

if [ $# -gt 0 ]; then
    files=("$@")
elif [ "$CHECK_ALL" = "1" ]; then
    shopt -s nullglob
    files=(*.lua)
else
    files=(OmniChain.lua)
fi

if [ ${#files[@]} -eq 0 ]; then
    echo "検査対象の .lua ファイルがありません。" >&2
    exit 2
fi

echo "使用チェッカー: $checker"
fail=0
for f in "${files[@]}"; do
    if [ "$mode" = "luajit" ]; then
        out=$("$checker" -b "$f" /dev/null 2>&1)
    else
        out=$("$checker" -p "$f" 2>&1)
    fi
    if [ $? -eq 0 ]; then
        echo "OK    $f"
    else
        echo "ERROR $f"
        # "luac: file:line: message" → "file:line: message" (VS Code の problemMatcher 用)
        echo "$out" | sed -E 's/^.*(luac|luajit)[^ :]*(\.exe)?: //'
        fail=1
    fi
done

exit $fail
