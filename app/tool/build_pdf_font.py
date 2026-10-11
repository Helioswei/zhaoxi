#!/usr/bin/env python3
"""生成 PDF 导出用的中文字体子集（TrueType）。

为什么需要：
- `pdf` 包只支持 **TrueType（glyf）** 轮廓，思源宋体是 CFF/OTF，必须先转换；
- 完整思源宋体 ~11MB，直接进仓库/APK 太重，所以按字符集裁剪。

依赖：
    pip install fonttools otf2ttf        # 提供 pyftsubset / otf2ttf

用法：
    python3 tool/build_pdf_font.py <SourceHanSerifCN-Regular.otf> assets/fonts

产物：
    assets/fonts/ZhaoxiSerif-Regular.ttf   （以及同目录的 OFL.txt，请勿删除）

许可：思源宋体为 SIL OFL-1.1，分发时必须随包附带 OFL.txt。
"""

import os
import subprocess
import sys
import tempfile


def build_charset() -> str:
    chars = set()
    # GB2312 全部汉字与符号
    for b1 in range(0xA1, 0xF8):
        for b2 in range(0xA1, 0xFF):
            try:
                chars.add(bytes([b1, b2]).decode("gb2312"))
            except Exception:
                pass
    # ASCII
    for cp in range(0x20, 0x7F):
        chars.add(chr(cp))
    # CJK 标点、全角字符
    for cp in range(0x3000, 0x3040):
        chars.add(chr(cp))
    for cp in range(0xFF00, 0xFF61):
        chars.add(chr(cp))
    # 常用符号（含破折号/省略号/勾选圈）
    for cp in list(range(0x2010, 0x2016)) + [
        0x00A0, 0x00B7, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026,
        0x2192, 0x221A, 0x2500, 0x2502, 0x25CB, 0x25CF, 0x2605, 0x2713, 0x2714,
    ]:
        chars.add(chr(cp))
    return "".join(sorted(chars))


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    source, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        charset_path = os.path.join(tmp, "charset.txt")
        with open(charset_path, "w", encoding="utf-8") as fh:
            fh.write(build_charset())

        otf_out = os.path.join(tmp, "subset.otf")
        subprocess.run(
            [
                "pyftsubset", source,
                f"--text-file={charset_path}",
                f"--output-file={otf_out}",
                "--desubroutinize",
                "--no-hinting",
                "--layout-features=*",
                "--name-IDs=*",
            ],
            check=True,
        )

        subprocess.run(["otf2ttf", otf_out], check=True, cwd=tmp)
        ttf = os.path.join(tmp, "subset.ttf")
        if not os.path.exists(ttf):
            print("otf2ttf 未生成 .ttf", file=sys.stderr)
            return 1
        target = os.path.join(out_dir, "ZhaoxiSerif-Regular.ttf")
        os.replace(ttf, target)
        print(f"已生成 {target} ({os.path.getsize(target) / 1024 / 1024:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
