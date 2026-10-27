#!/usr/bin/env python3
"""对 sqlite 跑一句查询，打印第一行第一列。

用法：db_query.py <db 文件> "<SQL>"
查不到时打印空字符串（不抛异常），方便 shell 里判断。
"""
import sqlite3
import sys

db = sqlite3.connect(sys.argv[1])
row = db.execute(sys.argv[2]).fetchone()
print("" if row is None or row[0] is None else row[0])
