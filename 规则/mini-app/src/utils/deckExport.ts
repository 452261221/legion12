import type { Card } from "@/types";
import { resolveCardImage } from "@/utils/cardImage";

export interface ExportDeckCardRow {
  count: number;
  card?: Card;
}

export interface ExportDeckPayload {
  id: string;
  name: string;
  description: string;
  totalCount: number;
  summary: string;
  resolvedCards: ExportDeckCardRow[];
}

export const DECK_EXPORT_CANVAS_WIDTH = 644;

function getCanvasHeight(rowCount: number) {
  const cardHeight = 252;
  const gap = 20;
  const padding = 32;
  const headerHeight = 160;

  return headerHeight + padding * 2 + rowCount * (cardHeight + 72) + Math.max(0, rowCount - 1) * gap;
}

export function getDeckExportCanvasHeight(cardRowCount: number) {
  const columns = 3;
  const rowCount = Math.max(1, Math.ceil(cardRowCount / columns));
  return getCanvasHeight(rowCount);
}

export function buildDeckCode(resolvedCards: ExportDeckCardRow[]): string {
  return resolvedCards
    .flatMap((item) => {
      const cardNo = item.card?.cardNo?.trim();
      if (!cardNo) {
        return [];
      }

      return Array.from({ length: item.count }, () => cardNo);
    })
    .join(" ");
}

function getImageInfo(src: string) {
  return new Promise<UniApp.GetImageInfoSuccessData>((resolve, reject) => {
    uni.getImageInfo({
      src,
      success: resolve,
      fail: () => reject(new Error(`图片加载失败：${src}`))
    });
  });
}

function drawCanvas(context: UniApp.CanvasContext) {
  return new Promise<void>((resolve) => {
    context.draw(false, () => resolve());
  });
}

function canvasToTempFilePath(canvasId: string, width: number, height: number) {
  return new Promise<string>((resolve, reject) => {
    uni.canvasToTempFilePath({
      canvasId,
      x: 0,
      y: 0,
      width,
      height,
      destWidth: width * 2,
      destHeight: height * 2,
      fileType: "png",
      success: (result) => resolve(result.tempFilePath),
      fail: () => reject(new Error("导出图片失败。"))
    });
  });
}

export async function saveImageToAlbum(filePath: string) {
  return new Promise<void>((resolve, reject) => {
    uni.saveImageToPhotosAlbum({
      filePath,
      success: () => resolve(),
      fail: (error) => {
        const message = typeof error?.errMsg === "string" ? error.errMsg : "";
        if (message.includes("auth deny") || message.includes("authorize")) {
          reject(new Error("保存图片失败，请允许保存到相册权限后重试。"));
          return;
        }
        reject(new Error("保存图片到相册失败。"));
      }
    });
  });
}

export async function exportDeckOverview(row: ExportDeckPayload, canvasId: string) {
  if (!row.resolvedCards.length) {
    throw new Error("当前卡组暂无可导出的卡牌。");
  }

  const cardWidth = 180;
  const cardHeight = 252;
  const columns = 3;
  const gap = 20;
  const padding = 32;
  const headerHeight = 160;
  const rowCount = Math.ceil(row.resolvedCards.length / columns);
  const canvasWidth = DECK_EXPORT_CANVAS_WIDTH;
  const canvasHeight = getCanvasHeight(rowCount);

  const context = uni.createCanvasContext(canvasId);
  const gradient = context.createLinearGradient(0, 0, canvasWidth, canvasHeight);
  gradient.addColorStop(0, "#0b1f39");
  gradient.addColorStop(1, "#071321");
  context.setFillStyle(gradient);
  context.fillRect(0, 0, canvasWidth, canvasHeight);

  context.setFillStyle("#f7f0d0");
  context.setFontSize(32);
  context.fillText(row.name, padding, 54);

  context.setFillStyle("#f1dd98");
  context.setFontSize(20);
  context.fillText(`共 ${row.totalCount} 张`, padding, 92);

  context.setFillStyle("#c7d0dd");
  context.setFontSize(18);
  const description = (row.description || row.summary || "").slice(0, 64);
  const descLines = [description.slice(0, 32), description.slice(32, 64)].filter(Boolean);
  descLines.forEach((line, index) => {
    context.fillText(line, padding, 124 + index * 26);
  });

  const images = await Promise.all(
    row.resolvedCards.map(async (item) => ({
      item,
      imagePath: await getImageInfo(resolveCardImage(item.card!)).then((result) => result.path)
    }))
  );

  images.forEach(({ item, imagePath }, index) => {
    const column = index % columns;
    const rowIndex = Math.floor(index / columns);
    const x = padding + column * (cardWidth + gap);
    const y = headerHeight + padding + rowIndex * (cardHeight + 72 + gap);

    context.drawImage(imagePath, x, y, cardWidth, cardHeight);
    context.setFillStyle("#f7f0d0");
    context.setFontSize(18);
    context.fillText(item.card!.name.slice(0, 10), x, y + cardHeight + 24);
    context.setFillStyle("#c7d0dd");
    context.setFontSize(16);
    context.fillText(`${item.card!.type} / ${item.card!.faction}`.slice(0, 14), x, y + cardHeight + 48);
    context.setFillStyle("#f1dd98");
    context.setFontSize(18);
    context.fillText(`×${item.count}`, x + cardWidth - 30, y + cardHeight + 24);
  });

  await drawCanvas(context);
  return canvasToTempFilePath(canvasId, canvasWidth, canvasHeight);
}
