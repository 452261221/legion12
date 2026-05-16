# Asset Pipeline

这个目录负责把当前根目录中的 PDF、Excel、Word 和图片资料整理成查卡器可消费的数据资产。

## 第一阶段目标

- 扫描现有资料并生成资产清单
- 输出首版提取计划，明确每个文件后续要走的处理步骤
- 为下一步 `PDF -> 分页 -> 裁剪 -> OCR/抽文本 -> 结构化` 铺好目录和脚本入口

## 当前可运行入口

```bash
python scripts/run_pipeline.py
python scripts/export_sample_data.py
python scripts/extract_card_images.py --pdf 5.pdf --start-page 1 --end-page 3
```

运行后会生成：

- `data/processed/manifest.json`
- `data/processed/extraction-plan.json`
- `data/processed/cards.sample.json`
- `data/processed/faq.sample.json`
- `data/processed/<pdf-name>-crop-report.json`

## 下一步

- 在 `src/pdf` 中补 PDF 分页和文本抽取
- 在 `src/image` 中补卡图裁剪
- 在 `src/ocr` 中补 OCR 适配
- 在 `src/normalize` 中补字段清洗和结构化导出
