"""Write the macOS AppIcon asset catalog manifest from generated icon PNGs."""
import json
import sys
from pathlib import Path

catalog = Path(sys.argv[1])
images = [
    {
        "idiom": "mac",
        "size": f"{size}x{size}",
        "scale": f"{scale}x",
        "filename": f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png",
    }
    for size in (16, 32, 128, 256, 512)
    for scale in (1, 2)
]
missing = [item["filename"] for item in images if not (catalog / item["filename"]).is_file()]
if missing:
    raise SystemExit("Missing AppIcon image(s): " + ", ".join(missing))
(catalog / "Contents.json").write_text(
    json.dumps({"images": images, "info": {"version": 1, "author": "xcode"}}, indent=2) + "\n",
    encoding="utf-8",
)
