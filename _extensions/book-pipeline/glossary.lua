--[[
Glossary Filter for Quarto Book Pipeline
Processes [[term]] syntax and generates glossary

Usage:
- [[DevRel]] - First mention: creates link with tooltip
- [[DevRel]] - Subsequent mentions: plain text
- Generates glossary section at document end

YAML Format (glossary/terms.yml):
terms:
  - term: "DevRel"
    definition: "Developer Relations"
    synonyms: ["Developer Relations"]
]]

-- Simple YAML parser for basic glossary format
local function parse_yaml(content)
    local terms = {}
    local in_terms = false
    local current_term = nil
    
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$") -- trim whitespace
        
        if line == "terms:" then
            in_terms = true
        elseif in_terms and line:match("^%- term:") then
            if current_term then
                table.insert(terms, current_term)
            end
            current_term = {
                term = line:match('term: "([^"]+)"'),
                definition = "",
                synonyms = {}
            }
        elseif current_term and line:match('^definition:') then
            current_term.definition = line:match('definition: "([^"]+)"') or ""
        elseif current_term and line:match('^synonyms:') then
            -- Handle synonyms array (simplified)
            local synonyms_str = line:match('synonyms: %[([^%]]+)%]')
            if synonyms_str then
                for synonym in synonyms_str:gmatch('"([^"]+)"') do
                    table.insert(current_term.synonyms, synonym)
                end
            end
        end
    end
    
    if current_term then
        table.insert(terms, current_term)
    end
    
    return { terms = terms }
end

-- Global state for tracking first mentions
local first_mentions = {}
local glossary_terms = {}
local glossary_loaded = false

-- Load glossary from YAML file
local function load_glossary()
    if glossary_loaded then
        return
    end
    
    local glossary_file = "glossary/terms.yml"
    local file = io.open(glossary_file, "r")
    
    if not file then
        -- Try alternative paths
        local alt_paths = {
            "glossary/terms.yml",
            "./glossary/terms.yml",
            "../glossary/terms.yml"
        }
        
        for _, path in ipairs(alt_paths) do
            file = io.open(path, "r")
            if file then
                glossary_file = path
                break
            end
        end
    end
    
    if not file then
        print("Warning: glossary/terms.yml not found. Glossary features disabled.")
        glossary_loaded = true
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local data = parse_yaml(content)
    if not data then
        print("Warning: Failed to parse glossary/terms.yml")
        glossary_loaded = true
        return
    end
    
    if data and data.terms then
        for _, term_data in ipairs(data.terms) do
            if term_data.term and term_data.definition then
                glossary_terms[term_data.term] = {
                    definition = term_data.definition,
                    synonyms = term_data.synonyms or {}
                }
            end
        end
    end
    
    glossary_loaded = true
    local count = 0
    for _ in pairs(glossary_terms) do count = count + 1 end
    print("Loaded " .. count .. " glossary terms")
end

-- Check if a term exists in glossary
local function is_glossary_term(term)
    load_glossary()
    return glossary_terms[term] ~= nil
end

-- Get term definition
local function get_term_definition(term)
    load_glossary()
    local term_data = glossary_terms[term]
    return term_data and term_data.definition or term
end

-- Check if this is the first mention of a term
local function is_first_mention(term)
    return not first_mentions[term]
end

-- Mark term as mentioned
local function mark_as_mentioned(term)
    first_mentions[term] = true
end

-- Create HTML link for first mention
local function create_html_link(term, definition)
    return {
        pandoc.Link(
            { pandoc.Str(term) },
            "#glossary-" .. term:lower():gsub("%s+", "-"),
            "",
            { title = definition }
        )
    }
end

-- Create PDF footnote for first mention
local function create_pdf_footnote(term, definition)
    return {
        pandoc.Str(term),
        pandoc.Note({ pandoc.Str(definition) })
    }
end

-- Process text nodes for [[term]] patterns
local function process_text(text)
    local result = {}
    local remaining = text
    
    while remaining do
        local start, term, rest = remaining:match("(.*)%[%[([^%]]+)%]%](.*)")
        
        if not start then
            table.insert(result, pandoc.Str(remaining))
            break
        end
        
        -- Add text before the term
        if start ~= "" then
            table.insert(result, pandoc.Str(start))
        end
        
        -- Process the term
        if is_glossary_term(term) then
            local definition = get_term_definition(term)
            
            if is_first_mention(term) then
                mark_as_mentioned(term)
                -- Create appropriate link based on format
                local link = create_html_link(term, definition)
                for _, elem in ipairs(link) do
                    table.insert(result, elem)
                end
            else
                -- Subsequent mentions: plain text
                table.insert(result, pandoc.Str(term))
            end
        else
            -- Not a glossary term, keep as plain text
            table.insert(result, pandoc.Str("[[" .. term .. "]]"))
        end
        
        remaining = rest
    end
    
    return result
end

-- Process different element types
local function process_element(elem)
    if elem.t == "Str" then
        local processed = process_text(elem.text)
        if #processed == 1 and processed[1].t == "Str" then
            return processed[1]
        else
            return processed
        end
    elseif elem.t == "Para" then
        local new_content = {}
        for _, inline in ipairs(elem.content) do
            local processed = process_element(inline)
            if type(processed) == "table" then
                for _, item in ipairs(processed) do
                    table.insert(new_content, item)
                end
            else
                table.insert(new_content, processed)
            end
        end
        return pandoc.Para(new_content)
    elseif elem.t == "Plain" then
        local new_content = {}
        for _, inline in ipairs(elem.content) do
            local processed = process_element(inline)
            if type(processed) == "table" then
                for _, item in ipairs(processed) do
                    table.insert(new_content, item)
                end
            else
                table.insert(new_content, processed)
            end
        end
        return pandoc.Plain(new_content)
    else
        return elem
    end
end

-- Generate glossary section
local function generate_glossary()
    load_glossary()
    
    if not next(glossary_terms) then
        return {}
    end
    
    -- Sort terms alphabetically
    local sorted_terms = {}
    for term, _ in pairs(glossary_terms) do
        table.insert(sorted_terms, term)
    end
    table.sort(sorted_terms)
    
    local glossary_content = {}
    
    -- Add glossary header
    table.insert(glossary_content, pandoc.Header(1, { pandoc.Str("Glossary") }))
    
    -- Add terms
    for _, term in ipairs(sorted_terms) do
        local term_data = glossary_terms[term]
        local definition = term_data.definition
        
        -- Create term with anchor for HTML
        local term_element = pandoc.Span(
            { pandoc.Str(term) },
            { id = "glossary-" .. term:lower():gsub("%s+", "-") }
        )
        
        -- Create definition paragraph
        local def_para = pandoc.Para({
            term_element,
            pandoc.Str(": "),
            pandoc.Str(definition)
        })
        
        table.insert(glossary_content, def_para)
    end
    
    return glossary_content
end

-- Main filter function
function Pandoc(doc)
    -- Process all elements
    local new_blocks = {}
    
    for _, block in ipairs(doc.blocks) do
        local processed = process_element(block)
        if type(processed) == "table" then
            for _, item in ipairs(processed) do
                table.insert(new_blocks, item)
            end
        else
            table.insert(new_blocks, processed)
        end
    end
    
    -- Add glossary at the end
    local glossary = generate_glossary()
    for _, item in ipairs(glossary) do
        table.insert(new_blocks, item)
    end
    
    return pandoc.Pandoc(new_blocks, doc.meta)
end