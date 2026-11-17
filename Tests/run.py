"""Check the Theme account-level first-opening lifecycle with Lua 5.1 mocks."""

from argparse import ArgumentParser
from pathlib import Path
import re
import sys

parser = ArgumentParser(description=__doc__)
parser.add_argument("--runtime", type=Path, help="Directory containing Lupa's Python package")
options = parser.parse_args()
if options.runtime:
    sys.path.insert(0, str(options.runtime.resolve()))

from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(source, path) assert(loadstring(source, path)) end")
files = [path for path in root.glob("*.lua")]
for path in files:
    compile_lua(path.read_text(encoding="utf-8-sig"), str(path))
print(f"PASS: {len(files)} production files compile with {lua.eval('_VERSION')}")

toc = (root / "Sintezza_Theme.toc").read_text(encoding="utf-8-sig")
version = re.search(r"^## Version:\s*(\S+)", toc, re.M)[1]
sections = re.findall(r"^## (\S+)", (root / "CHANGELOG.md").read_text(encoding="utf-8-sig"), re.M)
assert next(value for value in sections if value != "Unreleased") == version
assert "16001" in re.search(r"^## Interface:\s*(.+)", toc, re.M)[1]
for row in toc.splitlines():
    if row.strip() and not row.startswith("#"):
        assert (root / row.strip().replace("\\", "/")).is_file(), row
assert "## SavedVariables: Sintezza_ThemeDB" in toc
assert "## LoadSavedVariablesFirst: 1" in toc
print(f"PASS: TOC, SavedVariables loading contract and version {version}")

lua.globals().ADDON_ROOT = root.as_posix()
lua.execute((root / "Tests/FirstRun.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests/Tooltip.lua").read_text(encoding="utf-8"))
lua.execute((root / "Tests/Widgets.lua").read_text(encoding="utf-8"))
