#! /usr/bin/env bash

SERVER_NAME="${CRONOS_SERVER_NAME:-minecraft}"
BACKUP_DIR="${CRONOS_BACKUP_DIR:-$HOME/minecraft_backups}"

if ! grep --version | grep -iq gnu; then
	echo "Sorry, this script needs GNU grep!" >&2
	exit 1
fi

jobs_done() {
	cat - <<EOF

Job's done!
  ／l、             
（ﾟ､ ｡ ７         
  l  ~ヽ       
  じしf_,)ノ
EOF
}

usage() {
	cat - <<EOF
Welcome!
  ／l、             
（ﾟ､ ｡ ７         
  l  ~ヽ       
  じしf_,)ノ

EOF

	echo "Commands:"
	echo "backup: creates a backup at this current time (stops server if its running)"
	echo "$ cronos.sh backup"
	echo

	echo "Options:"
	echo "--help | -h        show this message"
	echo "--backup-dir <dir> set dest directory"
  echo

  echo "Environment Variables:"
  echo "You can use the following variables instead of manually using flags"
  echo "CRONOS_SERVER_NAME=<your backup prefix>"
  echo "CRONOS_BACKUP_DIR=<backup destination directory>"

	exit 1
}

[ -z "$1" ] && usage

backup() {
	if [ ! -d "$BACKUP_DIR" ]; then
		echo -n "Creating backup directory: ${BACKUP_DIR}... "
		mkdir -p "$BACKUP_DIR" || exit
		echo "OK."
	fi

	fabric_pid=$(pgrep -f fabric-server)
	should_restart=0
	if [ -z "$fabric_pid" ]; then
		echo "Server is not running. OK."
	else
		if ! tmux info &>/dev/null; then
			echo "Server is running outside of tmux! Please run it inside a tmux session." >&2
			exit 1
		fi

		tmux_pane_id=$(tmux list-panes -a -F '#{pane_id} #{pane_current_command}' | grep -i "java" | awk '{print $1}')
		if [ -z "$tmux_pane_id" ]; then
			echo "Server is running outside of tmux! Please run it inside a tmux session." >&2
			echo "Tip: this can also mean you wrapped your server start command in a script but did not use exec"
			exit 1
		fi
		pids_found=$(wc -l <<< "$tmux_pane_id")
		if (( pids_found > 1 )); then
			echo "More than 1 tmux pane running java. This script expect only one pane with java running (the server)." >&2
			exit 1
		fi
			
		should_restart=1
		msg="$(date +'%H:%M:%S') SERVER IS BACKING UP. SEE YOU ON THE OTHER SIDE!"
		tmux send-keys -t "$tmux_pane_id" say Space "$msg" Enter || exit
		tmux send-keys -t "$tmux_pane_id" save-off Enter || exit
		tmux send-keys -t "$tmux_pane_id" save-all Space flush Enter || exit

		seconds_passed=0
		echo -n "Waiting for server to pause... "
		while true; do
			if (( seconds_passed > 600 )); then
				echo "I've waited for 10 minutes but server does not seem to respond. Aborting." >&2
				exit 1
			fi

			if tmux capture-pane -p -t "$tmux_pane_id" | grep -A 5000 "$msg" | grep -q "Saved the game"; then
				echo "OK."
				break
			fi

			sleep 1
			seconds_passed=$(( seconds_passed + 1 ))
		done
	fi

	timestamp=$(date +"%F_%H-%M-%S") || exit
	backup_name="${SERVER_NAME}_${timestamp}.tar.gz"
	echo -n "Saving ${backup_name} to ${BACKUP_DIR}... "
	err=$(tar -cvzf "${BACKUP_DIR}/${backup_name}" . 2>&1)
	if [ "$?" -ne 0 ]; then
		if [ "$should_restart" -eq 1 ]; then
			tmux send-keys -t "$tmux_pane_id" save-on Enter
		fi
		echo "$err"
		exit 1
	fi
	echo "OK."
	if [ "$should_restart" -eq 1 ]; then
		tmux send-keys -t "$tmux_pane_id" save-on Enter || exit
	fi
	jobs_done
}

while true; do
	[ -z "$1" ] && break

  action=""
	case "$1" in
		--help|-h|help)
			shift
			action=usage
			;;

		--backup-dir)
			shift
			if [ -z "$1" ]; then
				echo "--backup-dir: argument required" >&1
				exit 1
			fi
			BACKUP_DIR="$1"
			shift
			;;

		backup)
			shift
			action=backup
			;;

		*)
			echo "Invalid option: $1" >&1
			shift
			action=usage
			;;
	esac
done

if [ -z "$action" ]; then
	echo "Nothing to do." >&2
	exit 1
fi

"$action"
