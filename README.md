# How to use with crontab
```sh
$ crontab -e
# run at 5am every day, and save logs
0 5 * * * /path/to/cronos.sh --dir /path/to/server --backup-dir /path/to/backups backup >> /path/to/logs 2>&1
```
