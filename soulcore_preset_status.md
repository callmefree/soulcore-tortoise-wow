# SoulCore Tortoise WoW — 预置部署状态报告

- **生成时间**：2026-08-12 10:46 (UTC+8)
- **部署目标**：Ubuntu 22.04.5 LTS（主机名 `wowserver`）@ `soulcore.asia:56789`
- **报告性质**：预置阶段 T1–T9 进度 + Linux 二进制缺口补齐（本会话完成）

---

## 一、总体结论

预置阶段 **T1–T9 全部完成**。原「唯一缺口」—— GitHub CI 产出的 Linux 二进制（`mangosd`/`realmd`）——已于 **2026-08-12 本会话内补齐并验证可执行**。

**服务已具备起服条件，仅待人工启动 `realmd(3724)` → `mangosd(8090)`。**

---

## 二、预置进度统计（T1–T9）

| 任务 | 状态 | 结果 |
|---|---|---|
| T1 目录骨架 | 完成 | `/opt/soulcore/{server/{bin,data,etc,sql,logs},sql}` |
| T2 地图数据 3.4G | 完成 | dbc/maps/vmaps/mmaps/Buildings 齐全 |
| T3 Lua 脚本 | 完成 | welcome / super_hearthstone / arpg/* 就位（`bin/lua_scripts/`） |
| T4 MariaDB 11.4 | 完成 | Ubuntu 11.4.12，root/soulcore2026，mangos/mangos 已授权 |
| T5 dump 四库 | 完成 | 本机读库导出，未动原数据 |
| T6 传 dump | 完成 | 四库 SQL 传至 `sql/dump/` |
| T7 导入 | 完成 | tw_logon 41表 / tw_world 281表 / tw_char 96表 / tw_logs 1表；creature_template=14340，account=1（已有 GM 账号） |
| T8 配置 | 完成 | 三份 conf 已传（CRLF→LF），零改动可用 |
| T9 验证 | 完成 | 全部元素就位，磁盘 36G / 用11G / 闲23G |

---

## 三、二进制缺口补齐（本会话 2026-08-12）

- **CI 现状**：`weekly-build.yml` 已含 Linux job（`build`，`ubuntu-22.04`），产物 artifact `soulcore-tortoise-wow`。**无需新建 `build-linux.yml`**。
- **选用构建**：run **#21**（2026-08-10，success），`head_sha = b10cbbb` == 当前 `main` HEAD → 产物即最新代码编译结果。
- **流程**：下载 artifact（319MB zip）→ 解包（zip→tar.gz→`dist/bin`）→ 提取 `mangosd`(684MB)/`realmd`(12MB) → SFTP 至 `/opt/soulcore/server/bin/`（chmod 755）。
- **缺库修复**：`ldd` 报 `libACE-7.0.6.so => not found` → 目标机 `apt-get install -y libace-7.0.6`，复验无缺库。
- **执行验证**：
  - `mangosd --version` → `Core revision: 2026-08-09 16:07:53 +0800`
  - `realmd --version` → 同上
  - `ldd` 两二进制均 `not found` → **NONE**

---

## 四、远端实测快照（soulcore.asia:56789，只读探活）

- OS：Ubuntu 22.04.5 LTS，kernel 5.15.0-187-generic
- 磁盘 `/`：36G / 11G used / 23G avail / 33%
- MariaDB：`active`；库 `tw_logon` / `tw_world` / `tw_char` / `tw_logs` 全部在位
- `/opt/soulcore/server/bin`：`anticheat.conf`、`lua_scripts/`、`mangosd`、`mangosd.conf`、`realmd`、`realmd.conf`（二进制已就位）
- `/opt/soulcore/server/data`：Buildings / dbc / maps / mmaps / vmaps 齐全

---

## 五、起服步骤（用户执行，AI 不碰进程）

1. 启动 `realmd`：`/opt/soulcore/server/bin/realmd`（端口 3724）
2. 启动 `mangosd`：`/opt/soulcore/server/bin/mangosd`（端口 8090）
3. 客户端 `realmlist.wtf` 指向 `192.168.1.53:3724`（公网 `soulcore.asia:3724` 视路由器端口映射）
4. 用 GM 账号 `admin/admin123` 登录验证

---

## 六、已知坑 / 运维要点

- `soulcore.asia` 同时解析 **IPv6（240e:…）与 IPv4（125.110.90.129）**；SSH/paramiko 必须强制 IPv4（`socket.getaddrinfo(AF_INET)`），否则卡 IPv6 超时。
- 从 WorkBuddy 沙箱触达该 SSH 端口需关闭沙箱网络限制（`dangerouslyDisableSandbox`）；GitHub HTTPS 在沙箱内默认可达。
- Linux 二进制运行时依赖 `libACE-7.0.6.so`（apt 包 `libace-7.0.6`）；Windows 端对应为 `ACE.dll`。
- 获取后续 Linux 二进制：直接下载 `weekly-build.yml` `build` job 最新成功 run 的 artifact `soulcore-tortoise-wow`，无需重建。
