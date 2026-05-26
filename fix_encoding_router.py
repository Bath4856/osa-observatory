content = open(r"G:\osa-observatory\api\routers\opendata.py", encoding="utf-8").read()
old = "from fastapi import APIRouter, Depends, Query\nfrom fastapi.responses import JSONResponse"
new = "import json\nfrom fastapi import APIRouter, Depends, Query\nfrom fastapi.responses import JSONResponse, Response"
content = content.replace(old, new, 1)

old2 = "def _wrap(data: list, dataset_code: str) -> dict:\n    return {\n        \"dataset\":    dataset_code,\n        \"license\":    \"CC-BY-4.0\",\n        \"access\":     \"Couche 0 -- Open Data\",\n        \"disclaimer\": _DISCLAIMER,\n        \"count\":      len(data),\n        \"data\":       data,\n    }"
new2 = "def _wrap(data: list, dataset_code: str) -> Response:\n    payload = {\n        \"dataset\":    dataset_code,\n        \"license\":    \"CC-BY-4.0\",\n        \"access\":     \"Couche 0 -- Open Data\",\n        \"disclaimer\": _DISCLAIMER,\n        \"count\":      len(data),\n        \"data\":       data,\n    }\n    return Response(\n        content=json.dumps(payload, ensure_ascii=False),\n        media_type=\"application/json; charset=utf-8\"\n    )"
content = content.replace(old2, new2, 1)

open(r"G:\osa-observatory\api\routers\opendata.py", "w", encoding="utf-8").write(content)
print("OK")
