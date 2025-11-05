#!/usr/bin/env python3
"""
Очистка временных файлов после рендеринга
Post-render hook для Quarto
"""

import shutil
from pathlib import Path

def main():
    temp_dir = Path("_temp_build")
    
    # НЕ удаляем файлы! Они нужны Quarto для рендеринга
    # Очистка происходит автоматически при следующей сборке
    
    print(f"ℹ️  Временные файлы в {temp_dir}/ оставлены для использования")
    print(f"   Они будут перезаписаны при следующей сборке")
    
    return 0

if __name__ == '__main__':
    exit(main())

