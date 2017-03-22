#!/usr/bin/env bash

# Optional varaible
cluster_name="$3"

set -o errexit
set -o pipefail
set -o nounset
set -o errtrace


# main script mandatory params
node="$1"
action="$2"

set +o nounset

if [ "${cluster_name}z" == "z" ]; then
	cluster_name=${HOSTNAME}
fi


# https://hadoop.apache.org/docs/r2.7.3/hadoop-project-dist/hadoop-common/ClusterSetup.html

HADOOP_PREFIX=/opt/hadoop
HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop

# stars a name node
name_node() {
	local action="$1"
	local cluster_name="$2"
	
	case $action in
		start)
			if [ ! -d /data/${cluster_name}/ ]; then
				# The first time you bring up HDFS, it must be formatted. Format a new distributed filesystem as hdfs: 
				$HADOOP_PREFIX/bin/hdfs namenode -format ${cluster_name}
			fi
			# Start the HDFS NameNode with the following command on the designated node as hdfs:
			$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config ${HADOOP_CONF_DIR} --script hdfs start namenode
		;;
		stop)
			# Stop the NameNode with the following command, run on the designated NameNode as hdfs:
			$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config ${HADOOP_CONF_DIR} --script hdfs stop namenode
		;;
		status)
			# I would love a status report
			echo "Not implemented"
		;;
		*)
		echo "Action not supported"
		;;
	esac
	
}

data_node() {
	local action="$1"
	local cluster_name="$2"
	
	case $action in
		start)	
			# Start a HDFS DataNode with the following command on each designated node as hdfs:
			$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config ${HADOOP_CONF_DIR} --script hdfs start datanode
		;;
		stop)
			# Run a script to stop a DataNode as hdfs:
			$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config ${HADOOP_CONF_DIR} --script hdfs stop datanode
		;;
		status)
			# I would love a status report
			echo "Not implemented"
		;;
		*)
		echo "Action not supported"
		;;
	esac
}

config() {
	local file="${1}"
	shift
	local conf=("${@}")
	echo "<configuration>" > ${file}
	for p in "${conf[@]}"; do
		prop=$(echo ${p} | cut -f 1 -d '=')
		val=$(echo ${p} | cut -f 2 -d '=')
		echo "$file: $prop = $val"
		echo "<property>" >> ${file}
		echo "<name>${prop}</name><value>${val}</value>" >> ${file}
		echo "</property>" >> ${file}
	done
	echo "</configuration>" >> ${file} 
}

hadoop_handler() {
	local node="$1"
	local action="$2"
	local cluster_name="$3"
	echo "hadoop_handler():${node} ${action} ${cluster_name}"
	case $node in
		namenode)
			config "${HADOOP_CONF_DIR}/core-site.xml" ${CORE_SITE_CONF[@]}
			config "${HADOOP_CONF_DIR}/hdfs-site.xml" ${HDFS_SITE_CONF[@]}
			name_node ${action} ${cluster_name}
		;;
		datanode)
			config "${HADOOP_CONF_DIR}/core-site.xml" ${CORE_SITE_CONF[@]}
			config "${HADOOP_CONF_DIR}/hdfs-site.xml" ${HDFS_SITE_CONF[@]}	
			data_node ${action} ${cluster_name}
		;;
		*)
			echo This component is not implemented, see boot.sh
		;;
	esac
}

shut_down() {
	echo "Calling shutdown! $1"
	hadoop_handler ${node} stop ${cluster_name}
}


trap "shut_down sigkill" SIGKILL
trap "shut_down sigterm" SIGTERM 
trap "shut_down sighup" SIGHUP 
trap "shut_down sigint" SIGINT
# trap "shut_down sigexit" EXIT


# default config
core_site_default=(
	"fs.defaultFS=hdfs://${cluster_name}:8020"
	"io.file.buffer.size=131072"
)

# https://log.rowanto.com/why-datanode-is-denied-communication-with-namenode/
# disable remote host name check, enable in production with a correct service
# discovery reverse dns set up
hdfs_site_default=(
	"dfs.namenode.name.dir=file:///data/${cluster_name}/"
	"dfs.blocksize=268435456"
	"dfs.namenode.handler.count=100"
	"dfs.namenode.servicerpc-address=hdfs://${cluster_name}:8022"
	"dfs.namenode.datanode.registration.ip-hostname-check=false"
)


if [ "${CORE_SITE_CONF}z" == "z" ]; then
	CORE_SITE_CONF=${core_site_default[@]}
fi

if [ "${HDFS_SITE_CONF}z" == "z" ]; then
	HDFS_SITE_CONF=${hdfs_site_default[@]}
fi


echo "The ${node} is swtching to ${action} with ${cluster_name} id"
hadoop_handler ${node} ${action} ${cluster_name}

sleep 2s
tail -f /opt/hadoop/logs/*
