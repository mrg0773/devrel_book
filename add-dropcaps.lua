-- Автоматическое добавление буквиц (drop caps) в начале глав

local chapter_started = false

function Header(el)
  if el.level == 1 then
    -- Это заголовок главы (# Глава X)
    chapter_started = true
    io.stderr:write("📖 Глава началась: " .. pandoc.utils.stringify(el) .. "\n")
  end
  return el
end

function Para(el)
  if chapter_started and el.content and #el.content > 0 then
    -- Это первый параграф после заголовка главы
    local text = pandoc.utils.stringify(el)
    
    -- Пропускаем пустые параграфы и технические блоки
    if text:match("^%s*$") or text:match("^Зачем эта глава") or text:match("^%*%*") then
      return el
    end
    
    -- Получаем первую букву
    local first_char = text:sub(1, 1)
    
    -- Проверяем что это буква (кириллица или латиница)
    if first_char:match("[А-ЯЁA-Z]") then
      io.stderr:write("✨ Добавляю буквицу: " .. first_char .. "\n")
      
      -- Создаем LaTeX команду для буквицы
      local rest_of_first_word = ""
      local rest_of_text = text
      
      -- Извлекаем остаток первого слова
      local first_word = text:match("^(%S+)")
      if first_word and #first_word > 1 then
        rest_of_first_word = first_word:sub(2)
        rest_of_text = text:sub(#first_word + 1)
      else
        rest_of_text = text:sub(2)
      end
      
      -- Формируем LaTeX код
      local latex_code = string.format(
        "\\lettrine{%s}{%s}%s",
        first_char,
        rest_of_first_word,
        rest_of_text
      )
      
      -- Сбрасываем флаг
      chapter_started = false
      
      -- Возвращаем как RawBlock
      return pandoc.RawBlock('latex', latex_code)
    end
    
    chapter_started = false
  end
  
  return el
end

return {
  {Header = Header},
  {Para = Para}
}

