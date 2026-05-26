content = open(r"G:\osa-observatory\api\main.py", encoding="utf-8").read()
for router in ["decision_router", "sovereignty_readiness_router", "scenario_router", "decision_phase3_router", "ew_phase3_router"]:
    content = content.replace(
        f"app.include_router({router})",
        f"# SPRINT14 DEPRECATED -- app.include_router({router})"
    )
open(r"G:\osa-observatory\api\main.py", "w", encoding="utf-8").write(content)
print("OK")
