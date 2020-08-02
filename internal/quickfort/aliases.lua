-- alias expansion logic for the quickfort script query module
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log

-- special key sequences inherited from python quickfort. these cannot be
-- overridden with aliases
local specials = {
    ['&']='Enter',
    ['+']='{Shift}',
    ['@']={'{Shift}','Enter'},
    ['^']='ESC',
    ['{ExitMenu}']='ESC',
    ['%']='{Wait}'
}

local alias_stack = {}

function reset_aliases()
    alias_stack = {}
end

-- pushes a file of aliases on the stack. aliases are resolved with the
-- definition nearest the top of the stack.
function push_aliases_csv_file(filename)
    local file = io.open(filename)
    if not file then
        log('aliases file not found: "%s"', filename)
        return
    end
    local aliases = {}
    for line in file:lines() do
        line = line:gsub('[\r\n]*$', '')
        _, _, alias, definition = line:find('^([%w]+):%s*(.*)')
        if alias and #definition > 0 then
            log('found alias: "%s" -> "%s"', alias, definition)
            aliases[alias] = definition
        end
    end
    log('successfully read in aliases from "%s"', filename)
    local prev = alias_stack
    setmetatable(aliases, {__index=function(_, key) return prev[key] end})
    alias_stack = aliases
end

local function process_text(text, tokens, depth)
    if depth > 50 then
        qerror(string.format('alias resolution maximum depth exceeded (%d)',
                             depth))
    end
    local i = 1
    while i <= #text do
        local next_char = text:sub(i, i)
        log('processing next character: "%s"', next_char)
        local token, expansion, repititions = next_char, {}, 1
        if next_char ~= '{' then
            -- token is a sepcial key or a key literal
            expansion[1] = specials[token] or token
        else
            -- find the next closing bracket, skipping one space to allow for
            -- '{}}' and it's kin
            local b, e, extended_token = text:find('{(.[^}]*)}', i)
            if not extended_token then
                qerror(string.format(
                        'invalid extended token: "%s"; did you mean "{{}"?',
                        text:sub(i)))
            end
            log('matched extended token: "%s"', extended_token)
            local _, _, rep_tok, rep_rep = extended_token:find('(.-)%s+(%d+)$')
            if rep_tok then
                token = rep_tok
                repititions = rep_rep
            end
            if token == 'Numpad' and repititions then
                token = string.format('%s %d', token, repititions)
            end
            log('found token: "%s" with repitition count: "%s"',
                token, tostring(repititions))
            if not repititions then repititions = 1 end
            if alias_stack[token] then
                log('expanding alias')
                process_text(alias_stack[token], expansion, depth+1)
            else
                expansion[1] = token
            end
            i = i + #extended_token + 1
        end
        for j=1,repititions do
            log('adding tokens: "%s"', table.concat(expansion, ''))
            for k=1, #expansion do
                tokens[#tokens+1] = expansion[k]
            end
        end
        i = i + 1
    end
end

-- expands aliases in a string and returns the individual key tokens.
-- if the entirety of text matches an alias, expands the entire text as an alias
-- otherwise, if the text contains a substring like '{alias}', matches the alias
-- between the curly brackets and replaces the substring. Aliases themselves
-- can contain other aliases, but must use the {} format if they do. Literal
-- key names can also appear in curly brackets to allow the parser to recognize
-- multi-character keys, such as '{F10}'. Anything in curly brackets can be
-- followed by a number to indicate repitition. For example, '{Down 5}'
-- indicates 'Down' 5 times. 'Numpad' is treated specially so that '{Numpad 8}'
-- doesn't get expanded to 'Numpad' 8 times, but rather 'Numpad 8' once. You can
-- repeat Numpad keys like this: '{Numpad 8 5}'.
-- returns an array of character key tokens
function expand_aliases(text)
    local tokens = {}
    log('processing cell text: "%s"', text)
    if alias_stack[text] then
        log('expanding alias')
        process_text(alias_stack[text], tokens, 1)
    else
        process_text(text, tokens, 1)
    end
    return tokens
end
