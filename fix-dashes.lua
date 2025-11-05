-- Фильтр для правильной конвертации длинного тире в LaTeX
-- Заменяет — на \textemdash{} вместо -\/-

function RawInline(el)
  if el.format == 'latex' then
    -- Заменяем -\/- на настоящее длинное тире
    el.text = el.text:gsub('%-\\/%- ', '\\textemdash{} ')
    el.text = el.text:gsub('%-\\/-', '\\textemdash{}')
  end
  return el
end

function Str(el)
  -- Для формата latex заменяем — на \textemdash
  if FORMAT == 'latex' then
    if el.text:match('—') then
      return pandoc.RawInline('latex', '\\textemdash{}')
    end
  end
  return el
end

return {
  {Str = Str},
  {RawInline = RawInline}
}

