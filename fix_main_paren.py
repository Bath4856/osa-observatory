content = open(r"G:\osa-observatory\api\main.py", encoding="utf-8").read()
content = content.replace(
    "# SPRINT14 DEPRECATED --     ew_router as ew_sprint7_phase2_router, scenario_router\n)",
    "# SPRINT14 DEPRECATED --     ew_router as ew_sprint7_phase2_router, scenario_router\n# SPRINT14 DEPRECATED -- )"
)
open(r"G:\osa-observatory\api\main.py", "w", encoding="utf-8").write(content)
print("OK")
