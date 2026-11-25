# PUSHUP · 项目交接活文档（给接手的 AI / 开发者）

> **这是本项目的唯一权威说明。** 换 AI 接手、改功能、修 bug 之前，先读完这份再动手。
> 最后更新：**2026-11-25**，对应发布版本 **v1.45**（代码+发布均在 PUSHUP/main）。
>
> 旧的 v1.30 时代误导文档（`HANDOFF.md`、`HANDOFF-PROMPT.md`、`supabase.sql`、`supabase-proxy/`）
> 已于 2026-11-25 **清理删除**（还写着 Supabase 反代、Lite 版、4 个 tab，容易误导）。
> 本项目早已不用 Supabase / 云函数反代，后端是 MySQL（见第 7 节）。`README.md` 是门面介绍，本文是唯一权威活文档。

---

## 1. 三十秒速览

| 项 | 内容 |
|---|---|
| 是什么 | 极简俯卧撑训练记录 Android App，主体是**单文件 Web App `index.html`**，用 Capacitor 包成 APK |
| 技术栈 | 原生 HTML/CSS/JS（无框架、无构建步骤）+ Capacitor + MySQL 8.0 后端（PHP 单文件 `api.php`）+ localStorage 本地兜底 |
| 代码仓库 | **`simplejuzi/PUSHUP` 的 `main` 分支**（2026-11-25 迁移完成，代码与发布统一到这一个仓库） |
| 发布仓库 | 同上 `simplejuzi/PUSHUP`，Release 发这里，App 检查更新也读这里的 `releases/latest` |
| 旧仓库 | `simplejuzi/pushup-lite` 已设为**私有只读存档**，不再使用；原主线 `transition/legacy-upgrade` 的内容已迁到 PUSHUP/main |
| 包名 / 签名 | `com.simplejuzi.pushup` / 调试密钥 `signing/debug.keystore`（指纹 `5E:9C:…:55:56`），可覆盖安装 |
| 当前发布 | **v1.45**，versionCode `10016`，Service Worker 缓存 `pushup-transition-v17` |
| 页面 | **5 个 tab**：记录 · 数据 · 历史 · 动态 · 我的（外加排行榜/消息/个人主页/动作库等二级页） |
| 云端 | MySQL 8.0，接口 `http://154.12.36.171:27080/pushup/api.php`（宝塔服务器，见第 7 节） |

---

## 2. 技术栈与架构

- **前端**：一个 `index.html` 装下全部 HTML/CSS/JS（约 8000 行）。没有 React/Vue、没有 npm 打包，`<style>` 分块 + `<script>` 分块组织，新功能通常以「追加一个 `<style id="...">` / `<script id="...">`」的方式叠加，避免改动老代码。
- **壳**：Capacitor（`capacitor.config.json`、`package.json`、`tools/build-apk.py`），`webDir` 是 `www`，构建时把 `index.html` 等拷进去。开了明文流量（`cleartext: true`、`allowMixedContent: true`），因为后端是 http 非标端口。
- **后端**：`mysql/api.php` 单文件 PHP（PDO），兼容原 Supabase 风格的 `api.php?path=...` 路由。表结构在 `mysql/schema.sql`。无第三方依赖。
- **数据策略**：**本地优先 + 云端同步**。localStorage 存全量（`sLoad()`/`sSave()`），登录后 `syncCloud()` 把云端 posts/likes/comments/records/settings 拉下来合并；离线也能完整用，联网才同步。
- **通知/提醒**：纯本地计算（`v141-notif-js` 脚本块），读已同步下来的点赞/评论，不额外发请求。已读线存 localStorage `pushup_notif_seen_v1`。

---

## 3. 当前进度（改之前先对齐）

- **已发布 v1.45**（PUSHUP/main commit `5b94ae7`，Release id `458063803`，`releases/latest` 指向它）：= v1.44 全部 + ①「被回复的人收到红点」（消息页「XXX 回复了你」，被回复人 uid 用零宽字符编进 comment 的 text，`replyTarget()`/`stripReplyMark()` 解析，notif 生成 `k:"reply"` 事件）；②**真沉浸式状态栏**（`setOverlaysWebView(true)` + 透明底 `#00000000`，页面 `--surface` 透上来无分割线；图标随主题明暗自动切；开屏/底栏/二级页按 safe-area 留白）。versionCode `10016` / sw v17 / 更新说明 2 条。
- **本地未发布的改动**（未提交/未构建，出包等用户说「上传」）：**悬浮胶囊底栏**（v1.46，参照图重做）——底栏改成两侧留边+大圆角+半透明玻璃的悬浮胶囊，选中项用 `--accent-soft` 高亮块包裹（`.tab.on`），5 个图标换实心（`ic-solid` 用 fill），内容是记录/数据/历史/动态/我的（**不做中间 + 按钮**）。相关：`.tabbar` 改 `position:absolute;left/right:12px;bottom:calc(18px+safe-area);border-radius:26px`，tab 间距 `gap:0`、左右 padding 0 收紧，`.screen` padding-bottom 118px、`feed-lock` 110px、`.lib-foot` 底距 92px、tabdot 位置微调。**液态玻璃**：`.tabbar` 用 `background:linear-gradient(半透明) + backdrop-filter:blur(26px) saturate(1.9)`，`::before` 顶部斜向反光、`::after` 底部内阴影，`.tab.on` 半透明主题色光片 + 内高光；`body.dark .tabbar` 单独降白色高光防发灰。
- **底栏显隐 + 二级页返回**（v1.46，本地未发布）：`switchTab()` 里 `barless` 改成 `!MAIN_TABS[name]`（5 主 tab 才显示底栏，10 个二级页全部隐藏）；把 `.pg-back` 提为全局样式、新增 `.head-row.has-back`（返回键+标题成组、右侧靠右），给缺返回的 4 个页 **myposts / recs / settings / library** 补了左上返回按钮（`onclick="handleAppBack()"`，走 SUB_PARENT 回父页）。badges/rank/notif 原本已有 `.bg-back`、friends/post 有 `.back-btn`、user 有 `.pg-back`，未动。
- 全 15 页遍历验证：5 主 tab 底栏显示、10 二级页底栏隐藏且都有返回；截图核对 settings/myposts/recs/library 返回键位置正常。
- **v1.46 第二批功能**（本地未发布）：①**底栏滑块动画**：`#tabSlider` 玻璃滑块随 tab 平滑移动（`moveTabSlider()`/`refreshTabSlider()`，`.tab.on` 只变色不再自带背景），切主 tab 定位、二级页隐藏、resize/orientation 重算。②**数据页周环比**：`renderWeekCmp()` 在 `#kpis` 下渲染「本周 vs 上周」个数/天数对比 + 涨跌箭头 + 提示语（`weekStat(0,true)` vs `weekStat(1,false)`，注意 offset=1 是上周，因 `weekStartDay` 是减 offset*7）。③**周日首次打开弹本周周报**：`maybeShowSundayWeekReport()`，`getDay()===0` 且当天没弹过（`localStorage pushup_weekreport_seen`）且有数据才弹，开屏后 3.4s 弹 `openWeekReport()`。④**底栏手势**：`bindTabGestures()`（幂等，`__tgBound` 防重绑，初始化重试 8 次）——双击同一 tab 回顶部、长按「记录」展开添加面板补录、长按其它 tab 回顶部。
  - **踩坑**：`renderWeekCmp` 里直接调 `weekStat` 若运行期顺序不巧会抛 `ReferenceError` 打断整段主脚本（连带 bindTabGestures 不执行）；已加 `typeof weekStat==="function"` 守卫。
- **旧仓库历史**：v1.44 `4d8abe3`（评论可回复某人，发布在迁库前）、v1.43 `521a5bc`（动态页卡片化重构）、v1.42 `c0c063b`（目标只算俯卧撑/自定义动作/彩蛋）。
- 注：v1.45 是通过 Git Data API 提交到 PUSHUP/main 的（git push 因 github.com:443 超时不通）。本地目录 git 历史仍是旧 lite 历史，内容以 PUSHUP/main 为准。

---

## 4. 功能清单

**5 个主 tab**
- **记录**：每天打卡俯卧撑个数/体重/臂围/备注，常用动作一按填；每日目标（只统计名称含「俯卧撑」的动作）+ 完成掉彩蛋；今日提醒。
- **数据**：日历热力、累计统计、体重折线图、周报（可发动态）。
- **历史**：按日/月看记录、月度统计。
- **动态**：卡片列表（默认 15 条可展开），发动态附今日成果/周报快照，点赞、**评论 + 回复**、内联展开；点赞人和评论直接显示；顶部「动态」标题 + 消息/排行榜/找朋友/发动态按钮；下拉刷新。
- **我的**：资料编辑、训练天数/累计/连续统计、成就墙、我的动态、体重臂围、设置（8 套配色 × 浅色/深色/跟随系统）、接口地址、更新日志。

**二级页 / 功能**
- **消息页**：谁赞了/评论了/回复了你，未读红点（铃铛 + 底栏），点开定位并高亮对应动态，全部已读。
- **排行榜**：独立页面，总榜（按健身天数，非连续）+ 月榜 + 周榜，并列同名次、距上一名提示。
- **找朋友 / 个人主页**：用户列表、他人主页（滑入过渡）、公开训练记录、成就墙、关注/聊天入口。
- **动作库**：自定义动作本机与云端按 id 合并、删除记墓碑；分类可横滑。
- **成就**：多枚徽章（`BADGES`），达成弹窗。
- **彩蛋**：14 种普通/稀有/传说（`EGGS`），图鉴存本机 `pushup_egg_day_v1`/`pushup_egg_album_v1`。
- **检查更新**：优先自建服务器 `version.json`，GitHub Release 兜底；带超时与进度提示。

---

## 5. 关键文件地图

| 文件 | 作用 / 改动入口 |
|---|---|
| `index.html` | **主战场**，全部前端。搜索关键函数/标识定位：`APP_VERSION`（版本号）、`APP_CHANGELOG`（更新日志）、`UPDATE_ENDPOINTS`（更新源）、`API_BASE_DEFAULT`（接口地址）、`sLoad/sSave`（本地数据）、`syncCloud`（同步）、`sendComment`（发评论/回复）、`renderFeed`/`postCardHtml`（动态卡片）、`v141-notif-js`（提醒）、`BADGES`/`EGGS`（成就/彩蛋） |
| `version.json` | 版本唯一来源：`version`/`tag`/`apk`/apkUrl/`changelog`。**必须与 `index.html` 的 `APP_VERSION` 一致** |
| `sw.js` | Service Worker，缓存名 `pushup-transition-vNN`，每次发版递增（清旧缓存） |
| `.github/workflows/build-apk.yml` | 构建 workflow（**仅 `workflow_dispatch` 手动触发**），里面写死 `versionCode 10016`。发布步骤 `if:false`，Release 要手动建 |
| `capacitor.config.json` / `package.json` | Capacitor 壳配置、包名、依赖、打包脚本 |
| `mysql/api.php` / `schema.sql` / `config*.php` | 后端单文件接口与表结构。**表字段固定**（见第 7 节），加字段要动数据库，谨慎 |
| `signing/debug.keystore` | 签名密钥，勿换，否则老用户无法覆盖安装 |
| `icons/` | 应用图标 |

**工作区交付目录**：`C:/Users/11922/WorkBuddy/2026-11-10-17-54-07`（预览 HTML、APK、日志都放这里；预览由 `.workbuddy/build_preview.py` + `preview-inject.js` 生成）。

---

## 6. 怎么改（重点，接手 AI 必读）

### 版本号同步清单（发新版时 4 处一起改）
1. `index.html` → `const APP_VERSION="vX.XX"`
2. `index.html` → `APP_CHANGELOG` 数组**顶部/末尾加本版条目**
3. `version.json` → `version`/`tag`/`apk`/`apkUrl` + `changelog`（**与 APP_CHANGELOG 逐条一致**）
4. `sw.js` → 缓存名 `pushup-transition-vNN` 递增
5. `.github/workflows/build-apk.yml` → `versionCode 100XX` 两处（`re.sub` 和 print）

### 构建 / 发布流程（实操）
1. 提交到 `PUSHUP` 的 `main`：`git push` 常不稳，用 `env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY git -c http.proxy= -c https.proxy= push origin main`；再失败用 GitHub Git Data API。
2. 触发构建：`POST /repos/simplejuzi/PUSHUP/actions/workflows/build-apk.yml/dispatches`，body `{"ref":"main"}`。
3. 轮询 run 成功 → 取 `actions/runs/<id>/artifacts` → 下载 zip 解压出 APK。
4. **手动建 Release**（workflow 的发布步骤是 `if:false`）：`POST /repos/simplejuzi/PUSHUP/releases`，`tag_name`/`name`/`body`(更新说明)/`make_latest:"true"`，**不要传 `target_commitish`**（省略即可，默认 main）。
5. 上传 asset：`POST uploads.github.com/repos/simplejuzi/PUSHUP/releases/<id>/assets?name=PUSHUP-vX.XX.apk`，Content-Type `application/octet-stream`。
6. 验证：`releases/latest` 指向新 tag，API 下载 asset 返回 200。
- 所有 GitHub API / curl 一律加 `--noproxy '*'`；token 在 remote URL / 环境变量里。

### 红线（别碰）
- **不改数据库字段、不动服务器**：按用户约定「宝塔那套先不动，服务器没传任何文件」。新功能尽量用现有字段（如回复信息塞进 comment 的 `text`，用零宽字符编码 uid，旧版不可见、新版可解析）。
- **兼容旧数据、不要丢**：本地与云端按 id 合并、删除记墓碑；新增逻辑不能覆盖老数据。
- **更新日志只写本版本内容**，不累积历史版本条目（见第 9 节）。
- **没叫上传/构建就不要 push 或打包**；正式代码等用户下指令再落地。

### 常见坑
- `index.html` 是大文件，工作区多为 CRLF；用 GitHub API 提交时 blob 要走 `git cat-file blob` 取仓库里的 LF 内容，否则 tree SHA 不一致。
- 预览脚本会吞顶层语句：新功能尽量写成独立 `<script>` 并用 `typeof` 防御，或写进主脚本；`const` 变量如需被别处覆盖改 `var`。
- 带 `g` 标志的正则 `String.match()` 返回字符串数组、**没有捕获组**；要提取捕获组得用不带 `g` 的正则（踩过：`replyTarget`）。
- 无头 Chrome 截图验证时 `--window-size=390` 实际视口会被撑到 500px，要注入 CSS 强制 `.phone{width:390px!important}` 才准。

---

## 7. 后端与数据

- 接口：`http://154.12.36.171:27080/pushup/api.php`（宝塔 13.2 / MySQL 8.0.46 / PHP 8.2 / Nginx 1.26，库 `pushup`）。服务商只放行 27022/27080/27443；SSH 用 22。非标端口不通先查 UFW。
- 表（`schema.sql`）：`profiles`(id,name,emoji,created_at)、`posts`(id,uid,text,workout,ts)、`post_likes`(post_id,uid,ts)、`post_comments`(id,post_id,uid,text,ts)、`records`(uid,d,payload,updated_at)、`settings`(uid,favs,custom,cats,nickname,theme,palette,updated_at)。**字段固定，改要动数据库**。
- 服务器部署：网站目录只放 `api.php`/`config.php`/`config.local.php`；`schema.sql`/`import.php` 等放 `/www/server/pushup-backend/`，Nginx 禁止外部访问。
- 云端未迁移老 Supabase 账号，库目前基本是空的；迁移待用户提供导出数据。

---

## 8. 已知问题 / 待办
- 提醒是**本地计算 + 依赖同步**，不是服务器推送：对方要打开 App 同步到新评论后才会看到红点。
- 目前是 `assembleDebug` + 调试密钥（`debuggable=true`）；上架正式商店需改 release 构建和隐私政策，但按用户约定「上架前三项不要提、找回密码不做」。
- 旧 Supabase 账号未迁移，库 0 用户，用户需重新注册。
- 本文档需**每次改动同步更新**（见第 9 节约定）。

---

## 9. 协作约定（用户明确规定，接手 AI 必须遵守）

1. **交付格式**：要「预览版」→ 只给预览 HTML + 一份简短日志；要「上传构建 APK」→ 只给 APK + 一份简短日志。不主动发方案文档、不写长篇汇报。没叫上传/构建就不要 push 或打包。
2. **更新日志**：每个版本的 changelog **只写本版本改动**，不把历史版本条目堆进去（`APP_CHANGELOG` + `version.json` + Release notes 三处一致）。
3. **动手前先征询**：用户让做功能/改 bug 时，先给简短建议并问：①有没有要优化/增加的 ②方案合不合适、是否继续 ③是否要扩展或衍生其他功能。确认后再做。
4. **本文活文档**：每次改动后同步更新本文件（版本进度、功能状态、改动了什么），保证接手方永远看得到最新状态。
