content = open(r"G:\osa-observatory\api\main.py", encoding="utf-8").read()
old = "from api.routers.opendata import router as opendata_router"
new = "from api.routers.opendata import router as opendata_router\nfrom api.routers.eparticipation import router as eparticipation_router"
content = content.replace(old, new, 1)
old2 = "app.include_router(opendata_router)"
new2 = "app.include_router(opendata_router)\napp.include_router(eparticipation_router)"
content = content.replace(old2, new2, 1)
open(r"G:\osa-observatory\api\main.py", "w", encoding="utf-8").write(content)
print("OK")
