# 云托管静态卡图服务

这个目录用于微信云托管部署卡图静态服务。

## 提供的访问路径
- 健康检查：`/healthz`
- 缩略图目录：`/cards/thumbs/<card-id>.webp`

## 本地目录依赖
- 原始卡图目录：`../cloud-assets/cards`
- 部署目录：`./public/cards`

## 部署前准备
1. 在 `cloud-hosting` 目录运行：

```powershell
.\sync-assets.ps1
```

2. 运行完成后，只会把 `../cloud-assets/cards/thumbs` 复制为 `./public/cards/thumbs/<card-id>.webp`
3. 云托管部署时直接选择 `cloud-hosting` 目录即可

## 部署后如何给小程序使用
1. 在云托管控制台拿到服务域名，例如：`https://your-service.run.tcloudbase.com`
2. 修改 `src/config/cardAssets.ts`：

```ts
const CARD_ASSET_BASE_URL = "https://your-service.run.tcloudbase.com";
```

3. 重新执行：

```bash
npm run build:mp-weixin
```

## 验证
- 访问：
  - `/healthz`
  - `/cards/thumbs/face-s01_0106.webp`
- 若能打开，说明卡图服务已接通。

## 当前方案说明
- 为了绕开云托管单次上传 `512 MiB` 限制，当前只部署缩略图资源。
- 小程序中的列表、详情、卡组封面统一使用缩略图展示。
- 为了绕开云托管解压中文文件名乱码冲突，当前云端缩略图统一使用 `card.id.webp` 这种 ASCII 文件名。
