local M = {}
local Path = require("plenary.path")
local json = require("dkjson") -- 确保安装了 dkjson 库

-- 读取工作区文件夹路径
local function read_workspace_files(workspace_dir)
	local workspace_files = {}
	local path_pattern = Path:new(workspace_dir .. "/*.code-workspace"):expand()

	for _, file in ipairs(vim.fn.glob(path_pattern, true, true)) do
		table.insert(workspace_files, file)
	end

	return workspace_files
end

local function remove_comments(json_string)
	-- 使用模式匹配去除以 // 开头的注释行
	return json_string:gsub("%s*//[^\n]*", "")
end

local function parse_path_in_one_workspace(json_path)
	-- 打开并读取JSON文件
	local file = io.open(json_path, "r")
	if not file then
		print("Could not open file: " .. json_path)
		return
	end

	local json_string = file:read("*a") -- 读取整个文件内容
	file:close() -- 关闭文件
	-- 去除注释
	local cleaned_json = remove_comments(json_string)

	-- 解析JSON
	local data, pos, err = json.decode(cleaned_json, 1, nil)

	if err then
		print("Error:", err)
		return
	end

	-- 打印folders中的path
	local paths = {} -- 存储有效路径的表
	if data.folders then
		for _, folder in ipairs(data.folders) do
			if folder.path then
				print(folder.path)
				table.insert(paths, folder.path) -- 将路径添加到表中
			end
		end
	else
		print("No folders found.")
	end
	return paths -- 返回路径表
end
local function search_in_selected_path(paths)
	require("telescope.pickers")
		.new({}, {
			prompt_title = "Select Folder",
			finder = require("telescope.finders").new_table({
				results = paths,
			}),
			sorter = require("telescope.sorters").get_fuzzy_file(),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
					local selected_path = selection.value
					require("telescope.actions").close(prompt_bufnr) -- 关闭选择窗口

					-- 在选定的路径下查找文件
					require("telescope.builtin").find_files({ cwd = selected_path }) -- 在选定路径下查找文件
				end)
				return true
			end,
		})
		:find()
end
function M.select_workspace()
	local workspace_dir = "~/sda/env/vscode" -- 请替换为你的工作区文件夹路径
	local workspace_files = read_workspace_files(workspace_dir)

	if #workspace_files == 0 then
		print("未找到任何工作区文件。")
		return
	end

	require("telescope.pickers")
		.new({}, {
			prompt_title = "选择工作区",
			finder = require("telescope.finders").new_table({
				results = workspace_files,
				entry_maker = function(entry)
					return {
						value = entry,
						display = Path:new(entry):make_relative(vim.loop.cwd()),
						ordinal = entry,
					}
				end,
			}),
			sorter = require("telescope.sorters").get_fuzzy_file(),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry() -- 正确获取选中的条目
					require("telescope.actions").close(prompt_bufnr)

					-- 打开选定的工作区文件
					print(selection.value)
					local wsp_paths = parse_path_in_one_workspace(selection.value)
					if #wsp_paths > 0 then
						search_in_selected_path(wsp_paths)
					else
						print("wsp_paths is empty")
					end
				end)

				return true
			end,
		})
		:find()
end
-- 设置插件的初始化函数
function M.setup()
	-- 设置键映射
	vim.api.nvim_set_keymap(
		"n",
		"<leader>vw",
		":lua require('wsp-like-vscode.core').select_workspace()<CR>",
		{ noremap = true, silent = true }
	)
end

return M
