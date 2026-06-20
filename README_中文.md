# RustDesk 自定义客户端编译器 (中文版)

> 本仓库 fork 自 [wztx/rustdesk-client](https://github.com/wztx/rustdesk-client) (rdgen.crayoneater.org 源码)。  
> 已**全 UI 中文化**, 后续会加 **svchost 专属预设 + 独有 patch**。

---

## ⚡ 启动前你要做的 3 件事

### 1. 生成 GitHub Fine-grained Token (5 分钟)

1. 打开 https://github.com/settings/tokens?type=beta
2. 点 **Generate new token**
3. 填:
   - **Token name**: `rustdesk-builder` (随便起)
   - **Expiration**: 90 天 (或更长)
   - **Repository access**: 选 **Only select repositories** → 勾选你的 `liuleiliulei/rustdesk-client` (这个 fork)
   - **Permissions** (展开 Repository permissions):
     - **Actions**: Read and Write ⭐ 必须
     - **Contents**: Read and Write ⭐ 必须
     - **Workflows**: Read and Write ⭐ 必须
     - **Metadata**: Read (自动勾选, 不用动)
4. 点 **Generate token** → 复制出来那串 `github_pat_xxxx...` (只显示一次, 记下来)

### 2. 启用你 fork 的 GitHub Actions

打开 https://github.com/liuleiliulei/rustdesk-client/actions → 如果有绿色按钮 "I understand my workflows, enable them" 就点一下。

### 3. 改 docker-compose.yml 填两个值

打开 `docker-compose.yml`, 找到这两行, 填进去:

```yaml
SECRET_KEY: "请-改-我-..."     # ← 改成随机字符串 (下面给生成命令)
GHBEARER: "请-改-我-ghp_..."   # ← 改成你刚生成的 GitHub token
```

**生成随机 SECRET_KEY**:
```bash
python3 -c "import secrets; print(secrets.token_hex(50))"
```

---

## 🚀 启动

```bash
cd /Users/liulei/Downloads/rustdesk-builder

# 启动 (首次会构建 docker 镜像, ~3-5 分钟; 之后秒启)
docker compose up -d

# 看日志
docker compose logs -f

# 停止
docker compose down
```

启动后访问: **http://localhost:8000**

---

## 📋 表单填法 (svchost 等效配置)

打开 http://localhost:8000 后, 按这个填:

| 选项 | 填什么 |
|---|---|
| **选择平台** | Windows 64Bit |
| **RustDesk 版本** | 1.4.7 (或更高) |
| **修复第三方 API 连接延迟** | ☑ 勾上 |
| **EXE 文件名** | `svchost` |
| **应用名称** | `svchost` |
| **连接方向** | `仅被控端 (Incoming Only)` ← 客户端装这个 |
| **禁用安装功能** | `否, 允许安装` |
| **禁用设置面板** | `是, 禁用设置` |
| **服务器地址** | `10.10.10.10` |
| **服务器公钥** | `R6W+FOvHRK3rH9q2s0T7YlNc85rroFnujs0gHcphqMo=` |
| **API 服务器** | `http://10.10.10.10:21114` |
| **公司名** | 留空 (默认 Purslane Ltd, 跟改版一致) |
| **密码接受模式** | `通过密码接受连接` |
| **设置永久密码** | `an8888` |
| **允许直接 IP 连接** | ☑ 勾上 |
| **允许隐藏 CM 连接窗口** | ☑ 勾上 |
| **权限类型** | `完全权限` |
| **会话期间移除被控端壁纸** | ☑ 勾上 |
| **移除新版本升级提示** | ☑ 勾上 |
| (其他默认) | 不动 |

点 **开始编译** → 等 30-45 分钟 → 下载 zip。

---

## ⚠️ 编译注意

- **第一次编译会失败**: 因为 GitHub Actions 需要先在 fork 仓库手动启用 (上面第 2 步)
- **后续每次**: 触发 fork 仓库的 GitHub Actions 跑, 用你 GitHub 账号免费 2000 分钟/月 额度
- **30 分钟编译完, 自动下载 zip**: zip 里是各平台所有产物 (exe / msi / dmg / deb / apk)

---

## 🎯 跟我们 v1.5 svchost 还差什么

这一步 (Step 1) 只是把 rdgen **中文化 + 本机部署**, 还**没加** svchost 专属 patch:

```
本机 rdgen 编译出的 vs 我们 v1.5 svchost:
  ✅ 装 MSI 就能用 (server/key/api 编进 DLL)
  ✅ disable-settings=Y (设置面板锁死)
  ✅ an8888 预设密码
  ✅ access-mode=full (默认完全权限)
  ✅ allow-hide-cm=Y (CM 隐藏)
  ✅ direct-server=Y (允许直连)
  ✅ 移除升级 banner
  ❌ "由 svchost 提供" 中文翻译 (rdgen 没改 lang/cn.rs)
  ❌ 三个点 onTap=null (rdgen 用 disable-settings, 三个点可能直接消失)
  ❌ 反 OnVUE 任务管理器空白伪装 (rdgen 没改 PE VERSION_INFO)
  ❌ 临时密码 + 固定密码同时显示 (rdgen 用 verification-method=use-permanent-password)
```

→ 你**先试用本机 rdgen 编译一版**, 看跟 v1.5 体验差多少:
- 如果**接受这个差距** → 后续就用 rdgen, 不用再 patch
- 如果**必须加我们独有 patch** → Step 2 fork rdgen + 加 patch (1-2 天)

---

## 🆘 常见问题

**Q: docker compose up 启动失败, 提示 GHUSER 不能空**  
A: docker-compose.yml 里 `GHBEARER` 还是 "请-改-我-...", 必须填真 token

**Q: 编译触发后, GitHub Actions 报 "workflow not found"**  
A: 你 fork 仓库的 Actions 没启用. 去 `https://github.com/liuleiliulei/rustdesk-client/actions` 点"Enable Actions"

**Q: 编译完了下载 zip 报 password 错误**  
A: 你 docker-compose 配了 ZIP_PASSWORD, 但 web 表单提交时也要填同一个密码. 留空就两边都留空

**Q: 中文显示乱码**  
A: 浏览器 charset 强制 UTF-8 (一般不会有问题, Chrome/Safari 都默认 UTF-8)
