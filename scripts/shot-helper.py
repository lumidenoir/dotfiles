#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


def get_ocr(img_path):
    pre = img_path.replace(".png", "_pre.png")
    subprocess.run(
        [
            "convert",
            img_path,
            "-colorspace",
            "gray",
            "-contrast-stretch",
            "2x2%",
            "-sharpen",
            "0x1",
            "-resize",
            "200%",
            pre,
        ],
        check=True,
    )

    result = subprocess.run(
        ["tesseract", pre, "stdout", "--psm", "3", "-l", "eng"],
        capture_output=True,
        text=True,
    )
    Path(pre).unlink(missing_ok=True)  # clean up temp file
    return result.stdout.strip()


if __name__ == "__main__":
    mode = sys.argv[1]
    path = sys.argv[2]
    if mode == "--ocr":
        print(get_ocr(path))
