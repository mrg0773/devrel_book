#!/usr/bin/env python3
"""
Синхронизация glossary/terms.yml → СЛОВАРЬ_ТЕРМИНОВ.json
Pre-render hook для Quarto
"""

import json
import yaml
from pathlib import Path

def main():
    # Читаем glossary/terms.yml
    glossary_file = Path("glossary/terms.yml")
    
    if not glossary_file.exists():
        print(f"Ошибка: {glossary_file} не найден")
        return 1
    
    with open(glossary_file, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
    
    # Создаем словарь для JSON
    terms_dict = {}
    for item in data.get('terms', []):
        term_key = item['term']
        term_value = item['definition']
        terms_dict[term_key] = term_value
    
    # Сохраняем в JSON
    output_file = Path("СЛОВАРЬ_ТЕРМИНОВ.json")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(terms_dict, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Синхронизировано {len(terms_dict)} терминов: {glossary_file} → {output_file}")
    return 0

if __name__ == '__main__':
    exit(main())

