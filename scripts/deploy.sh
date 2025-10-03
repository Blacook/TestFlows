#!/bin/bash

# Knowledge Base既存前提のBedrock Flows専用デプロイスクリプト
# 環境変数ベースの設定管理

set -e

# 設定ファイルの読み込み
if [ -f ".env" ]; then
    echo "📋 .env ファイルから設定を読み込み中..."
    export $(grep -v '^#' .env | xargs)
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

# 1. IAMロールの作成
echo "🔐 IAMロールを作成中..."
aws iam create-role \
  --role-name "$EXECUTION_ROLE_NAME" \
  --assume-role-policy-document file://config/iam-policies.json \
  --query 'Role.Arn' \
  --output text 2>/dev/null || echo "ロール '$EXECUTION_ROLE_NAME' は既に存在します"

# IAMポリシーのアタッチ
echo "🔒 IAMポリシーをアタッチ中..."
aws iam put-role-policy \
  --role-name "$EXECUTION_ROLE_NAME" \
  --policy-name "$EXECUTION_ROLE_POLICY_NAME" \
  --policy-document file://config/iam-policies.json

echo "⏳ IAMロールの伝播を待機中（30秒）..."
sleep 30

# 2. フロー定義ファイルの生成
echo "📝 フロー定義ファイルを生成中..."
envsubst < config/flow-template.json > flow-definition.json

# 3. Bedrock Flowの作成
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

# 4. フローの準備
echo "🔧 フローを準備中..."
aws bedrock-agent prepare-flow --flow-identifier "$FLOW_ID"

# 5. 環境変数ファイルの更新
echo "📄 環境変数ファイルを更新中..."
echo "" >> .env
echo "# デプロイ結果" >> .env
echo "FLOW_ID=$FLOW_ID" >> .env

# 6. テスト実行用ファイルの生成
echo "📋 テスト実行ファイルを生成中..."
cat > test-execution-generated.json << EOF
{
  "flowId": "$FLOW_ID",
  "inputs": {
    "log_content": "$(cat test-data/sample-test-log.log | sed 's/"/\\"/g' | tr '\n' '\\n')"
  }
}
EOF

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