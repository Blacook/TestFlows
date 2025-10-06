#!/bin/bash

# リソースクリーンアップスクリプト

set -e

# 設定ファイルの読み込み
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
else
    echo "❌ .env ファイルが見つかりません。"
    exit 1
fi

echo "🧹 Bedrock Flowsリソースのクリーンアップを開始します..."
echo ""
echo "⚠️  以下のリソースが削除されます:"

if [ -n "$FLOW_ID" ]; then
    echo "  - Bedrock Flow: $FLOW_ID"
else
    echo "  - Bedrock Flow: (設定されていません)"
fi

if [ -n "$EXECUTION_ROLE_NAME" ]; then
    echo "  - IAM Role: $EXECUTION_ROLE_NAME"
    if [ -d "generated-policies" ]; then
        echo "  - IAM Policies:"
        for policy_file in generated-policies/*-policy.json; do
            [ -f "$policy_file" ] || continue
            [ "$(basename "$policy_file")" = "trust-policy.json" ] && continue
            echo "      - ${EXECUTION_ROLE_NAME}-$(basename "$policy_file" .json)"
        done
    fi
else
    echo "  - IAM Role: (設定されていません)"
fi

echo "  - 生成されたファイル (flow-definition.json, test-execution-generated.json, generated-policies/)"
echo ""
echo "⚠️  注意: このスクリプトは.envで指定されたリソースのみを削除します。"
echo "⚠️  Knowledge Baseは削除されません。"
echo ""

read -p "本当に削除しますか？ (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "❌ クリーンアップを中止しました。"
    exit 1
fi

# Bedrock Flow の削除
if [ -n "$FLOW_ID" ]; then
    echo "🔄 Bedrock Flow を削除中..."
    
    if aws bedrock-agent get-flow --flow-identifier "$FLOW_ID" >/dev/null 2>&1; then
        FLOW_INFO=$(aws bedrock-agent get-flow --flow-identifier "$FLOW_ID" --query '[name,status]' --output text 2>/dev/null)
        echo "  ℹ️  Flow情報: $FLOW_INFO"
        
        if aws bedrock-agent delete-flow --flow-identifier "$FLOW_ID" 2>/dev/null; then
            echo "  ✅ Flow '$FLOW_ID' を削除しました"
        else
            echo "  ⚠️  Flow '$FLOW_ID' の削除に失敗しました"
        fi
    else
        echo "  ⚠️  Flow '$FLOW_ID' が見つかりません（既に削除済みの可能性）"
    fi
else
    echo "  ℹ️  削除対象のFlow IDが設定されていません"
fi

# IAM Role の削除
echo "🔐 IAM Role を削除中..."

# 分割されたIAMポリシーの削除
if [ -n "$EXECUTION_ROLE_NAME" ]; then
    if aws iam get-role --role-name "$EXECUTION_ROLE_NAME" >/dev/null 2>&1; then
        echo "ℹ️  IAM Role '$EXECUTION_ROLE_NAME' が存在します"
        
        if [ -d "generated-policies" ]; then
            for policy_file in generated-policies/*-policy.json; do
                [ -f "$policy_file" ] || continue
                [ "$(basename "$policy_file")" = "trust-policy.json" ] && continue
                policy_name="${EXECUTION_ROLE_NAME}-$(basename "$policy_file" .json)"
                
                if aws iam get-role-policy --role-name "$EXECUTION_ROLE_NAME" --policy-name "$policy_name" >/dev/null 2>&1; then
                    if aws iam delete-role-policy --role-name "$EXECUTION_ROLE_NAME" --policy-name "$policy_name" 2>/dev/null; then
                        echo "  ✅ Role Policy '$policy_name' を削除しました"
                    else
                        echo "  ⚠️  Role Policy '$policy_name' の削除に失敗しました"
                    fi
                else
                    echo "  ℹ️  Role Policy '$policy_name' が見つかりません（スキップ）"
                fi
            done
        fi
        
        # ロールに他のポリシーがアタッチされていないか確認
        OTHER_POLICIES=$(aws iam list-role-policies --role-name "$EXECUTION_ROLE_NAME" --query 'PolicyNames[?!starts_with(@, `'"$EXECUTION_ROLE_NAME"'`)]' --output text 2>/dev/null)
        if [ -n "$OTHER_POLICIES" ]; then
            echo "  ⚠️  ロールに他のポリシーがアタッチされています: $OTHER_POLICIES"
            echo "  ⚠️  ロールの削除をスキップします。手動で削除してください。"
        else
            if aws iam delete-role --role-name "$EXECUTION_ROLE_NAME" 2>/dev/null; then
                echo "  ✅ IAM Role '$EXECUTION_ROLE_NAME' を削除しました"
            else
                echo "  ⚠️  IAM Role の削除に失敗しました"
            fi
        fi
    else
        echo "  ℹ️  IAM Role '$EXECUTION_ROLE_NAME' が見つかりません（既に削除済みの可能性）"
    fi
else
    echo "  ⚠️  EXECUTION_ROLE_NAME が設定されていません"
fi

# 生成されたファイルの削除
echo "📄 生成されたファイルを削除中..."
files_to_delete=(
    "flow-definition.json"
    "test-execution-generated.json"
    "*.bak"
)

for file_pattern in "${files_to_delete[@]}"; do
    for file in $file_pattern; do
        [ -f "$file" ] || continue
        rm -f "$file"
        echo "  ✅ $file を削除しました"
    done
done

# generated-policiesディレクトリの削除
if [ -d "generated-policies" ]; then
    rm -rf "generated-policies"
    echo "  ✅ generated-policies/ を削除しました"
fi

# .env ファイルからデプロイ結果の削除
echo "📝 .env ファイルからデプロイ結果を削除中..."
if [ -f ".env" ]; then
    grep -v '^FLOW_ID=' .env | grep -v '^# デプロイ結果' > .env.tmp && mv .env.tmp .env
    echo "  ✅ .env ファイルを更新しました"
fi

echo ""
echo "🎉 クリーンアップが完了しました！"
echo ""
echo "💡 再デプロイする場合は以下のコマンドを実行してください:"
echo "   ./scripts/deploy.sh"