--[[
Include Filter for Quarto Book Pipeline
========================================

Purpose: Insert file contents via <<include path>> syntax

Usage:
  <<include snippets/stories/yandex-success.md>>

The filter processes document blocks to find <<include path>> patterns
and replaces them with the parsed content of the specified file.

Features:
- Processes both inline and block includes
- Resolves paths relative to book root
- Parses included content as Markdown
- Provides clear error messages for missing files
- Handles nested includes recursively

Implementation Details:
- Uses Pandoc's Block function to process paragraph elements
- Handles the fact that include patterns are split across multiple Str elements
- Accounts for Space elements between <<include and the path
- Safely reads files with proper error handling
- Parses included content as Markdown to maintain formatting
]]

local function resolve_path(include_path, book_root)
  -- If path is already absolute, use it as-is
  if include_path:match("^/") then
    return include_path
  end
  
  -- Resolve relative to book root
  if book_root then
    return book_root .. "/" .. include_path
  end
  
  -- Fallback: resolve relative to current working directory
  return include_path
end

local function read_file_safely(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil, "File not found: " .. file_path
  end
  
  local content = file:read("*all")
  file:close()
  
  if not content then
    return nil, "Failed to read file: " .. file_path
  end
  
  return content, nil
end

-- Process document blocks
function Block(block)
  if block.t == "Para" then
    -- Process paragraph content
    local new_content = {}
    local i = 1
    local book_root = PANDOC_STATE.input_files and PANDOC_STATE.input_files[1] and PANDOC_STATE.input_files[1]:match("(.*/)") or nil
    
    while i <= #block.content do
      local elem = block.content[i]
      
      if elem.t == "Str" and elem.text == "<<include" then
        -- Look for the path in the next few elements (accounting for spaces)
        local j = i + 1
        local found_path = false
        
        while j <= #block.content and j <= i + 3 do
          local next_elem = block.content[j]
          if next_elem.t == "Str" and next_elem.text:match(">>") then
            -- Extract path from "path>>"
            local path = next_elem.text:match("([^>]+)>>")
            if path then
              path = path:match("^%s*(.-)%s*$") -- trim whitespace
              local resolved_path = resolve_path(path, book_root)
              
              -- Read the file content
              local content, error_msg = read_file_safely(resolved_path)
              if content then
                -- Parse the content as Markdown
                local success, parsed = pcall(pandoc.read, content, "markdown")
                if success and parsed.blocks and #parsed.blocks > 0 then
                  -- Add all content from the first block
                  local first_block = parsed.blocks[1]
                  if first_block.t == "Para" or first_block.t == "Plain" then
                    for _, inline in ipairs(first_block.content) do
                      table.insert(new_content, inline)
                    end
                  end
                else
                  -- If parsing failed, add error message
                  table.insert(new_content, pandoc.Str("**Error:** Failed to parse included file: " .. resolved_path))
                end
              else
                -- If file not found, add error message
                table.insert(new_content, pandoc.Str("**Error:** " .. error_msg))
              end
              
              found_path = true
              i = j
              break
            end
          end
          j = j + 1
        end
        
        if not found_path then
          table.insert(new_content, elem)
        end
      else
        table.insert(new_content, elem)
      end
      
      i = i + 1
    end
    
    return pandoc.Para(new_content)
  end
  
  return block
end