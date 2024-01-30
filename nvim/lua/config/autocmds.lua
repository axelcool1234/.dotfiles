-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds hereby

-- Variable to track if HTML file has been opened
local html_file_opened = false

-- Function to compile Markdown to HTML using Pandoc
function CompileMarkdownToHtml()
    -- Get the current file name
    local current_file = vim.fn.expand("%:p")

    -- Generate HTML file name by changing the extension
    local html_file = current_file:gsub("%.md$", ".html")

    -- Run Pandoc command to compile Markdown to HTML
    local pandoc_command = string.format("pandoc --standalone --mathjax %s -o %s", current_file, html_file)
    vim.fn.system(pandoc_command)

    -- Open the generated HTML file in the default browser only if not already opened
    if not html_file_opened then
        vim.fn.jobstart(string.format("xdg-open %s", html_file), { detach = true })
        html_file_opened = true
    end
end

-- Function to delete the generated HTML file
function DeleteHtmlFile()
    local current_file = vim.fn.expand("%:p")
    local html_file = current_file:gsub("%.md$", ".html")
    vim.fn.delete(html_file)
end

-- Autocommands for Markdown files
vim.api.nvim_exec(
    [[
  augroup MarkdownAutoCompile
    autocmd!
    autocmd BufWritePost *.md call v:lua.CompileMarkdownToHtml()
    autocmd VimLeave *.md call v:lua.DeleteHtmlFile()
  augroup END
]],
    false
)
-- Disable autoformat for cpp files
vim.api.nvim_create_autocmd({ "FileType" }, {
    pattern = { "c", "cpp" },
    callback = function()
        vim.b.autoformat = false
    end,
})
