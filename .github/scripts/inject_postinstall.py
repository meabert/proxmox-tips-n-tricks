import re
import string

README = "README.md"
SCRIPT = "post-install-example.sh"
START = "<!-- POSTINSTALL:START -->"
END = "<!-- POSTINSTALL:END -->"

def sanitize(text):
    printable = set(string.printable)
    return ''.join(
        c if c in printable else '\\x{:02x}'.format(ord(c))
        for c in text
    )

# Read and sanitize the shell script
with open(SCRIPT, "r", encoding="utf-8") as f:
    raw_script = f.read().strip()
    script_content = sanitize(raw_script)

# Wrap in a Markdown code block
code_block = f"```bash\n{script_content}\n```"

# Read the README and inject the script
with open(README, "r", encoding="utf-8") as f:
    readme = f.read()

pattern = re.compile(f"{START}.*?{END}", re.DOTALL)
replacement = f"{START}\n{code_block}\n{END}"
updated = pattern.sub(replacement, readme)

# Write the updated README
with open(README, "w", encoding="utf-8") as f:
    f.write(updated)
