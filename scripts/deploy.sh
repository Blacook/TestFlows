#!/bin/bash

# Knowledge Base既存前提のBedrock Flows専用デプロイスクリプト
# 環境変数ベースの設定管理

set -e

# 設定ファイルの読み込み
if [ -f ".env" ]; then
    echo "📋 .env ファイルから設定を読み込み中..."
    set -a
    source .env
    set +a
else
    echo "⚠️  .env ファイルが見つかりません。"
    echo "📝 .env.example をコピーして .env を作成し、環境に合わせて設定してください。"
    echo ""
    echo "cp .env.example .env"
    echo "# .env ファイルを編集してから再実行してください"
    exit 1
fi

# 必須環境変数のチェック
required_vars=("AWS_REGION" "AWS_ACCOUNT_ID" "KNOWLEDGE_BASE_ID" "EXECUTION_ROLE_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ 必須環境変数 $var が設定されていません。"
        echo "📝 .env ファイルを確認してください。"
        exit 1
    fi
done

echo "🚀 Bedrock専用テストログ分析フローのデプロイを開始します..."
echo "📝 設定情報:"
echo "  - AWS Region: $AWS_REGION"
echo "  - Account ID: $AWS_ACCOUNT_ID"
echo "  - Knowledge Base ID: $KNOWLEDGE_BASE_ID"
echo "  - Flow Name: $FLOW_NAME"
echo "  - Execution Role: $EXECUTION_ROLE_NAME"

# Knowledge Base の存在確認
echo "🔍 Knowledge Base の存在確認中..."
if ! aws bedrock-agent get-knowledge-base --knowledge-base-id "$KNOWLEDGE_BASE_ID" >/dev/null 2>&1; then
    echo "❌ Knowledge Base ID '$KNOWLEDGE_BASE_ID' が見つかりません。"
    echo "📋 利用可能なKnowledge Base一覧:"
    aws bedrock-agent list-knowledge-bases --query 'knowledgeBaseSummaries[*].[knowledgeBaseId,name,status]' --output table
    exit 1
fi

# 1. ポリシーファイルの生成
echo "📝 ポリシーファイルを生成中..."
[ -d "generated-policies" ] && rm -rf "generated-policies"
python3 scripts/generate-template.py config/iam-policies generated-policies

# 2. IAMロールの作成
echo "🔐 IAMロールを作成中..."
if aws iam get-role --role-name "$EXECUTION_ROLE_NAME" >/dev/null 2>&1; then
    echo "⚠️  ロール '$EXECUTION_ROLE_NAME' は既に存在します"
    echo "⚠️  既存のロールを使用しますが、ポリシーが上書きされる可能性があります"
    read -p "続行しますか？ (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        echo "❌ デプロイを中止しました"
        exit 1
    fi
else
    aws iam create-role \
      --role-name "$EXECUTION_ROLE_NAME" \
      --assume-role-policy-document file://generated-policies/trust-policy.json \
      --query 'Role.Arn' \
      --output text
    echo "✅ IAMロール '$EXECUTION_ROLE_NAME' を作成しました"
fi

# 3. IAMポリシーのアタッチ
echo "🔒 IAMポリシーをアタッチ中..."
for policy_file in generated-policies/*-policy.json; do
    [ -f "$policy_file" ] || continue
    [ "$(basename "$policy_file")" = "trust-policy.json" ] && continue
    
    policy_name="${EXECUTION_ROLE_NAME}-$(basename "$policy_file" .json)"
    
    if aws iam get-role-policy --role-name "$EXECUTION_ROLE_NAME" --policy-name "$policy_name" >/dev/null 2>&1; then
        echo "⚠️  ポリシー '$policy_name' は既に存在します（上書きします）"
    fi
    
    aws iam put-role-policy \
      --role-name "$EXECUTION_ROLE_NAME" \
      --policy-name "$policy_name" \
      --policy-document "file://$policy_file"
    echo "✅ $policy_name をアタッチしました"
done

echo "⏳ IAMロールの伝播を待機中（30秒）..."
sleep 30

# 4. フロー定義ファイルの生成
echo "📝 フロー定義ファイルを生成中..."
python3 scripts/generate-template.py config/flow-template.json flow-definition.json

# 5. Bedrock Flowの作成
echo "🔄 Bedrock Flowを作成中..."
FLOW_ID=$(aws bedrock-agent create-flow \
  --cli-input-json file://flow-definition.json \
  --query 'id' --output text)

if [ $? -eq 0 ]; then
    echo "✅ フローが作成されました。Flow ID: $FLOW_ID"
else
    echo "❌ フローの作成に失敗しました。"
    exit 1
fi

# 6. フローの準備
echo "🔧 フローを準備中..."
aws bedrock-agent prepare-flow --flow-identifier "$FLOW_ID"

# 7. 環境変数ファイルの更新
echo "📄 環境変数ファイルを更新中..."
echo "" >> .env
echo "# デプロイ結果" >> .env
echo "FLOW_ID=$FLOW_ID" >> .env


echo "🎉 Bedrock専用フローのデプロイが完了しました！"
echo ""
echo "🔗 作成されたリソース:"
echo "- Flow ID: $FLOW_ID"
echo "- Knowledge Base ID: $KNOWLEDGE_BASE_ID"
echo "- IAM Role: $EXECUTION_ROLE_NAME"
echo "- Flow Definition: flow-definition.json"
echo ""
echo "💡 テスト実行方法:"
echo "1. 生成されたテストファイルでの実行:"
echo "   aws bedrock-agent invoke-flow --flow-identifier $FLOW_ID --inputs file://test-execution-generated.json"
echo ""
echo "2. 簡単なテスト実行:"
echo "   aws bedrock-agent invoke-flow --flow-identifier $FLOW_ID --inputs '{\"log_content\": \"2024-10-03 ERROR [Test] NullPointerException occurred\"}'"
echo ""
echo "3. AWS コンソールでのテスト:"
echo "   https://console.aws.amazon.com/bedrock/home?region=$AWS_REGION#/flows/$FLOW_ID"
echo ""
echo "📝 設定情報は .env ファイルに保存されました。"