#!/bin/bash

## NET_NAME  更改网卡名
## DISK_DEV  格式化磁盘并挂载
## DATA_DIR docker数据目录
DOCKERD_PULGIN_DIR=/usr/local/lib/docker/cli-plugins
images="zk.tar,broker.tar,bookie.tar,etcd.tar,es.tar,backend.tar,traefik.tar"

## set set_max_map_count=262144
set_max_map() {
	sed '$ a vm.max_map_count=262144' /etc/sysctl.conf -i
	sysctl -p
}

## 格式化磁盘、挂载、docker目录链接/data/
format_disk() {
	if [ ! $DATA_DIR ]; then
		DATA_DIR="/data"
	fi
	mkfs.ext4 $DATA_DISK
	if [ ! -d $DATA_DIR ]; then
		mkdir $DATA_DIR
		echo UUID=$(blkid ${DISK_DEV} | awk -F '"' '{print $2}') $DATA_DIR ext4 defaults 0 1 >>/etc/fstab
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
		docker load -i image
	done

}

## 更改网卡名
change_net() {
	read -p "更改网卡名会导致重启机器(yes/no)?" tmp
	if [ $tmp == yes ]; then
		sed 's#GRUB_CMDLINE_LINUX=""#GRUB_CMDLINE_LINUX="net.ifnames=0"#g' /etc/default/grup
		sed "s#${NET_NAME}#eth0#g" /etc/netplan/00-installer-config.yaml
		echo "reboot"
	else
		return 1
	fi
}

main() {
	dockerd_install
	set_max_map
	if [ $DISK_DEV ]; then
		format_disk
	fi
	load_image $images
	if [ $NET_NAME ]; then
		change_net
	fi
}

main
