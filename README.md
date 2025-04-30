# Usage
This is script is meant for servers running inside a tmux session.
After you have your server running inside tmux, you can manually run the script
```sh
$ ./cronos.sh backup
```

or setup a cron job

```sh
$ crontab -e
# run at 5am every day, and save logs
0 5 * * * /path/to/cronos.sh --dir /path/to/server --backup-dir /path/to/backups backup >> /path/to/logs 2>&1
```
