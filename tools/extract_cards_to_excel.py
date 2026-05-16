#!/usr/bin/env python3
"""
卡牌数据提取工具
从cards.json中提取卡牌信息并生成Excel表格
"""

import json
import pandas as pd
from pathlib import Path

def load_cards_data(json_path):
    """加载卡牌JSON数据"""
    with open(json_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def process_cards_to_dataframe(cards):
    """将卡牌数据转换为pandas DataFrame"""
    processed_data = []

    for card in cards:
        # 展开source字段
        source_file = card.get('source', {}).get('file', '')
        source_code = card.get('source', {}).get('code', '')

        # 将tags数组转换为字符串
        tags_str = ', '.join(card.get('tags', []))

        # 将alias数组转换为字符串
        alias_str = ', '.join(card.get('alias', []))

        # 将faqIds数组转换为字符串
        faq_ids_str = ', '.join(card.get('faqIds', []))

        processed_card = {
            '卡牌ID': card.get('id', ''),
            '卡牌名称': card.get('name', ''),
            '别名': alias_str,
            '系列': card.get('series', ''),
            '卡牌编号': card.get('cardNo', ''),
            '稀有度': card.get('rarity', ''),
            '费用': card.get('cost', ''),
            '攻击力': card.get('attack', ''),
            '生命值': card.get('health', ''),
            '卡牌类型': card.get('type', ''),
            '子类型': card.get('subType', ''),
            '阵营': card.get('faction', ''),
            '标签': tags_str,
            '效果文本': card.get('effectText', ''),
            '背景文本': card.get('flavorText', ''),
            '搜索文本': card.get('searchText', ''),
            'FAQ IDs': faq_ids_str,
            '已验证': card.get('verified', False),
            '来源文件': source_file,
            '来源代码': source_code,
            '图片路径': card.get('image', '')
        }

        processed_data.append(processed_card)

    return pd.DataFrame(processed_data)

def export_to_excel(df, output_path):
    """导出到Excel文件"""
    # 创建Excel writer对象
    with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
        # 导出主数据表
        df.to_excel(writer, sheet_name='所有卡牌', index=False)

        # 按阵营创建多个sheet
        factions = df['阵营'].unique()
        for faction in factions:
            if faction:  # 跳过空阵营
                faction_df = df[df['阵营'] == faction]
                sheet_name = f"{faction}阵营"[:31]  # Excel sheet名称限制31字符
                faction_df.to_excel(writer, sheet_name=sheet_name, index=False)

        # 按卡牌类型创建sheet
        card_types = df['卡牌类型'].unique()
        for card_type in card_types:
            if card_type:  # 跳过空类型
                type_df = df[df['卡牌类型'] == card_type]
                sheet_name = f"{card_type}卡牌"[:31]
                type_df.to_excel(writer, sheet_name=sheet_name, index=False)

def main():
    """主函数"""
    # 定义路径
    project_root = Path(__file__).parent.parent
    json_file = project_root / "规则" / "h5-app" / "public" / "data" / "cards.json"
    output_file = project_root / "cards_database.xlsx"

    print(f"正在读取卡牌数据: {json_file}")

    # 加载数据
    try:
        cards = load_cards_data(json_file)
        print(f"成功加载 {len(cards)} 张卡牌")
    except FileNotFoundError:
        print(f"错误: 找不到文件 {json_file}")
        return
    except json.JSONDecodeError as e:
        print(f"错误: JSON解析失败 - {e}")
        return

    # 转换为DataFrame
    df = process_cards_to_dataframe(cards)

    # 显示统计信息
    print(f"\n卡牌统计:")
    print(f"总卡牌数: {len(df)}")
    print(f"阵营分布:")
    for faction, count in df['阵营'].value_counts().items():
        print(f"  {faction}: {count}张")
    print(f"卡牌类型分布:")
    for card_type, count in df['卡牌类型'].value_counts().items():
        print(f"  {card_type}: {count}张")

    # 导出到Excel
    print(f"\n正在导出到Excel: {output_file}")
    try:
        export_to_excel(df, output_file)
        print(f"成功! Excel文件已保存到: {output_file}")
        print(f"\n包含的工作表:")
        print(f"- 所有卡牌 (全部卡牌)")
        print(f"- 按阵营分类 (多个sheet)")
        print(f"- 按卡牌类型分类 (多个sheet)")
    except Exception as e:
        print(f"导出失败: {e}")

if __name__ == "__main__":
    main()