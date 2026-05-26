content = open(r"G:\osa-observatory\api\main.py", encoding="utf-8").read()

# Desactiver les imports legacy
content = content.replace(
    "from api.routers.early_warning_sprint7 import router as early_warning_sprint7_router",
    "# SPRINT14 DEPRECATED -- from api.routers.early_warning_sprint7 import router as early_warning_sprint7_router"
)
content = content.replace(
    "from api.routers.decision_scenarios_sprint7 import (",
    "# SPRINT14 DEPRECATED -- from api.routers.decision_scenarios_sprint7 import ("
)
content = content.replace(
    "    decision_router, sovereignty_router as sovereignty_readiness_router,",
    "# SPRINT14 DEPRECATED --     decision_router, sovereignty_router as sovereignty_readiness_router,"
)
content = content.replace(
    "    ew_router as ew_sprint7_phase2_router, scenario_router",
    "# SPRINT14 DEPRECATED --     ew_router as ew_sprint7_phase2_router, scenario_router"
)
content = content.replace(
    "from api.routers.api_phase3_sprint8 import decision_phase3_router, ew_phase3_router",
    "# SPRINT14 DEPRECATED -- from api.routers.api_phase3_sprint8 import decision_phase3_router, ew_phase3_router"
)

# Desactiver les include_router legacy
content = content.replace(
    "app.include_router(early_warning_sprint7_router)",
    "# SPRINT14 DEPRECATED -- app.include_router(early_warning_sprint7_router)"
)
content = content.replace(
    "app.include_router(ew_sprint7_phase2_router)",
    "# SPRINT14 DEPRECATED -- app.include_router(ew_sprint7_phase2_router)"
)

open(r"G:\osa-observatory\api\main.py", "w", encoding="utf-8").write(content)
print("OK")
