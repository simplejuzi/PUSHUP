# PUSHUP

极简俯卧撑训练记录 App。加上常用动作快捷填、每日目标、成就彩蛋，还能看大家的动态、互相点赞评论。

> 单文件 Web App（`index.html`）+ Capacitor 打包成 Android APK。
> 包名 `com.simplejuzi.pushup`，签名可覆盖安装。

## 功能

**5 个主页面**

| 页面 | 做什么 |
|---|---|
| **记录** | 每天打卡俯卧撑（含变式）：个数、体重、臂围、备注；常用动作一按填；每日目标（完成掉彩蛋）；每日提醒 |
| **数据** | 日历热力、累计统计、体重折线图、周报（可发动态） |
| **历史** | 按日 / 月回看记录，月度统计 |
| **动态** | 卡片列表，发动态附训练成果；点赞、评论、**回复某人**；消息提醒；下拉刷新 |
| **我的** | 资料、训练概览（天数/累计/连续）、成就墙、我的动态、体重臂围、设置（8 套配色 × 浅色/深色/跟随系统）、检查更新 |

**其他**：排行榜（总榜按健身天数 + 月榜 + 周榜）、消息页（谁赞了/评论了/回复了你，未读红点）、找朋友与他人主页（滑入过渡、公开记录、成就）、动作库（自定义动作、本机与云端合并不丢）、14 种彩蛋图鉴。

## 技术栈

- 前端：单个 `index.html`，内嵌 CSS + JS，无框架、无构建步骤
- 后端：**MySQL 8.0** + 单文件 PHP 接口 `mysql/api.php`（宝塔部署，无第三方依赖）
- 数据：本地 localStorage 优先 + 云端同步，离线可完整使用
- 打包：Capacitor 6 + Android，Service Worker 离线缓存（`sw.js`）
- 更新检查：自建服务器优先、GitHub Release 兜底

## 仓库与发布

- **代码 + 发布都在本仓库 `simplejuzi/PUSHUP` 的 `main` 分支**（2026-11-25 起统一）。
- 构建工作流 `.github/workflows/build-apk.yml` 仅手动触发（`workflow_dispatch`），发布步骤关闭，Release 手动创建。
- 当前发布版本见 [`version.json`](./version.json) 与 [Releases](https://github.com/simplejuzi/PUSHUP/releases)；App 内「检查更新」读取 `releases/latest`。

## 文档

| 文档 | 内容 |
|---|---|
| **[PROJECT-HANDOFF.md](./PROJECT-HANDOFF.md)** | **项目交接活文档（唯一权威）**：技术栈、当前进度、功能清单、关键文件、怎么改、后端数据、协作约定。改代码前先读这份 |
| [`version.json`](./version.json) | 版本唯一来源：版本号 / tag / APK 名 / 更新说明 |
| [`mysql/`](./mysql/) | 后端接口 `api.php`、建表 `schema.sql`、部署说明 `README.md` |

> 本项目已不使用 Supabase 与云函数反代；历史文档已清理，旧问题不要再参考。

## 本地打包（可选）

需要本机装 Node 20 + Android SDK：

```bash
npm install
npx cap sync android
cd android && ./gradlew assembleDebug
```

日常发版走 GitHub Actions 手动触发，见 `PROJECT-HANDOFF.md` 第 6 节。
