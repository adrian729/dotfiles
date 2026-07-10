return {
	{
		"junegunn/fzf",
		name = "fzf",
		dir = "~/.fzf",
		build = "./install --all",
	},
	{
		"junegunn/fzf.vim",
		dependencies = { "junegunn/fzf" },
		cmd = { "Files", "GFiles", "Buffers", "RG", "Commits" },
	},
}
