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

# Read the README
with open(README, "r", encoding="utf-8") as f:
    readme = f.read()

# Replace using a function to avoid escape parsing
pattern = re.compile(f"{START}.*?{END}", re.DOTALL)
updated = pattern.sub(lambda _: f"{START}\n{code_block}\n{END}", readme)

# Write the updated README
with open(README, "w", encoding="utf-8") as f:
    f.write(updated)
