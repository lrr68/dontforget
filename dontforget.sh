#!/bin/sh

#-Script that controls a calendar with emails
#-New appointments can be created by sending an email with an add command
#-Can notify via email your close appointments

appointmentsfile="$HOME/Documents/appointments.csv"

addappointment()
{
	date="$1"; shift
	time="$1"; shift
	description="$1"; shift

	echo "$date,$time,$description" >> $appointmentsfile
}

notifyappointment()
{

}
