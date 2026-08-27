return {
	{
		"junegunn/fzf",
		name = "fzf",
	},
	{
		"junegunn/fzf.vim",
		dependencies = { "junegunn/fzf" },
		cmd = { "Files", "GFiles", "Buffers", "RG", "Commits" },
	},
}
