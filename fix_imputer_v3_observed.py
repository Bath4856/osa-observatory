"""
OSA Observatory — fix_imputer_v3_observed.py v2
Fix insert_l2_batch() pour propager les observes L1 -> L2
"""
from pathlib import Path

IMPUTER = Path("collectors/imputer_v3.py")
content = IMPUTER.read_text(encoding="utf-8")

OLD = '    to_insert = df_final[\n        df_final["raw_value"].isna() &\n        df_final["imputed_value"].notna() &\n        df_final["quality_flag"].notna()\n    ].copy()'

NEW = '''    # Fix Sprint 8 : insérer TOUS les pays en L2
    # Observés (raw_value non null) : copie L1 -> L2, confidence=0.95
    # Imputés  (raw_value null)     : valeur MICE, confidence calculée
    df_obs = df_final[df_final["raw_value"].notna()].copy()
    df_obs["imputed_value"] = df_obs["raw_value"]
    df_obs["confidence"]    = 0.95
    df_obs["method_chain"]  = "ORIGINAL"
    df_obs["quality_flag"]  = df_obs["quality_flag"].fillna("OK")

    df_imp = df_final[
        df_final["raw_value"].isna() &
        df_final["imputed_value"].notna() &
        df_final["quality_flag"].notna()
    ].copy()

    to_insert = pd.concat([df_obs, df_imp], ignore_index=True)
    to_insert = to_insert[to_insert["imputed_value"].notna()].copy()'''

if OLD in content:
    content = content.replace(OLD, NEW, 1)
    IMPUTER.write_text(content, encoding="utf-8")
    print("OK -- fix applique dans imputer_v3.py")
else:
    print("WARN -- pattern non trouve")
    idx = content.find('to_insert = df_final[')
    print(repr(content[idx:idx+200]))
