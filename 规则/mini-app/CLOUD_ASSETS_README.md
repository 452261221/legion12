# 卡图上云说明

## 目录约定
- 将当前 `cloud-assets/cards` 目录整体上传到你的对象存储或 CDN 根目录下。
- 上传后保持原有目录结构不变：
  - `cards/faces/...`
  - `cards/thumbs/...`

## 配置位置
- 打开 `src/config/cardAssets.ts`
- 将 `CARD_ASSET_BASE_URL` 改成你的 HTTPS 资源根地址，例如：

```ts
const CARD_ASSET_BASE_URL = "https://cdn.example.com/legion-assets";
```

- 最终图片地址会按下面规则自动拼接：
  - 原图：`https://cdn.example.com/legion-assets/cards/faces/...`
  - 缩略图：`https://cdn.example.com/legion-assets/cards/thumbs/...`

## 微信后台
- 在微信公众平台为该域名配置下载合法域名。
- 如果使用 CDN，自定义域名需要 HTTPS。

## 重新发布
- 修改完 `src/config/cardAssets.ts` 后，重新执行：

```bash
npm run build:mp-weixin
```

