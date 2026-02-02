#!/bin/bash

# Production Backup Script for SubscribeCoffie Backend
# This script creates backups of the production database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SubscribeCoffie Production Backup      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if supabase CLI is installed
if ! command -v supabase >/dev/null 2>&1; then
    echo -e "${RED}❌ Supabase CLI not found${NC}"
    exit 1
fi

# Check if linked to a project
if [ ! -f "$PROJECT_ROOT/.git/config" ]; then
    echo -e "${RED}❌ Not in a linked Supabase project${NC}"
    echo -e "${YELLOW}Run: supabase link --project-ref YOUR_PROJECT_REF${NC}"
    exit 1
fi

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="subscribecoffie_backup_$TIMESTAMP"

echo -e "${YELLOW}Creating backup: $BACKUP_NAME${NC}"
echo ""

# Backup 1: Schema only
echo -e "${YELLOW}[1/3] Backing up database schema...${NC}"
SCHEMA_FILE="$BACKUP_DIR/${BACKUP_NAME}_schema.sql"

supabase db dump --linked -f "$SCHEMA_FILE" --data-only=false

if [ -f "$SCHEMA_FILE" ]; then
    SIZE=$(du -h "$SCHEMA_FILE" | cut -f1)
    echo -e "${GREEN}✅ Schema backup created: $SCHEMA_FILE ($SIZE)${NC}"
else
    echo -e "${RED}❌ Schema backup failed${NC}"
    exit 1
fi
echo ""

# Backup 2: Data only
echo -e "${YELLOW}[2/3] Backing up database data...${NC}"
DATA_FILE="$BACKUP_DIR/${BACKUP_NAME}_data.sql"

supabase db dump --linked -f "$DATA_FILE" --schema-only=false

if [ -f "$DATA_FILE" ]; then
    SIZE=$(du -h "$DATA_FILE" | cut -f1)
    echo -e "${GREEN}✅ Data backup created: $DATA_FILE ($SIZE)${NC}"
else
    echo -e "${RED}❌ Data backup failed${NC}"
    exit 1
fi
echo ""

# Backup 3: Full backup (schema + data)
echo -e "${YELLOW}[3/3] Creating full backup...${NC}"
FULL_FILE="$BACKUP_DIR/${BACKUP_NAME}_full.sql"

supabase db dump --linked -f "$FULL_FILE"

if [ -f "$FULL_FILE" ]; then
    SIZE=$(du -h "$FULL_FILE" | cut -f1)
    echo -e "${GREEN}✅ Full backup created: $FULL_FILE ($SIZE)${NC}"
else
    echo -e "${RED}❌ Full backup failed${NC}"
    exit 1
fi
echo ""

# Compress backups
echo -e "${YELLOW}Compressing backups...${NC}"

gzip -f "$SCHEMA_FILE" &
gzip -f "$DATA_FILE" &
gzip -f "$FULL_FILE" &

wait

echo -e "${GREEN}✅ Backups compressed${NC}"
echo ""

# Create metadata file
METADATA_FILE="$BACKUP_DIR/${BACKUP_NAME}_metadata.txt"
cat > "$METADATA_FILE" << EOF
SubscribeCoffie Production Backup
=====================================
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Backup Name: $BACKUP_NAME

Files:
- ${BACKUP_NAME}_schema.sql.gz (Database schema only)
- ${BACKUP_NAME}_data.sql.gz (Data only)
- ${BACKUP_NAME}_full.sql.gz (Complete backup)

Restore Instructions:
---------------------
1. Schema only:
   gunzip ${BACKUP_NAME}_schema.sql.gz
   psql -h [DB_HOST] -U postgres -f ${BACKUP_NAME}_schema.sql

2. Data only:
   gunzip ${BACKUP_NAME}_data.sql.gz
   psql -h [DB_HOST] -U postgres -f ${BACKUP_NAME}_data.sql

3. Full restore:
   gunzip ${BACKUP_NAME}_full.sql.gz
   psql -h [DB_HOST] -U postgres -f ${BACKUP_NAME}_full.sql

IMPORTANT: Test restore in a staging environment first!
EOF

echo -e "${GREEN}✅ Metadata file created: $METADATA_FILE${NC}"
echo ""

# List all backup files
echo -e "${BLUE}Backup files created:${NC}"
ls -lh "$BACKUP_DIR/${BACKUP_NAME}"* | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Cleanup old backups (keep last 7 days)
echo -e "${YELLOW}Cleaning up old backups (keeping last 7 days)...${NC}"

find "$BACKUP_DIR" -name "subscribecoffie_backup_*.gz" -type f -mtime +7 -delete
find "$BACKUP_DIR" -name "subscribecoffie_backup_*.txt" -type f -mtime +7 -delete

OLD_COUNT=$(find "$BACKUP_DIR" -name "subscribecoffie_backup_*" -type f | wc -l | xargs)
echo -e "${GREEN}✅ Cleanup complete. Total backups: $OLD_COUNT${NC}"
echo ""

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Backup Summary                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Backup completed successfully${NC}"
echo -e "${BLUE}Backup location: $BACKUP_DIR${NC}"
echo -e "${YELLOW}Backup name: $BACKUP_NAME${NC}"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo -e "  • Store backups in secure location (S3, cloud storage)"
echo -e "  • Test restore process regularly"
echo -e "  • Keep backups encrypted"
echo -e "  • Consider PITR for Pro plan (7 days retention)"
echo ""
echo -e "${BLUE}To restore this backup:${NC}"
echo -e "  gunzip $BACKUP_DIR/${BACKUP_NAME}_full.sql.gz"
echo -e "  psql -h [YOUR_DB_HOST] -U postgres -f $BACKUP_DIR/${BACKUP_NAME}_full.sql"
echo ""
