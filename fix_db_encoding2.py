content = open(r"G:\osa-observatory\api\db.py", encoding="utf-8").read()
old = 'DATABASE_URL = (\n    f"postgresql+psycopg2://{settings.DB_USER}:"\n    f"{settings.DB_PASSWORD}@{settings.DB_HOST}:"\n    f"{settings.DB_PORT}/{settings.DB_NAME}"\n)'
new = 'DATABASE_URL = (\n    f"postgresql+psycopg2://{settings.DB_USER}:"\n    f"{settings.DB_PASSWORD}@{settings.DB_HOST}:"\n    f"{settings.DB_PORT}/{settings.DB_NAME}"\n    f"?client_encoding=utf8"\n)'
content = content.replace(old, new, 1)
open(r"G:\osa-observatory\api\db.py", "w", encoding="utf-8").write(content)
print("OK")
