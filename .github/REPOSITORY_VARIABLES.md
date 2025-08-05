# Repository Variables 配置指南

本项目使用 GitHub Repository Variables 来管理配置参数，特别是 DanDanPlay API 密钥用于 CI/CD 测试。

## 配置步骤

1. 进入 GitHub 仓库页面
2. 点击 `Settings` 标签
3. 在左侧菜单中选择 `Secrets and variables` > `Actions`
4. 点击 `Variables` 标签
5. 点击 `New repository variable` 按钮

## 必需的 Variables

### DanDanPlay API 配置
- **DANDANPLAY_APP_ID**: 你的 DanDanPlay API 应用ID
- **DANDANPLAY_APP_SECRET**: 你的 DanDanPlay API 应用密钥

### 可选的 Variables

#### 构建环境配置
- **MACOS_RUNNER**: GitHub Actions 运行器版本 (默认: `macos-14`)
- **XCODE_VERSION**: Xcode 版本 (默认: `15.3`)
- **SWIFT_VERSION**: Swift 版本 (默认: `5.9`)
- **DEVELOPER_DIR**: Xcode 开发者目录 (默认: `/Applications/Xcode_15.3.app/Contents/Developer`)

#### 测试配置
- **TEST_TIMEOUT**: 测试超时时间(秒) (默认: `300`)

#### 其他配置
- **TVOS_VERSION**: tvOS 最低支持版本 (默认: `17.0`)
- **DANDANPLAY_CONTACT_EMAIL**: DanDanPlay 联系邮箱 (默认: `kaedei@dandanplay.net`)

## API 密钥申请

如需申请 DanDanPlay API 密钥，请联系：
- 邮箱：kaedei@dandanplay.net
- 说明：申请 DanmuPlayer tvOS 应用的 API 使用权限

## 使用说明

### 完整测试（包含 API 集成）
当配置了 `DANDANPLAY_APP_ID` 和 `DANDANPLAY_APP_SECRET` 时，CI/CD 将：
- 自动替换测试配置文件中的 API 密钥
- 运行完整的测试套件，包括 API 集成测试
- 测试完成后自动清理配置，恢复占位符

### 基础测试（跳过 API 集成）
当未配置 API 密钥时，CI/CD 将：
- 跳过需要 API 密钥的测试
- 仅运行基础功能测试
- 显示配置提示信息

## 安全性说明

- Repository Variables 对所有可以访问仓库的用户可见
- 敏感信息（如 API 密钥）应该使用 Secrets 而不是 Variables
- 但由于需要在 workflow 中进行字符串替换，API 密钥暂时使用 Variables
- 请确保仓库访问权限设置合理

## 示例配置

```
DANDANPLAY_APP_ID=your_app_id_here
DANDANPLAY_APP_SECRET=your_app_secret_here
XCODE_VERSION=15.3
SWIFT_VERSION=5.9
MACOS_RUNNER=macos-14
TEST_TIMEOUT=300
```

## 故障排除

### 测试失败
1. 检查 API 密钥是否正确配置
2. 确认 API 密钥是否有效
3. 检查网络连接是否正常

### 构建失败
1. 检查 Xcode 版本配置
2. 确认 Swift 版本兼容性
3. 检查依赖项缓存是否正常

### 环境问题
1. 确认运行器版本支持所需的 Xcode 版本
2. 检查开发者目录路径是否正确
3. 验证超时设置是否合理
