import re

README = "README.md"
SCRIPT = "post-install-example.sh"
START = "<!-- POSTINSTALL:START -->"
END = "<!-- POSTINSTALL:END -->"

with open(SCRIPT, "r") as f:
    script_content = f.read().strip()

code_block = f"```bash\n{script_content}\n```"

with open(README, "r") as f:
    readme = f.read()

pattern = re.compile(f"{START}.*?{END}", re.DOTALL)
replacement = f"{START}\n{code_block}\n{END}"
updated = pattern.sub(replacement, readme)

with open(README, "w") as f:
    f.write(updated)
