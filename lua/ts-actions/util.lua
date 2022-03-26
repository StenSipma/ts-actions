-- File:   util.lua
-- Author: Sten Sipma (sten.sipma@ziggo.nl)
-- Description:
--	Utility functions for working with treesitter
local ts = vim.treesitter
local ts_utils = require('nvim-treesitter.ts_utils')


-- Print some basic information about the given treesitter node
local function print_node(node)
        print("type: " .. node:type())
        print("#child: " .. node:child_count())
        local sr, sc, _ = node:start()
        local er, ec, _ = node:end_()
        print(string.format("(%s, %s) - (%s, %s)", sr, sc, er, ec))
end

local function iter_query_str(node_type)
        local parser = ts.get_parser()
        local tree = parser:parse()[1]

        local query = string.format("( %s ) @output", node_type)
        local q = ts.parse_query("python", query)
        return q:iter_captures(tree:root())
end

-- Checks if the given point {row, col} is inside (inclusive) the scope
-- of the given node
--
-- row is 1 based, column is 0 based
-- node range values are 0 based
local function point_is_inside(point, node)
        local row, col = unpack(point)
        row = row - 1 -- correct for 1 based index

        local start_row, start_col, end_row, end_col = node:range()

        if start_row <= row and row <= end_row then
                return start_col <= col and col <= end_col;
        end
        return false
end

-- Check if node1 is an inner node of node2
-- (i.e. node1 is a child of node2)
local function is_inner_node(node1, node2)
        local range1 = {node1:range()}
        local range2 = {node2:range()}

        -- Checks rows first (index 1 and 3)
        -- Then columns (index 2 and 4)
        return (range1[1] >= range2[1] and range1[3] <= range2[3]) and
               (range1[2] >= range2[2] and range1[4] <= range2[4])
end

local function get_function_parameters(function_node)
        local query = "(function_definition parameters: (parameters [ (identifier) (typed_parameter) (default_parameter) (typed_default_parameter) ] @parameter))"
        local q = ts.parse_query("python", query)
        return q:iter_captures(function_node)
end

-- Finds the inner most node of the given node_type, which surrounds
-- the current position of the cursor.
--
-- TODO: pass optional row / col and default to cursor?
-- TODO: pass optional buffer / window
local function get_closest_outer_node(node_type)
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local closest_node = nil

        -- TODO: if returned nodes are ordered, binary search is possible
        for _, node, _ in iter_query_str(node_type) do
                if point_is_inside({row, col}, node) then
                        if closest_node == nil or ts_utils.is_parent(closest_node, node) then
                                closest_node = node
                        end
                end
        end
        return closest_node
end

local function join(list, char)
        if char == nil then
                char = "\n"
        end

        if #list < 1 then
                return ""
        end

        local str = list[1]
        for _, line in pairs(vim.list_slice(list, 2)) do
                str = str .. char .. line
        end
        return str
end

local function list_into_text_edit(list, row)
        local text_edit = {
                range = {start={line=row, character=0}, ['end']={line=row, character=0}};
                newText = join(list)
        }
        return text_edit
end

return {
        print_node = print_node;
        point_is_inside = point_is_inside;
        is_inner_node = is_inner_node;
        get_closest_outer_node = get_closest_outer_node;
        get_function_parameters = get_function_parameters;
        join = join;
        list_into_text_edit = list_into_text_edit;
}
