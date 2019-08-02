#!/bin/bash

#MachineIp=$(ip addr | grep inet | grep ${INET_NAME} | awk '{print $2;}' | sed 's|/.*$||')
#使用k8s的service，默认和deployment名字一致，deployment名字不能带有-字符
MachineIp=$(echo ${HOSTNAME}|awk -F '-' '{print $1}')
MachineName=$(cat /etc/hosts | grep ${MachineIp} | awk '{print $2}')
OLDIPFILE=/data/OldMachineIp

install_node_services(){
	echo "base services ...."
	
	#mkdir -p /data/tars/tarsnode_data && ln -s /data/tars/tarsnode_data /usr/local/app/tars/tarsnode/data

	##核心基础服务配置修改
	cd /usr/local/app/tars

	sed -i "s/dbhost.*=.*192.168.2.131/dbhost = ${DBIP}/g" `grep dbhost -rl ./*`
	sed -i "s/registry.tars.com/${MASTER}/g" `grep registry.tars.com -rl ./*`
	sed -i "s/192.168.2.131/${MachineIp}/g" `grep 192.168.2.131 -rl ./*`
	sed -i "s/db.tars.com/${DBIP}/g" `grep db.tars.com -rl ./*`
	sed -i "s/dbport.*=.*3306/dbport = ${DBPort}/g" `grep dbport -rl ./*`
	sed -i "s/web.tars.com/${MachineIp}/g" `grep web.tars.com -rl ./*`

	if [ ${MOUNT_DATA} = true ];
	then
		mkdir -p /data/tarsnode_data && ln -sn /data/tarsnode_data /usr/local/app/tars/tarsnode/data
		CHECK=$(mysqlshow --user=${DBUser} --password=${DBPassword} --host=${DBIP} --port=${DBPort} db_tars | grep -v Wildcard | grep -o db_tars)
		if [[ "$CHECK" = "db_tars" && -f $OLDIPFILE && $(cat $OLDIPFILE) != ${MachineIp} ]]; then
			OLDIP=$(cat /data/OldMachineIp)
			mysql -h${DBIP} -P${DBPort} -u${DBUser} -p${DBPassword} -e "USE db_tars; UPDATE t_adapter_conf SET node_name=REPLACE(node_name, '${OLDIP}', '${MachineIp}'), endpoint=REPLACE(endpoint,'${OLDIP}', '${MachineIp}'); UPDATE t_machine_tars_info SET node_name=REPLACE(node_name, '${OLDIP}', '${MachineIp}'); UPDATE t_server_conf SET node_name=REPLACE(node_name, '${OLDIP}', '${MachineIp}'); UPDATE t_server_notifys SET node_name=REPLACE(node_name, '${OLDIP}', '${MachineIp}'), server_id=REPLACE(server_id, '${OLDIP}', '${MachineIp}'); DELETE FROM t_node_info WHERE node_name='${OLDIP}'; DELETE FROM t_registry_info WHERE locator_id LIKE '${OLDIP}:%';"
			sed -i "s/${OLDIP}/${MachineIp}/g" `grep ${OLDIP} -rl /usr/local/app/tars/tarsnode/*`
		fi
	fi
	
	chmod u+x tarsnode_install.sh
	./tarsnode_install.sh
	
	echo "* * * * * /usr/local/app/tars/tarsnode/util/monitor.sh" >> /etc/crontab
	echo ${MachineIp} > /data/OldMachineIp
}

install_node_services
