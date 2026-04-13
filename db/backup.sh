#!/bin/bash
# OSA Observatory -- Backup automatique PostgreSQL
# Usage : bash db/backup.sh
# Cron  : 0 2 * * * bash /workspaces/osa-observatory/db/backup.sh

BACKUP_DIR="/workspaces/osa-observatory/db/backups"
DATE=$(date +%Y%m%d_%H%M%S)
FILE="$BACKUP_DIR/osa_db_$DATE.sql.gz"

echo "[$(date)] Backup OSA en cours..."
docker exec db pg_dump -U osa_user osa_db | gzip > "$FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$FILE" | cut -f1)
    echo "[$(date)] Backup OK : $FILE ($SIZE)"
    # Garder seulement les 7 derniers backups
    ls -t "$BACKUP_DIR"/*.sql.gz | tail -n +8 | xargs -r rm
else
    echo "[$(date)] ERREUR backup"
    exit 1
fi
