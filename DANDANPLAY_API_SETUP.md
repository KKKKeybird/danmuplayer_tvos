# DanDanPlay API 配置指南

## 📋 概述

本项目使用 DanDanPlay API 提供弹幕服务。为了保护 API 密钥安全，我们将敏感信息单独存储在不会被版本控制的文件中。

## 🔑 配置步骤

### 1. 申请 API 密钥

- **申请地址**：https://doc.dandanplay.com/open/#_3-%E7%94%B3%E8%AF%B7-appid-%E5%92%8C-appsecret
- **申请邮箱**：kaedei@dandanplay.net
- **邮件标题**：弹弹play开放平台申请
- **邮件内容**：说明您的应用用途（如：tvOS弹幕播放器应用开发）

### 2. 创建配置文件

1. 复制模板文件：
   ```bash
   cp danmuplayer/Utilities/Config/DanDanPlaySecrets.swift.template danmuplayer/Utilities/Config/DanDanPlaySecrets.swift
   ```

2. 编辑 `DanDanPlaySecrets.swift` 文件：
   ```swift
   struct DanDanPlaySecrets {
       static let appId: String = "你的AppId"        // 替换为实际的AppId
       static let appSecret: String = "你的AppSecret"   // 替换为实际的AppSecret
   }
   ```

### 3. 验证配置

构建项目时，如果配置不正确，会在运行时显示相应的错误信息。

## 🛡️ 安全说明

- `DanDanPlaySecrets.swift` 文件已被添加到 `.gitignore`，不会被提交到版本控制
- 请确保不要将真实的 API 密钥提交到公开仓库
- 发布应用前建议对代码进行混淆处理

## 📁 文件结构

```
danmuplayer/Utilities/Config/
├── DanDanPlayConfig.swift          # 主配置文件（安全，可提交）
├── DanDanPlaySecrets.swift         # 敏感信息文件（不会被提交）
└── DanDanPlaySecrets.swift.template # 模板文件（提供给其他开发者）
```

## ❗ 常见问题

### Q: 编译时提示找不到 `DanDanPlaySecrets`？
A: 请确保您已按步骤2创建了 `DanDanPlaySecrets.swift` 文件。

### Q: 运行时提示 API 配置无效？
A: 请检查 `DanDanPlaySecrets.swift` 中的 AppId 和 AppSecret 是否正确配置。

### Q: 如何检查配置是否正确？
A: 可以使用 `DanDanPlayConfig.validateConfiguration()` 方法验证配置有效性。
