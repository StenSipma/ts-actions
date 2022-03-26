local util = require('ts-actions.util')
local ts = vim.treesitter
local ts_utils = require('nvim-treesitter.ts_utils')

-- A table mapping the node type (as a string) to a function converting the
-- node in Numpy docstring parameter style
local parameter_map = {
        ['identifier'] = function (node)
                return string.format("%s", ts_utils.get_node_text(node)[1])
        end;
        ['typed_parameter'] = function (node)
                local name = node:child(0) -- The identifier
                local type = node:field("type")[1]
                name = ts_utils.get_node_text(name)[1]
                type = ts_utils.get_node_text(type)[1]
                return string.format("%s : %s", name, type)
        end;
        ['default_parameter'] = function (node)
                local name = node:child(0) -- The identifier
                local value = node:field("value")[1]
                name = ts_utils.get_node_text(name)[1]
                value = ts_utils.get_node_text(value)[1]
                return string.format("%s : default = %s", name, value)
        end;
        ['typed_default_parameter'] = function (node)
                local name = node:child(0) -- The identifier
                local value = node:field("value")[1]
                local type = node:field("type")[1]
                name = ts_utils.get_node_text(name)[1]
                value = ts_utils.get_node_text(value)[1]
                type = ts_utils.get_node_text(type)[1]
                return string.format("%s : %s, default = %s", name, type, value)
        end;
}

local function generate_docstring(function_node)
        -- Get the parameter list
        local params = util.get_function_parameters(function_node)
        -- Convert to the numpy style
        local param_block = {}
        for _, node, _ in params do
                local line = parameter_map[node:type()](node)
                table.insert(param_block, line)
        end


        table.insert(param_block, 1, "----------")
        table.insert(param_block, 1, "Parameters")

        -- Surround with the docstring characters
        table.insert(param_block, 1, '"""')
        table.insert(param_block, '"""\n')

        return param_block
end

local function ts_test()
        -- Print the closest outer function definition
        local func_def = util.get_closest_outer_node("function_definition")
        if func_def == nil then
                print("not inside a node")
                return
        end

        local param_block = generate_docstring(func_def)


        -- Find the starting position
        local body_node = func_def:field("body")[1]
        local block_start, _, _ = body_node:start()

        local text_edit = util.list_into_text_edit(param_block, block_start)
        vim.lsp.util.apply_text_edits({text_edit}, 0)
end

return {
        ts_test = ts_test;
}
