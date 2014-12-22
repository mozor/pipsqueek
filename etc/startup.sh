#!/bin/bash

RUNAS=pips
COMMAND='/usr/bin/perl /home/pips/pipsqueek/bin/pipsqueek.pl'
ARGS=' -d /home/pips/channels/*'
PIDFILE='/home/pips/pipsqueek.pid'
EMAIL='ZFOUTS@FNA.bZ'

function start_pipsqueek {
	sudo -u ${RUNAS} ${COMMAND} ${ARGS} 2>/dev/null &
	PID=$!
	#kill -9 ${PID}
	PIDSQUEEK=$(ps auxf | egrep ^pips.*perl|awk '{print $1}')
	echo ${PIDSQUEEK} > ${PIDFILE}
	
}



function stop_pipsqueek {
	kill -9 $(cat ${PIDFILE})
}


function status_check {
	if [ $(ps auxf | grep -c $(cat ${PIDFILE})) -ge 1 ]; 
	then
		echo RUNNING
	else
		echo NOT RUNNING
	fi
}


function heartbeat {
	if [ $(ps auxf | grep -c $(cat ${PIDFILE})) -ge 1 ]; 
	then
		exit
	else
		echo -e "Starting Pips\n$(uptime)\n$(dmesg)\n$(ps auxf)\n$(last)" | mail -s "Pipsqueek Restart" ${EMAIL}
		start_pipsqueek
	fi
}

case "$1" in
        start)
            start_pipsqueek
            ;;

        stop)
            stop_pipsqueek
            ;;

        restart)
	    stop_pipsqueek
            start_pipsqueek
            ;;
        status)
	    status_check
            ;;			
	heartbeat)
	    heartbeat
	    ;;	
        *)
            echo $"Usage: $0 {start|stop|restart|status}"
            exit 1

esac
