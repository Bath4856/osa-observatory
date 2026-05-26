content = open(r"G:\osa-observatory\api\db.py", encoding="utf-8").read()
old = 'engine = create_engine(\n    DATABASE_URL,\n    pool_pre_ping=True,\n    pool_size=10,\n    max_overflow=20,\n)'
new = 'engine = create_engine(\n    DATABASE_URL,\n    pool_pre_ping=True,\n    pool_size=10,\n    max_overflow=20,\n    connect_args={"client_encoding": "utf8"},\n)'
content = content.replace(old, new, 1)
open(r"G:\osa-observatory\api\db.py", "w", encoding="utf-8").write(content)
print("OK")
