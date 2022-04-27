#!/bin/bash

### usage
## S_NET_NAME=ens160 T_NET_NAME=eth0 ./init.sh
## DISK_DEV=/dev/sdb ./init.sh
## DATA_DIR=/data1 ./init.sh 数据目录默认挂载/data

## S_NET_NAME  原网卡名
## T_NET_NAME  目标网卡名
## DISK_DEV  格式化磁盘并挂载
## DATA_DIR docker数据目录

DOCKERD_PULGIN_DIR=/usr/local/lib/docker/cli-plugins
images="zk.tar,broker.tar,bookie.tar,etcd.tar,es.tar,backend.tar,traefik.tar"

## check dockerd /docker compose
check_dockerd() {
	if ! docker version >/dev/null 2>&1; then
		return 1
	else

		if ! docker compose version >/dev/null 2>&1; then
			return 1
		else
			return 0
		fi
	fi
}

## check os/arch
check_arch() {
	arch=$(arch)
	if [[ $arch =~ "x86_64" ]]; then
		return 0
	else
		echo "当前CPU架构$arch,需要x86_64/i386"
		exit 1
	fi
}
check_os() {
	os=$(lsb_release -a 2>/dev/null | grep Des | awk '{print $2}')
	version=$(lsb_release -a 2>/dev/null | grep Des | awk '{print $3}' | awk -F "." '{print $1}')
	if [ "$os" == "Ubuntu" ] && [ "$version" -eq 20 ]; then
		return 0
	else
		echo "发行版/版本不匹配"
		exit 1
	fi
}

## set set_max_map_count=262144
set_max_map() {
	count="$(grep "vm.max_map_count" /etc/sysctl.conf -c)"
	if [ "$count" -eq 0 ]; then
		sed '$ a vm.max_map_count=262144' /etc/sysctl.conf -i
		sysctl -p
	else
		return 0
	fi
}

## 格式化磁盘、挂载、docker目录链接/data/
format_disk() {
	if [ -z "$DATA_DIR" ]; then
		DATA_DIR="/data"
	fi
	mkfs.ext4 "$DISK_DEV"
	if [ ! -d $DATA_DIR ]; then
		mkdir $DATA_DIR
		echo UUID="$(blkid "$DISK_DEV" | awk -F '"' '{print $2}')" $DATA_DIR ext4 defaults 0 1 >>/etc/fstab
		mount -a
		ln -sv /var/lib/docker $DATA_DIR/docker
	else
		return 1
	fi

}

## 安装dockerd 、docker compose v2
dockerd_install() {
	dpkg -i containerd.io_1.5.10-1_amd64.deb
	dpkg -i docker-ce-cli_20.10.13~3-0~ubuntu-focal_amd64.deb
	dpkg -i docker-ce-rootless-extras_20.10.13~3-0~ubuntu-focal_amd64.deb
	dpkg -i docker-ce_20.10.13~3-0~ubuntu-focal_amd64.deb
	if [ ! -d $DOCKERD_PULGIN_DIR ]; then
		mkdir -p $DOCKERD_PULGIN_DIR
	fi
	cp docker-compose $DOCKERD_PULGIN_DIR/
	chmod +x $DOCKERD_PULGIN_DIR/docker-compose

}

## 导入基础/应用镜像
load_image() {
	arr=(${1//,/ })
	for image in "${arr[@]}"; do
		docker load -i "$image"
	done

}

## 更改网卡名
change_net() {
	change_net() {
		file=$(ls /etc/netplan/)
		read -p "更改网卡名可能会导致网络不可用(yes/no)?" tmp
		if [ "$tmp" == yes ]; then
			macaddr=$(cat /sys/class/net/"$S_NET_NAME"/address)
			sed "/${S_NET_NAME}/a\      match:\n        macaddress: $macaddr\n      set-name: ${T_NET_NAME}" /etc/netplan/${file} -i
			sed "s#${S_NET_NAME}#${T_NET_NAME}#g" /etc/netplan/"$file" -i
			netplan apply
		else
			return 1
		fi
	}

}

main() {
	check_arch
	check_os
	check_dockerd
	if [ $? -eq 1 ]; then
		dockerd_install
	fi
	set_max_map
	if [ "$DISK_DEV" ]; then
		format_disk
	fi
	load_image $images
	if [[ -z "$S_NET_NAME" || -z "$T_NET_NAME" ]]; then
		echo "更改网卡名需要两个参数,原名称与目标名称"
		exit 1
	else
		change_net
	fi
}

main
