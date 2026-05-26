content = open(r"G:\osa-observatory\api\main.py", encoding="utf-8").read()
old = "from api.routers.opendata import router as opendata_router"
new = "from api.routers.opendata import router as opendata_router\nfrom api.routers.tokens import router as tokens_router, public_router as tokens_public_router"
content = content.replace(old, new, 1)
old2 = "app.include_router(opendata_router)"
new2 = "app.include_router(opendata_router)\napp.include_router(tokens_router)\napp.include_router(tokens_public_router)"
content = content.replace(old2, new2, 1)
open(r"G:\osa-observatory\api\main.py", "w", encoding="utf-8").write(content)
print("OK")
