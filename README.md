# Claude Code Statusline

Claude Code のステータスラインに以下を表示するスクリプト。

- モデル名 + thinking effort
- コンテキスト使用率
- 作業ディレクトリ
- 5時間レート制限（リセットまでの残り時間付き）
- 週間レート制限（リセットまでの残り時間付き）

## セットアップ

### Linux / macOS（bash 版）

**必要なもの**: `jq`

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

`~/.claude/settings.json` に追加:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Windows（PowerShell 版）

追加インストール不要。Windows Terminal 推奨。

```powershell
Copy-Item statusline-command.ps1 "$env:USERPROFILE\.claude\statusline-command.ps1"
```

`%USERPROFILE%\.claude\settings.json` に追加:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -File C:/Users/<ユーザー名>/.claude/statusline-command.ps1"
  }
}
```

`<ユーザー名>` は自分のユーザー名に置き換える。

## 表示例

```
Opus 4.6:high | context:42% | ~/my-project | 5h:23%(reset in 3h12m) | weekly:8%(reset in 5d2h)
```
