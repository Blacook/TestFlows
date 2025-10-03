# テスト実行ログRAG分析フロー（Bedrock専用構成）

## 概要
自動テスト実行後に出力される大量のログファイルをAIが分析・要約し、根本原因の推定や特に注目すべき失敗テストをまとめたサマリーレポートを生成するBedrock Flowsです。

**特徴**: 
- LambdaやDBを使わず、Bedrock ModelsとKnowledge Basesのみで構成
- 環境変数ベースの簡単な設定管理
- ワンコマンドでデプロイ可能

## 前提条件
- ✅ AWS Bedrock Knowledge Baseが既に作成済み
- ✅ Knowledge Baseにエラーパターンや過去事例データが登録済み
- ✅ 適切なAWS認証情報が設定済み

## アーキテクチャ

```
入力ログ → LogAnalyzer → SeverityClassifier → 重要度判定
              ↓
         ErrorExtractor → KnowledgeBaseSearch → ReportGenerator → 最終レポート
```

### ノード構成
1. **InputNode**: ログ内容の受け取り
2. **LogAnalyzer** (Prompt): ログをJSON形式で構造化分析
3. **SeverityClassifier** (Condition): エラー重要度の自動判定（Critical/High/Medium/Low）
4. **ErrorExtractor** (Prompt): 重要なエラーメッセージとスタックトレースの抽出
5. **KnowledgeBaseSearch** (KnowledgeBase): 過去事例との照合と根本原因推定
6. **ReportGenerator** (Prompt): Markdown形式の統合サマリーレポート生成
7. **OutputNode**: 最終レポートの出力

## クイックスタート

### 1. 環境設定
```bash
# 設定ファイルのコピー
cp .env.example .env

# .env ファイルを編集（必須項目を設定）
vim .env  # または任意のエディタ
```

**必須設定項目:**
- `AWS_ACCOUNT_ID`: AWSアカウントID
- `KNOWLEDGE_BASE_ID`: 既存のKnowledge Base ID
- `AWS_REGION`: デプロイ先リージョン（デフォルト: us-east-1）

### 2. 設定検証
```bash
chmod +x scripts/validate-config.sh
./scripts/validate-config.sh
```

検証内容:
- ✅ 必須環境変数の存在確認
- ✅ AWS認証情報の確認
- ✅ Knowledge Baseの存在確認
- ✅ Bedrockモデルの利用可能性確認
- ✅ JSON設定ファイルの構文チェック

### 3. デプロイ
```bash
chmod +x simple-deploy.sh
./simple-deploy.sh
```

デプロイ処理:
1. Knowledge Baseの存在確認
2. IAMロールの作成とポリシーアタッチ
3. フロー定義ファイルの生成（環境変数展開）
4. Bedrock Flowの作成と準備
5. テスト実行用ファイルの自動生成

## テスト実行

### 方法1: 生成されたテストファイルを使用
```bash
aws bedrock-agent invoke-flow \
  --flow-identifier <FLOW_ID> \
  --inputs file://test-execution-generated.json
```

### 方法2: 直接ログ内容を指定
```bash
aws bedrock-agent invoke-flow \
  --flow-identifier <FLOW_ID> \
  --inputs '{"log_content": "2024-10-03 ERROR [Test] NullPointerException occurred"}'
```

### 方法3: AWS コンソール
```
https://console.aws.amazon.com/bedrock/home?region=<REGION>#/flows/<FLOW_ID>
```

### 実行結果の確認
デプロイ完了後、`FLOW_ID`は`.env`ファイルに自動保存されます。

## ファイル構成

```
bedrock-flows-project/
├── config/
│   ├── flow-template.json      # フロー定義テンプレート（環境変数展開用）
│   └── iam-policies.json       # IAMロール・ポリシー定義
├── scripts/
│   ├── validate-config.sh      # 設定検証スクリプト
│   └── cleanup.sh              # リソース削除スクリプト
├── knowledge-base-data/
│   └── error-patterns.md       # ナレッジベース用サンプルデータ
├── .env.example                # 環境変数テンプレート
├── flow-definition.json        # 実際のフロー定義（デプロイ時に生成）
├── simple-deploy.sh            # メインデプロイスクリプト
└── README.md                   # このファイル
```

### 主要ファイルの説明

**設定ファイル:**
- `.env.example`: 環境変数テンプレート（コピーして`.env`を作成）
- `config/flow-template.json`: 環境変数を含むフロー定義テンプレート
- `config/iam-policies.json`: Bedrock実行用のIAMポリシー定義

**スクリプト:**
- `simple-deploy.sh`: ワンコマンドデプロイスクリプト
- `scripts/validate-config.sh`: デプロイ前の設定検証
- `scripts/cleanup.sh`: 作成したリソースの一括削除

**データ:**
- `knowledge-base-data/error-patterns.md`: よくあるエラーパターンと対処法のサンプル

## 環境変数設定

### 必須設定
| 変数名 | 説明 | 例 |
|--------|------|----|
| `AWS_REGION` | デプロイ先リージョン | `us-east-1` |
| `AWS_ACCOUNT_ID` | AWSアカウントID | `123456789012` |
| `KNOWLEDGE_BASE_ID` | 既存のKnowledge Base ID | `ABCDEFGHIJ` |
| `FLOW_NAME` | フロー名 | `test-log-analysis-flow` |
| `EXECUTION_ROLE_NAME` | IAMロール名 | `BedrockFlowExecutionRole` |

### オプション設定（推奨値）
| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `BEDROCK_MODEL_ID` | 使用するBedrockモデル | `anthropic.claude-3-haiku-20240307-v1:0` |
| `MAX_TOKENS_ANALYZER` | ログ分析の最大トークン数 | `3000` |
| `MAX_TOKENS_EXTRACTOR` | エラー抽出の最大トークン数 | `2000` |
| `MAX_TOKENS_REPORT` | レポート生成の最大トークン数 | `4000` |
| `TEMPERATURE` | モデルの温度パラメータ | `0.1` |
| `TOP_P` | モデルのTop-Pパラメータ | `0.9` |

## 入力・出力形式

### 入力形式
```json
{
  "log_content": "テストログの内容（文字列）"
}
```

**入力例:**
```json
{
  "log_content": "2024-10-03 10:15:26 ERROR [DatabaseConnection] Connection failed: java.sql.SQLException: Access denied\n2024-10-03 10:15:31 FATAL [TestRunner] Database connection failed after 3 attempts"
}
```

### 出力形式
Markdown形式のサマリーレポート:

```markdown
# 🔍 テスト実行サマリーレポート

**生成日時**: 2024-10-03 10:30:00
**重要度**: Critical

## 📊 実行概要
| 項目 | 値 |
|------|----|
| 総エラー数 | 5 |
| 総警告数 | 3 |
| 失敗テスト数 | 2 |

## 🚨 重要な問題
【重要なエラー1】
エラータイプ: DatabaseConnection
メッセージ: Connection failed

## 🔍 根本原因分析
- **主要な原因**: データベース認証情報の問題
- **影響範囲**: 全テストスイート
- **緊急度**: Critical

## 💡 推奨アクション
### 🔥 緊急対応（24時間以内）
- データベース認証情報の確認と修正
```

## Knowledge Baseの準備

このフローは既存のKnowledge Baseを使用します。Knowledge Baseには以下のようなデータを登録してください:

### 推奨データ構成
1. **エラーパターン集**: よくあるエラーとその対処法
2. **過去の障害事例**: 過去に発生した問題と解決方法
3. **トラブルシューティングガイド**: システム固有の対処手順

### サンプルデータ
`knowledge-base-data/error-patterns.md`にサンプルデータがあります。

**含まれる内容:**
- データベース接続エラーの対処法
- NullPointerExceptionの原因と対策
- タイムアウトエラーの解決方法

## トラブルシューティング

### デプロイエラー
**問題**: Knowledge Base IDが見つからない
```bash
# 利用可能なKnowledge Base一覧を確認
aws bedrock-agent list-knowledge-bases --query 'knowledgeBaseSummaries[*].[knowledgeBaseId,name,status]' --output table
```

**問題**: IAMロールの権限エラー
- `config/iam-policies.json`の内容を確認
- Bedrock実行に必要な権限が含まれているか確認

**問題**: モデルが利用できない
```bash
# 利用可能なモデル一覧を確認
aws bedrock list-foundation-models --query 'modelSummaries[*].[modelId,modelName]' --output table
```

### 実行エラー
**問題**: フローの実行が失敗する
1. CloudWatch Logsでエラー詳細を確認
2. 入力形式が正しいか確認
3. Knowledge Baseにデータが登録されているか確認

## クリーンアップ

作成したリソースを削除する場合:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

**削除されるリソース:**
- Bedrock Flow
- IAMロールとポリシー
- 生成されたファイル（flow-definition.json等）

**注意**: Knowledge Baseは削除されません。

## コスト見積もり

主なコスト要素:
- **Bedrock Model呼び出し**: 入力/出力トークン数に応じた従量課金
- **Knowledge Base検索**: クエリ数に応じた従量課金

詳細は[AWS Pricing Calculator](https://calculator.aws)で見積もりを作成してください。

## ライセンス

MIT License

## サポート

問題が発生した場合:
1. `scripts/validate-config.sh`で設定を確認
2. CloudWatch Logsでエラー詳細を確認
3. AWSサポートに問い合わせ