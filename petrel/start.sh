#!/bin/bash
register="petrel-kernel-register-1.0-SNAPSHOT-boot.jar"

user="petrel-kernel-user-1.0-SNAPSHOT-boot.jar"
game="petrel-kernel-game-1.0-SNAPSHOT-boot.jar"

lobby="petrel-game-lobby-1.0-SNAPSHOT-boot.jar"
slots="petrel-game-slots-1.0-SNAPSHOT-boot.jar"
web="petrel-cms-web-1.0-SNAPSHOT.war"


register_log="/data/petrel/logs/petrel-kernel-register/"
user_log="/data/petrel/logs/petrel-kernel-user/" 
game_log="/data/petrel/logs/petrel-kernel-user/"

lobby_log="/data/petrel/logs/petrel-game-lobby/"
slots_log="/data/petrel/logs/petrel-game-slots/"
web_log="/data/petrel/logs/petrel-cms-web/"

prm=$2

message="ALL|user|register|game|lobby|slots|web"
start() {
   
   if [[ $prm = 'ALL' ]] || [[ $prm = 'register' ]]
        then
            stop_register
            start_register
        fi
		

	if [[ $prm = 'ALL' ]] || [[ $prm = 'user' ]]
        then
                stop_user
                start_user
        fi

        
 

    if [[ $prm = 'ALL' ]] || [[ $prm = 'game' ]]
        then
            stop_game
            start_game
        fi

    if [[ $prm = 'ALL' ]] || [[ $prm = 'lobby' ]]
        then
            stop_lobby
            start_lobby
        fi
		
    if [[ $prm = 'ALL' ]] || [[ $prm = 'slots' ]]
        then
            stop_slots
            start_slots
        fi


    if [[ $prm = 'ALL' ]] || [[ $prm = 'web' ]]
        then
            stop_web
            start_web
    
	else
  		echo  "" + $message
	fi


	exit 0
}


stop() {

    if [[ $prm = 'ALL' ]] || [[ $prm = 'lobby' ]]
        then
            stop_lobby
        fi	

    if [[ $prm = 'ALL' ]] || [[ $prm = 'slots' ]]
        then
            stop_slots
		fi	
 

	if [[ $prm = 'ALL' ]] || [[ $prm = 'user' ]]
        then
                 stop_user
        fi


    if [[ $prm = 'ALL' ]] || [[ $prm = 'game' ]]
        then
            stop_game
        fi

	if [[ $prm = 'ALL' ]] || [[ $prm = 'register' ]]
        then
                 stop_register
    fi
		
	if [[ $prm = 'ALL' ]] || [[ $prm = 'register' ]]
        then
                 stop_web

	else
  		echo $message
	fi

	exit 0

}

# game--start-------------- message="ALL|user|register|game|lobby|slots|web"
start_user(){
	echo "-----------start-user------------------"
	nohup java  -jar -Xmn512m -Xms1024m -Xmx1024m $user \
		--spring.config.location=classpath:/,file:./config/ \
		--spring.profiles.active=prod \
		--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878 \
		--spring.cloud.nacos.config.server-addr=127.0.0.1:6878 \
		>/dev/null 2>&1&
	sleep 8s
	tail -n  300 $user_log`ls $user_log -t1|awk '{if (NR ==1) print}'`  
	echo "-----------end-user----------------------"
}

start_register(){
	echo "-----------start-register-------------------"
	nohup java -jar -Xmn200m -Xms400m -Xmx400m  $register \
		--spring.config.location=classpath:/,file:./config/ \
		--spring.profiles.active=prod \
		--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878 \
		--spring.cloud.nacos.config.server-addr=127.0.0.1:6878 \
		>/dev/null 2>&1&
	sleep 18s
	tail -n  300 $register_log`ls $register_log -t1|awk '{if (NR ==1) print}'`  
	echo "-----------end-register----------------------"
}


start_game(){
        echo "-----------start-game-------------------"
        nohup java  -jar -Xmn512m -Xms1024m -Xmx1024m $game \
		--spring.config.location=classpath:/,file:./config/ \
		--spring.profiles.active=prod \
		--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878 \
		--spring.cloud.nacos.config.server-addr=127.0.0.1:6878 \
		>/dev/null 2>&1&
        sleep 8s
       tail -n  300 $game_log`ls $game_log -t1|awk '{if (NR ==1) print}'`  
        echo "-----------end-game----------------------"
}

start_lobby(){
        echo "-----------start-lobby-------------------"
        nohup java  -jar -Xmn512m -Xms1024m -Xmx1024m $lobby \
		--spring.config.location=classpath:/,file:./config/ \
		--spring.profiles.active=prod \
		--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878 \
		--spring.cloud.nacos.config.server-addr=127.0.0.1:6878 \
		--zebra.ip.out=122.114.55.213 --zebra.port=8989 \
		>/dev/null 2>&1&
        sleep 10s
      tail -n  300 $lobby_log`ls $lobby_log -t1|awk '{if (NR ==1) print}'`  
        echo "-----------end-lobby----------------------"
}

start_slots(){
        echo "-----------start-slots------------------"
        nohup java  -jar -Xmn512m -Xms1024m -Xmx1024m $slots \
		--spring.config.location=classpath:/,file:./config/ \
		--spring.profiles.active=prod \
		--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878 \
		--spring.cloud.nacos.config.server-addr=127.0.0.1:6878 \
		--zebra.ip.out=122.114.55.213 \
		>/dev/null 2>&1&
        sleep 10s
      tail -n  300 $slots_log`ls $slots_log -t1|awk '{if (NR ==1) print}'`  
        echo "-----------end-slots----------------------"
}
start_web(){
        echo "-----------start-web------------------"
        nohup java  -jar -Xmn512m -Xms1024m -Xmx1024m $web \
		--spring.config.location=classpath:/,file:./config/ \
		--spring.profiles.active=prod \
		--spring.cloud.nacos.discovery.server-addr=127.0.0.1:6878 \
		--spring.cloud.nacos.config.server-addr=127.0.0.1:6878 \
		>/dev/null 2>&1&
        sleep 10s
      tail -n  300 $web_log`ls $web_log -t1|awk '{if (NR ==1) print}'`  
        echo "-----------end-web----------------------"
}

# stop  ------------ message="ALL|user|register|game|lobby|slots|web"



stop_lobby(){
        echo "---------stop-lobby--------------------"
        P_ID=`ps -ef | grep -w $lobby | grep -v "grep" | awk '{print $2}'`
        if [ "$P_ID" == "" ]; then
            echo "---lobby process not exists or stop success"
        else
            kill -9 $P_ID
			 sleep 5s
            echo "lobby  killed success"
        fi
}

stop_slots(){
        echo "---------stop-slots--------------------"
        P_ID=`ps -ef | grep -w $slots | grep -v "grep" | awk '{print $2}'`
        if [ "$P_ID" == "" ]; then
            echo "---slots process not exists or stop success"
        else
            kill -9 $P_ID
		    sleep 5s
            echo "slots  killed success"
        fi
}


stop_user(){
	echo "---------stop-user--------------------"
	P_ID=`ps -ef | grep -w $user | grep -v "grep" | awk '{print $2}'`
        if [ "$P_ID" == "" ]; then
            echo "---user process not exists or stop success"
        else
            kill -9 $P_ID
            echo "user  killed success"
        fi
}


stop_game(){
        echo "---------stop-game--------------------"
        P_ID=`ps -ef | grep -w $game | grep -v "grep" | awk '{print $2}'`
        if [ "$P_ID" == "" ]; then
            echo "---game process not exists or stop success"
        else
            kill -9 $P_ID
            echo "game  killed success"
        fi
}


stop_register(){
	echo "---------stop-register-center------------------"
	P_ID=`ps -ef | grep -w $register | grep -v "grep" | awk '{print $2}'`
        if [ "$P_ID" == "" ]; then
            echo "---register process not exists or stop success"
        else
            kill -9 $P_ID
            echo "register  killed success"
        fi
}

stop_web(){
	echo "---------stop-web------------------"
	P_ID=`ps -ef | grep -w $web | grep -v "grep" | awk '{print $2}'`
        if [ "$P_ID" == "" ]; then
            echo "---web process not exists or stop success"
        else
            kill -9 $P_ID
            echo "web  killed success"
        fi
}

# Status check function
status() {
	echo "=========================================="
	echo "   Petrel Services Status"
	echo "=========================================="
	echo ""
	
	check_service_status "Register" "$register"
	check_service_status "User" "$user"
	check_service_status "Game" "$game"
	check_service_status "Lobby" "$lobby"
	check_service_status "Slots" "$slots"
	check_service_status "Web" "$web"
	
	echo ""
	echo "=========================================="
}

check_service_status() {
	local name=$1
	local jar=$2
	
	P_ID=`ps -ef | grep -w "$jar" | grep -v "grep" | awk '{print $2}'`
	if [ "$P_ID" != "" ]; then
		echo "✓ $name: RUNNING (PID: $P_ID)"
	else
		echo "✗ $name: STOPPED"
	fi
}
 


tips() {
	echo "----------------Error command------------------------"
	echo "parameter1  start stop status"
	echo $message
	exit 1
}
case $1 in
  (start)
     start
     ;;
  (stop)
     stop
     ;;
  (status)
     status
     ;;
  (*)
     tips
     ;;
esac

