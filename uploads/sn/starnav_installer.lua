local files = {
	starNav = "BCk9q0EB",
	goto = "aaxFVEPn",
	tinyMap = "9GZkMSiF",
	pQueue = "PYbpYrfx",
	location = "HPS8KbxL",
	aStar = "BZFJqHBi",
}

for fileName, pasteCode in pairs(files) do
	shell.run("pastebin get "..pasteCode.." "..fileName)
end