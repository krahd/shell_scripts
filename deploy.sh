
#!/bin/bash
mkdir -p ./backups

backup_date=$(date +%Y-%m-%d)
backup_file="./backups/bin-backup-$backup_date.zip"
suffix=1

while [ -e "$backup_file" ]; do
    backup_file="./backups/bin-backup-$backup_date-$suffix.zip"
    ((suffix++))
done

if [ -d ./bin ]; then
    zip -r "$backup_file" ./bin > /dev/null
fi



rm -f ./bin/*
cp ./*.sh ./bin
chmod +x ./bin/*.sh
