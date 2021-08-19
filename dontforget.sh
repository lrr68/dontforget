#!/bin/sh

#-Script that controls a calendar with emails
#-New appointments can be created by sending an email with an add command
#-Can notify via email your close appointments

appointmentsfile="$HOME/Documents/appointments.csv"
header="date,time,description"
#email is used to ssh to server and fetch remote commands
email="lucca@luccaaugusto.xyz"
#subject is used to filter emails that contain commands
subject="Naoesquece"

fetchemailappointments()
{
	state=0
	date=""
	time=""
	description=""
	body=""
	mailquery="${0##*/}.mailquery"

	(ssh $email "doveadm fetch 'body date.received' mailbox inbox subject $subject > mailquery &&
		doveadm flags add '\Seen' mailbox inbox unseen subject $subject &&
		doveadm move Trash mailbox inbox seen subject $subject &&
		cat mailquery" > "$mailquery")
	# query the server for unseen emails with subject=$subject
	# outputs email body and date.received to a file so line breaks are preserved
	# marks these emails as seen
	# cats the file so we get it's contents locally
	while IFS= read -r line || [ -n "$line" ]
	do
		case "$state" in
			0) #expect body
				[ "${line%%:*}" = "body" ] && state=1
				;;
			1) #read until find spend or receive
				#concatenate line for future error reporting
				body="$body|$line"
				date="${line%% *}"
				isdate="$(date -d ${date} 2>/dev/null)"
				if [ "$isdate" ]
				then
					state=2
					time="${line#* }"
					time="${time%% *}"
					description="${line#* }"
					description="${description#* }"
				elif [ "${line%%:*}" = "date.received" ]
				then
					#read until date and did not get command, something is wrong with the email
					{
						echo "${0##*/} ERROR:"
						echo "    Command not found in email"
						echo "    body: $body"
						echo "====Please do this one manually"
					} >> "$HOME/.${0##*/}.log"

					state=0
					body=""
				fi
				;;
			2) #read until find date.received
				if [ "${line%%:*}" = "date.received" ]
				then
					addappointment "$date" "$time" "$description"

					#Reset to read next
					state=0
					body=""
				fi
				;;
		esac

	done < "$mailquery"
	rm "$mailquery"

	#format log file and notify
	[ -e "$HOME/.${0##*/}.log" ] &&
		sed 's/|/\n    /g' < "$HOME/.${0##*/}.log" > "$HOME/.${0##*/}.log.aux" &&
		mv "$HOME/.${0##*/}.log.aux" "$HOME/.${0##*/}.log" &&
		notify-send "${0##*/} ERROR" "There were errors processing email logged appointments. See $HOME/.${0##*/}.log"
}

fetchupdates()
{
	fetchemailappointments
}

addappointment()
{
	date="$1"; shift
	time="$1"; shift
	description="$1"; shift

	if [ -z "$date" ] ||
		[ -z "$time" ] ||
		[ -z "$description" ]
	then
		echo "Missing parameters. Usage:"
		echo "${0##*/} add (date) (time) (description)"
	else
		echo "$date,$time,$description" >> $appointmentsfile
	fi
}

notifyappointment()
{
	#get appointments for tomorrow and exactly seven days ahead

	msg=""
	weekday="$(date +%A)"
	tomorrow="$(date -d tomorrow +%Y/%m/%d)"
	aweekfromnow="$(date -d "next $weekday" +%Y/%m/%d)"

	while IFS= read -r aptmt || [ -n "$aptmt" ]
	do
		[ "$aptmt" = "$header" ] && continue

		aptdate="${aptmt%%,*}"

		if [ "$aptdate" = "$tomorrow" ]
		then
			msg="$msg""Tomorrow at ${aptmt#*,}\n"
		elif [ "$aptdate" = "$aweekfromnow" ]
		then
			msg="$msg""Next week ($weekday) at ${aptmt#*,}\n"
		fi
	done < $appointmentsfile

	[ "$msg" ] &&
		notify-send "You have the following appointments" "$msg"
}

showappointmentsfile()
{
	column -s',' -t < "$appointmentsfile"
}

#RUNNING
[ -e "$appointmentsfile" ] ||
	echo "$header" > "$appointmentsfile"

arg="$1"; shift
case "$arg" in
	add)
		addappointment "$1" "$2" "$3"
		;;
	edit)
		"$EDITOR" "$appointmentsfile"
		;;
	fetch)
		fetchupdates
		;;
	notify)
		notifyappointment
		;;
	show)
		showappointmentsfile "$1"
		;;
	*)
		echo "usage: ${0##*/} ( command )"
		echo "commands:"
		echo "		add "
		echo "		edit: Opens the appointmentsfile with EDITOR"
		echo "		fetch: Fetches appointments registered by email"
		echo "		show [past]: Shows the current month transactions. If 'full' is passed as argument,"
		;;
esac
