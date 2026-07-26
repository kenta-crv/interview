#!/bin/bash
# Sidekiq セットアップスクリプト（meetia）
# 使い方: bash bin/setup_sidekiq.sh
#
# systemd で常駐化し、落ちても自動再起動します。

set -euo pipefail

SERVICE_NAME="sidekiq-meetia"
DEFAULT_REDIS_URL="redis://127.0.0.1:6379/2"

echo ""
echo "========================================="
echo "  Sidekiq セットアップ（meetia）"
echo "========================================="
echo ""

cd "$(dirname "$0")/.."
APP_DIR=$(pwd)
APP_USER=$(whoami)

echo "[1/8] 環境情報"
echo "  アプリ: $APP_DIR"
echo "  ユーザー: $APP_USER"
echo "  サービス名: $SERVICE_NAME"
echo ""

echo "[2/8] Redis接続確認..."
if command -v redis-cli > /dev/null 2>&1; then
  if redis-cli ping > /dev/null 2>&1; then
    echo "  OK: Redisに接続できました"
  else
    echo "  NG: Redisに接続できません"
    echo "  → 以下を試してください: sudo systemctl start redis"
    exit 1
  fi
else
  echo "  確認スキップ（redis-cliが見つかりません）"
fi
echo ""

echo "[3/8] REDIS_URL を Meetia 専用 DB に設定..."
ENV_FILE="$APP_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  if grep -qE '^REDIS_URL=' "$ENV_FILE"; then
    # コメントアウト済みや他DB指定があっても本番は専用DBへ寄せる
    if grep -qE '^REDIS_URL=redis://[^[:space:]]+/2$' "$ENV_FILE"; then
      echo "  既存の REDIS_URL は DB2 です（変更なし）"
    else
      # 有効な REDIS_URL 行を置換（コメント行は触らない）
      if grep -qE '^REDIS_URL=' "$ENV_FILE"; then
        sed -i.bak 's|^REDIS_URL=.*|REDIS_URL='"$DEFAULT_REDIS_URL"'|' "$ENV_FILE"
        echo "  REDIS_URL を $DEFAULT_REDIS_URL に更新しました"
      fi
    fi
  else
    printf '\n# Meetia 専用 Redis（Okurite 等と分離）\nREDIS_URL=%s\n' "$DEFAULT_REDIS_URL" >> "$ENV_FILE"
    echo "  REDIS_URL=$DEFAULT_REDIS_URL を追記しました"
  fi
else
  echo "  WARN: $ENV_FILE がありません。手動で REDIS_URL=$DEFAULT_REDIS_URL を設定してください"
fi
echo ""

echo "[4/8] 既存の meetia Sidekiq を停止..."
sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
sleep 2
echo "  完了"
echo ""

echo "[5/8] サービスファイルを設置..."
sudo cp config/sidekiq-meetia.service "/etc/systemd/system/${SERVICE_NAME}.service"
sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$APP_DIR|" "/etc/systemd/system/${SERVICE_NAME}.service"
sudo sed -i "s|User=.*|User=$APP_USER|" "/etc/systemd/system/${SERVICE_NAME}.service"
sudo sed -i "s|Group=.*|Group=$APP_USER|" "/etc/systemd/system/${SERVICE_NAME}.service"
# EnvironmentFile / ExecStart 内のパスも実ディレクトリに合わせる
sudo sed -i "s|/opt/webroot/meetia|$APP_DIR|g" "/etc/systemd/system/${SERVICE_NAME}.service"
echo "  WorkingDirectory=$APP_DIR"
echo "  User=$APP_USER"
echo "  完了"
echo ""

echo "[6/8] systemd 登録・起動..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"
echo "  起動コマンド実行完了"
echo ""

echo "[7/8] 起動確認（10秒待機）..."
sleep 10
echo ""

echo "[8/8] 結果"
echo "========================================="
sudo systemctl status "$SERVICE_NAME" --no-pager 2>&1 || true
echo ""
echo "プロセス:"
ps aux | grep -E '[s]idekiq.*meetia' || echo "  （meetia Sidekiq プロセスが見つかりません）"
echo ""
echo "========================================="
echo "  完了"
echo "========================================="
echo ""
echo "「active (running)」なら成功です。"
echo "失敗時は: journalctl -u $SERVICE_NAME -n 100 --no-pager"
echo ""
echo "日次再起動 cron 例:"
echo "  45 0 * * * sudo systemctl restart $SERVICE_NAME >> /opt/webroot/cron_restart.log 2>&1"
echo ""
