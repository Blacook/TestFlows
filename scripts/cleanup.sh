#!/bin/bash

# リソースクリーンアップスクリプト

set -e

# 設定ファイルの読み込み
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ .env ファイルが見つかりません。"
    exit 1
fi

echo "🧹 Bedrock Flowsリソースのクリーンアップを開始します..."
echo ""
echo "⚠️  以下のリソースが削除されます:"
echo "  - Bedrock Flow: $FLOW_ID (存在する場合)"
echo "  - IAM Role: $EXECUTION_ROLE_NAME"
echo "  - 生成されたファイル"
echo ""

read -p "本当に削除しますか？ (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "❌ クリーンアップを中止しました。"
    exit 1
fi

# Bedrock Flow の削除
if [ ! -z "$FLOW_ID" ]; then
    echo "🔄 Bedrock Flow を削除中..."
    if aws bedrock-agent delete-flow --flow-identifier "$FLOW_ID" 2>/dev/null; then
        echo "  ✅ Flow '$FLOW_ID' を削除しました"
    else
        echo "  ⚠️  Flow '$FLOW_ID' の削除に失敗しました（既に削除済みの可能性）"
    fi
else
    echo "  ℹ️  削除対象のFlow IDが見つかりません"
fi

# IAM Role の削除
echo "🔐 IAM Role を削除中..."

# ロールポリシーの削除
if aws iam delete-role-policy --role-name "$EXECUTION_ROLE_NAME" --policy-name "$EXECUTION_ROLE_POLICY_NAME" 2>/dev/null; then
    echo "  ✅ Role Policy '$EXECUTION_ROLE_POLICY_NAME' を削除しました"
else
    echo "  ⚠️  Role Policy の削除に失敗しました（既に削除済みの可能性）"
fi

# ロールの削除
if aws iam delete-role --role-name "$EXECUTION_ROLE_NAME" 2>/dev/null; then
    echo "  ✅ IAM Role '$EXECUTION_ROLE_NAME' を削除しました"
else
    echo "  ⚠️  IAM Role の削除に失敗しました（既に削除済みの可能性）"
fi

# 生成されたファイルの削除
echo "📄 生成されたファイルを削除中..."
files_to_delete=(
    "flow-definition.json"
    "test-execution-generated.json"
    "*.bak"
)

for file_pattern in "${files_to_delete[@]}"; do
    if ls $file_pattern 1> /dev/null 2>&1; then
        rm -f $file_pattern
        echo "  ✅ $file_pattern を削除しました"
    fi
done

# .env ファイルからデプロイ結果の削除
echo "📝 .env ファイルからデプロイ結果を削除中..."
if [ -f ".env" ]; then
    # FLOW_ID行を削除
    sed -i.bak '/^FLOW_ID=/d' .env
    sed -i.bak '/^# デプロイ結果/d' .env
    rm -f .env.bak
    echo "  ✅ .env ファイルを更新しました"
fi

echo ""
echo "🎉 クリーンアップが完了しました！"
echo ""
echo "💡 再デプロイする場合は以下のコマンドを実行してください:"
echo "   ./scripts/validate-config.sh"
echo "   ./scripts/deploy.sh"