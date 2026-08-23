# deploy/ — 部署运维脚本（版本化管理，已脱敏）

> 2026-08-22 整理：原 `_archive/工具/` 脚本迁入本目录并**脱敏**——所有口令改用环境变量注入，
> 仓库内**无明文口令**（对"已知口令值字样"做 `git grep` 断言为空，见工作流SOP §3）。
> 凭据实际值保存在用户记忆中，不入库、不上公共仓库。

## 环境变量（使用前 export 或写入 shell 配置）

| 变量 | 用途 | 默认 |
|---|---|---|
| `SOULCORE_HOST` | 游戏服域名 | `soulcore.asia` |
| `SOULCORE_PORT` | SSH 端口 | `56789` |
| `SOULCORE_USER` | SSH 用户 | `administrator` |
| `SOULCORE_SSH_PASS` | SSH 口令（必填，无默认） | — |
| `SOULCORE_DB_PASS` | MariaDB root 口令（`ssh_soulcore.py --mysql*`、`run_backup.py` 用） | — |
| `SOULCORE_FN_USER` / `SOULCORE_FN_PASS` | FNOS/NAS 账号（`run_backup.py`、`setup_fn_key.py` 用） | — |
| `GITHUB_PAT` | GitHub PAT（`deploy_pb_ci.py` / `deploy_pb_final3.py` 取 CI 产物用） | — |
| `SOULCORE_PROXY` | 下载代理 URL（可选） | — |

遗留说明：`deploy_pb_now.log`、`register_src.tar.gz` 留在 `_archive/工具/`（含日志/归档，不入库）。

## 脚本清单

| 脚本 | 用途 | 备注 |
|---|---|---|
| `ssh_soulcore.py` | **主运维工具**：远程命令 / `--mysql-all` 导 SQL（目标库自动解析） / `--put` 传 Lua | 强制 IPv4；SOP 主用 |
| `tunnel_3306.py` | 本地→服务器 3306 端口转发（注册页联调） | 环境变量默认 |
| `pbmangosd.service` / `pbrealmd.service` / `pb-tunnel.service` | PB 服 systemd 单元（`/opt/soulcore-pb/`） | 无凭据，直接入库 |
| `deploy_units.py` | 部署上述 3 个 systemd 单元到服务器 | |
| `deploy_fix.py` | 修复/重部署 systemd 单元 | |
| `deploy_hearthstone_fix.py` | 炉石脚本修复 + 热重启（tmux） | |
| `deploy_fail2ban.py` | 服务器安装 fail2ban（SSH 爆破封禁） | |
| `fix_jaillocal.py` | fail2ban jail 配置修复 | |
| `deploy_pb_ci.py` / `deploy_pb_final3.py` | 从 GitHub Actions 取 CI 产物→替换 PB 二进制→重启 | 需要 `GITHUB_PAT` |
| `run_backup.py` | **NAS 冷备**：主服+PB服 rsync + 四库×2 mysqldump→FNOS | 对应 `PB服冷备恢复指南` |
| `run_copy.py` | 服务器间/服务器-NAS 拷贝 | |
| `setup_fn_key.py` | 建立 游戏服→FNOS 免密 key 通道 | |
| `launch_mangosd.py` / `tunnel_launch.py` | 启动 mangosd / 建隧道 | |
| `pb_deploy_exec.py` / `pb_diff_analyze.py` / `pb_diff_show.py` | PB 部署执行 / diff 分析 | 项目脚本 |
| `ssh_generic.py` | 通用 SSH 执行（口令走 `SOULCORE_SSH_PASS` env，**不落 argv/ps**） | |
| `analyze_core.sh` | 服务器日志/崩溃分析脚本 | |
| `sync_server_baseline.py` | **只读探针 + 漂移检查**：`--check` 比对活服与 `docs/server_baseline_expected.json`（漂移非零退出）；`--store-expected` 刷新期望基线；默认生成 `docs/服务器现状_快照_*.md` | 需 python+SSH |

## 用法示例

```bash
export SOULCORE_SSH_PASS='***' SOULCORE_DB_PASS='***'
# 拉取/执行远程命令
python deploy/ssh_soulcore.py 'systemctl is-active pbmangosd pbrealmd mariadb'
# 导 SQL：目标库自动解析（USE → 文件头「目标库」→ 默认 tw_world）
python deploy/ssh_soulcore.py --mysql-all sql/local_changes/017_phase1_reforge.sql
#   部署 001-017（头标主服库族）到 PB 实例时显式传库：--mysql-all 017_phase1_reforge.sql tw_pb_world
# 传 Lua
python deploy/ssh_soulcore.py --put lua_scripts/core/welcome.lua /opt/soulcore-pb/server/bin/lua_scripts/welcome.lua
# NAS 冷备
python deploy/run_backup.py
# 服务器真身漂移检查（非零=漂移；迁移落地后先 --store-expected 刷新期望值）
python deploy/sync_server_baseline.py --check
python deploy/sync_server_baseline.py --store-expected
```
> 详细工作流见 `docs/工作流SOP_2026-08-22.md`。