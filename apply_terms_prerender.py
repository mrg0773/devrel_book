#!/usr/bin/env python3
"""
Применяет замену терминов <TERM:xxx>> перед рендерингом
Pre-render hook для Quarto
"""

import re
import yaml
from pathlib import Path
import shutil

def main():
    # Читаем словарь терминов
    glossary_file = Path("glossary/terms.yml")
    
    if not glossary_file.exists():
        print(f"Ошибка: {glossary_file} не найден")
        return 1
    
    with open(glossary_file, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
    
    # Создаем словарь замен
    terms_dict = {}
    for item in data.get('terms', []):
        term_key = item['term']
        term_value = item['definition']
        terms_dict[term_key] = term_value
    
    # Директория исходников
    source_dir = Path("Черновики глав")
    temp_dir = Path("_temp_build")
    
    # Создаем временную директорию
    temp_dir.mkdir(exist_ok=True)
    
    # Обрабатываем файлы из _quarto.yml
    # Обрабатываем все .md файлы из source_dir
    source_files = list(source_dir.glob("*.md"))
    
    # Фильтруем только те файлы которые нужны для книги
    # Пропускаем архивы, бэкапы, combined-book, test и т.д.
    skip_patterns = ['combined-book', 'База_DevRel', '_OLD', 'test_', '_archive', '_backup']
    
    replaced_total = 0
    files_processed = 0
    dashes_replaced = 0
    
    for source_file in source_files:
        # Проверяем что файл нужно обрабатывать
        if any(skip in source_file.name for skip in skip_patterns):
            continue
        
        with open(source_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Заменяем термины
        original_content = content
        
        def replace_term(match):
            term_key = match.group(1)
            if term_key in terms_dict:
                return terms_dict[term_key]
            else:
                # Оставляем как есть если термин не найден
                return match.group(0)
        
        # Паттерн для замены <TERM:xxx>>
        content = re.sub(r'<TERM:([^>]+)>>', replace_term, content)
        
        # Заменяем двойные дефисы -- на длинное тире —
        # Делаем это только вне блоков кода
        parts = content.split('```')
        for i in range(len(parts)):
            # Четные индексы - это текст, нечетные - код
            if i % 2 == 0:
                parts[i] = parts[i].replace('--', '—')
        content = '```'.join(parts)
        
        # Подсчитываем замены
        replacements = len(re.findall(r'<TERM:[^>]+>>', original_content)) - len(re.findall(r'<TERM:[^>]+>>', content))
        replaced_total += replacements
        
        # Сохраняем в _temp_build
        temp_file = temp_dir / source_file.name
        with open(temp_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        files_processed += 1
    
    print(f"✅ Обработано {files_processed} файлов, заменено {replaced_total} терминов и {dashes_replaced} дефисов")
    print(f"   Временные файлы: {temp_dir}/")
    
    return 0

if __name__ == '__main__':
    exit(main())

