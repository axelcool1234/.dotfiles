require("telescope").setup({
  defaults = {
    prompt_prefix = "",
    selection_caret = "  ",
    entry_prefix = "  ",
    prompt_title = false,
    results_title = false,
    preview_title = false,
    border = true,
    borderchars = {
      prompt = { "─", "│", " ", "│", "┌", "┐", "│", "│" },
      results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
      preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
    },
    sorting_strategy = "ascending",
    layout_strategy = "horizontal",
    layout_config = {
      prompt_position = "top",
      width = 0.92,
      height = 0.88,
      preview_width = 0.55,
      horizontal = {
        preview_width = 0.55,
      },
      vertical = {
        width = 0.9,
        height = 0.9,
        preview_height = 0.55,
      },
    },
  },
})
