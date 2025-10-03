#!/bin/bash

# 設定ファイルの検証スクリプト

set -e

echo "🔍 設定ファイルの検証を開始します..."

# .env ファイルの存在確認
if [ ! -f ".env" ]; then
    echo "❌ .env ファイルが見つかりません。"
    echo "📝 .env.example をコピーして設定してください:"
    echo "   cp .env.example .env"
    exit 1
fi

# 環境変数の読み込み
export $(grep -v '^#' .env | xargs)

# 必須環境変数のチェック
echo "📋 必須環境変数をチェック中..."
required_vars=(
    "AWS_REGION"
    "AWS_ACCOUNT_ID" 
    "FLOW_NAME"
    "KNOWLEDGE_BASE_ID"
    "EXECUTION_ROLE_NAME"
    "MODEL_ID_ANALYZER"
    "MODEL_ID_EXTRACTOR"
    "MODEL_ID_QUERY_GENERATOR"
    "MODEL_ID_REPORT"
    "MODEL_ID_KNOWLEDGE_BASE"
    "MAX_TOKENS_ANALYZER"
    "MAX_TOKENS_EXTRACTOR"
    "MAX_TOKENS_REPORT"
    "TEMPERATURE"
    "TOP_P"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    else
        echo "  ✅ $var: ${!var}"
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo ""
    echo "❌ 以下の必須環境変数が設定されていません:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "📝 .env ファイルを確認して設定してください。"
    exit 1
fi

# AWS認証情報の確認
echo ""
echo "🔐 AWS認証情報をチェック中..."
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ AWS認証情報が設定されていません。"
    echo "📝 以下のいずれかの方法で認証情報を設定してください:"
    echo "  - aws configure"
    echo "  - AWS_ACCESS_KEY_ID と AWS_SECRET_ACCESS_KEY 環境変数"
    echo "  - IAMロール（EC2/ECS等）"
    exit 1
fi

CURRENT_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
if [ "$CURRENT_ACCOUNT" != "$AWS_ACCOUNT_ID" ]; then
    echo "⚠️  現在のAWSアカウント ($CURRENT_ACCOUNT) と設定されたアカウントID ($AWS_ACCOUNT_ID) が異なります。"
    read -p "続行しますか？ (y/N): " confirm
    if [[ $confirm != [yY] ]]; then
        exit 1
    fi
fi

echo "  ✅ AWS認証情報: OK"
echo "  ✅ アカウントID: $CURRENT_ACCOUNT"

# Knowledge Base の存在確認
echo ""
echo "🧠 Knowledge Base の存在確認中..."
if aws bedrock-agent get-knowledge-base --knowledge-base-id "$KNOWLEDGE_BASE_ID" >/dev/null 2>&1; then
    KB_INFO=$(aws bedrock-agent get-knowledge-base --knowledge-base-id "$KNOWLEDGE_BASE_ID" --query '[name,status]' --output text)
    echo "  ✅ Knowledge Base: $KB_INFO"
else
    echo "❌ Knowledge Base ID '$KNOWLEDGE_BASE_ID' が見つかりません。"
    echo ""
    echo "📋 利用可能なKnowledge Base一覧:"
    aws bedrock-agent list-knowledge-bases --query 'knowledgeBaseSummaries[*].[knowledgeBaseId,name,status]' --output table
    exit 1
fi

# Bedrock モデルの確認
echo ""
echo "🤖 Bedrock モデルの確認中..."
if aws bedrock list-foundation-models --query "modelSummaries[?modelId=='$BEDROCK_MODEL_ID']" --output text | grep -q "$BEDROCK_MODEL_ID"; then
    echo "  ✅ Bedrock Model: $BEDROCK_MODEL_ID"
else
    echo "⚠️  Bedrock Model '$BEDROCK_MODEL_ID' の確認ができませんでした。"
    echo "📋 利用可能なモデル一覧を確認してください:"
    echo "   aws bedrock list-foundation-models --query 'modelSummaries[*].[modelId,modelName]' --output table"
fi

# 設定ファイルの構文チェック
echo ""
echo "📄 設定ファイルの構文チェック中..."

# JSON テンプレートの検証
if ! envsubst < config/flow-template.json | jq . >/dev/null 2>&1; then
    echo "❌ フローテンプレートのJSON構文エラーがあります。"
    exit 1
fi
echo "  ✅ フローテンプレート: OK"

# IAM ポリシーの検証
if ! jq . config/iam-policies.json >/dev/null 2>&1; then
    echo "❌ IAMポリシーのJSON構文エラーがあります。"
    exit 1
fi
echo "  ✅ IAMポリシー: OK"

echo ""
echo "🎉 すべての設定検証が完了しました！"
echo "💡 デプロイを実行する場合は以下のコマンドを実行してください:"
echo "   ./scripts/deploy.sh"