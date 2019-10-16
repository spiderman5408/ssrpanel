#!/bin/bash
#Time: 2018-4-14 10:10:41
#Author: marisn
#Blog: blog.67cc.cn
#更新日志：

#2018-8-24 09:07:33
#更新500错误
#优化lnmp搭建

#2018-5-13 11:31:59
#增加系统检测，避免错误

#2018-5-7 13:19:52
#修复CyMySQL

#2018-4-14 10:12:57
#1.采用最新官网生产版搭建，避免不必要的错误
#2.优化lnmp的搭建
#3.修复搭建失败
#4.数据库采用端口888访问
[ $(id -u) != "0" ] && { echo "错误: 您必须以root用户运行此脚本"; exit 1; }
function check_system(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
	if [[ ${release} == "centos" ]] && [[ ${bit} == "x86_64" ]]; then
	echo -e "你的系统为[${release} ${bit}],检测\033[32m 可以 \033[0m搭建。"
	else 
	echo -e "你的系统为[${release} ${bit}],检测\033[31m 不可以 \033[0m搭建。"
	echo -e "\033[31m 正在退出脚本... \033[0m"
	exit 0;
	fi
}
function install_ssrpanel(){
	yum -y remove httpd
	yum install -y unzip zip git gzip
	yum update nss curl iptables -y
	#自动选择下载节点
	GIT='raw.githubusercontent.com'
	MY='coding.net'
	GIT_PING=`ping -c 1 -w 1 $GIT|grep time=|awk '{print $7}'|sed "s/time=//"`
	MY_PING=`ping -c 1 -w 1 $MY|grep time=|awk '{print $7}'|sed "s/time=//"`
	echo "$GIT_PING $GIT" > ping.pl
	echo "$MY_PING $MY" >> ping.pl
	fileinfo=`sort -V ping.pl|sed -n '1p'|awk '{print $2}'`
	if [ "$fileinfo" == "$GIT" ];then
		Download='https://raw.githubusercontent.com/spiderman5408/ssrpanel/master'
	else
		Download='https://coding.net/u/marisn/p/ssrpanel/git/raw/master'
	fi
	rm -f ping.pl	
	wget -c --no-check-certificate "${Download}/lnmp1.5.zip" && unzip lnmp1.5.zip && rm -rf lnmp1.5.zip && cd lnmp1.5 && chmod +x install.sh && ./install.sh
	clear
	#安装fileinfo必须组件
	#cd /root && wget --no-check-certificate "${Download}/fileinfo.zip"
	#File="/root/fileinfo.zip"
    #if [ ! -f "$File" ]; then  
    #echo "fileinfo组件下载失败，请检查/root/fileinfo.zip"
	#exit 0;
	#else
    #unzip fileinfo.zip
    #fi
    cd /home/wwwroot/
	cp -r default/phpmyadmin/ .  #复制数据库
	cd default
	rm -rf index.html
	#获取git最新released版文件 适用于生产环境
	ssrpanel_new_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/marisn2017/ssrpanel_resource/releases | grep -o '"tag_name": ".*"' |head -n 1| sed 's/"//g;s/v//g' | sed 's/tag_name: //g')
	#wget -c --no-check-certificate "https://github.com/spiderman5408/ssrpanel_resource/archive/V4.8.0.tar.gz"
	#tar zxvf "V4.8.0.tar.gz" && cd ssrpanel_resource-* && mv * .[^.]* ..&& cd /home/wwwroot/default && rm -rf "V4.8.0.tar.gz"
	git clone https://github.com/marisn2017/ssrpanel_resource.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
	#替换数据库配置
	cp .env.example .env
	wget -N -P /usr/local/php/etc/ "${Download}/php.ini"
	wget -N -P /usr/local/nginx/conf/ "${Download}/nginx.conf"
	service nginx restart
	#设置数据库
	#mysql -uroot -proot -e"create database ssrpanel;" 
	#mysql -uroot -proot -e"use ssrpanel;" 
	#mysql -uroot -proot ssrpanel < /home/wwwroot/default/sql/db.sql
	#开启数据库远程访问，以便对接节点
	#mysql -uroot -proot -e"use mysql;"
	#mysql -uroot -proot -e"GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;"
	#mysql -uroot -proot -e"flush privileges;"
mysql -hlocalhost -uroot -proot --default-character-set=utf8mb4<<EOF
create database ssrpanel;
use ssrpanel;
source /home/wwwroot/default/sql/db.sql;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;
flush privileges;
EOF
	#安装依赖
	cd /home/wwwroot/default/
	php composer.phar install
	php artisan key:generate
	cd /home/wwwroot/default/
	chown -R www:www storage/
	chmod -R 777 storage/
	service nginx restart
    service php-fpm restart
	#开启日志监控
	yum -y install vixie-cron crontabs
	rm -rf /var/spool/cron/root
	echo '* * * * * php /home/wwwroot/default/artisan schedule:run >> /dev/null 2>&1' >> /var/spool/cron/root
	service crond restart
	#修复数据库
	# mv /home/wwwroot/default/phpmyadmin/ /home/wwwroot/default/public/
	# cd /home/wwwroot/default/public/phpmyadmin
	# chmod -R 755 *
	lnmp restart
	IPAddress=`wget http://members.3322.org/dyndns/getip -O - -q ; echo`;
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	echo "# 一键安装已完成，请访问http://${IPAddress}查看~                   #"
	echo "# 一键安装ssrpanel前端面板已完成                                   #"
	echo "# Author: marisn          Ssrpanel:ssrpanel                        #"
	echo "# Blog: http://blog.67cc.cn/                                       #"
	echo "# Github: https://github.com/marisn2017/ssrpanel                   #"
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
}
function install_log(){
    myFile="/root/shadowsocksr/ssserver.log"  
	if [ ! -f "$myFile" ]; then  
    echo "您的shadowsocksr环境未安装"
	echo "请检查/root/shadowsocksr/ssserver.log是否存在"
	else
	cd /home/wwwroot/default/storage/app/public
	ln -S ssserver.log /root/shadowsocksr/ssserver.log
	chown www:www ssserver.log
	chmod 0777 /home/wwwroot/default/storage/app/public/ssserver.log
	chmod 777 -R /home/wwwroot/default/storage/logs/
	echo "日志分析（仅支持单机单节点） - 安装成功"
    fi
}
function change_password(){
	echo -e "\033[31m注意:必须正确填写数据库密码，否则只能手动修改。\033[0m"
	read -p "请输入数据库密码(初始密码为root):" Default_password
	Default_password=${Default_password:-"root"}
	read -p "请输入要设置的数据库密码:" Change_password
	Change_password=${Change_password:-"root"}
	echo -e "\033[31m您设置的密码是:${Change_password}\033[0m"
mysql -hlocalhost -uroot -p$Default_password --default-character-set=utf8<<EOF
use mysql;
update user set password=passworD("${Change_password}") where user='root';
flush privileges;
EOF
	echo "开始在设置文件中替换数据库信息..."
	myFile="/root/shadowsocksr/server.py"
    if [ ! -f "$myFile" ]; then  
    sed -i "s/'password' => '"${Default_password}"'/'password' => '"${Change_password}"'/g" /home/wwwroot/default/config/database.php
	echo "数据库密码已完成，请记住。."
	echo "您设置的密码是:${Change_password}"
	else
	sed -i 's/"password": "'${Default_password}'",/"password": "'${Change_password}'",/g' /root/shadowsocksr/usermysql.json
	sed -i "s/'password' => '"${Default_password}"'/'password' => '"${Change_password}"'/g" /home/wwwroot/default/config/database.php
	echo "重新启动配置以生效..."
	init 6
    fi

}
function install_ssr(){
	yum -y update
	yum -y install git 
	yum -y install python-setuptools && easy_install pip 
	yum -y groupinstall "Development Tools" 
	#512M chicks add 1 g of Swap
	dd if=/dev/zero of=/var/swap bs=1024 count=1048576
	mkswap /var/swap
	chmod 0644 /var/swap
	swapon /var/swap
	echo '/var/swap   swap   swap   default 0 0' >> /etc/fstab
	#自动选择下载节点
	GIT='raw.githubusercontent.com'
	LIB='download.libsodium.org'
	GIT_PING=`ping -c 1 -w 1 $GIT|grep time=|awk '{print $7}'|sed "s/time=//"`
	LIB_PING=`ping -c 1 -w 1 $LIB|grep time=|awk '{print $7}'|sed "s/time=//"`
	echo "$GIT_PING $GIT" > ping.pl
	echo "$LIB_PING $LIB" >> ping.pl
	libAddr=`sort -V ping.pl|sed -n '1p'|awk '{print $2}'`
	if [ "$libAddr" == "$GIT" ];then
		libAddr='https://raw.githubusercontent.com/spiderman5408/ss-panel-v3-mod_Uim/master/libsodium-1.0.17.tar.gz'
	else
		libAddr='https://download.libsodium.org/libsodium/releases/libsodium-1.0.17.tar.gz'
	fi
	rm -f ping.pl
	wget --no-check-certificate $libAddr
	tar xf libsodium-1.0.17.tar.gz && cd libsodium-1.0.17
	./configure && make -j2 && make install
	echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
	ldconfig
	cd /root && rm -rf libsodium*
	yum -y install python-setuptools
	easy_install supervisor
    cd /root
	wget https://raw.githubusercontent.com/spiderman5408/ssrpanel/master/shadowsocksr.zip
	unzip shadowsocksr.zip
	cd shadowsocksr
	./initcfg.sh
	chmod 777 *
	wget -N -P /root/shadowsocksr/ https://raw.githubusercontent.com/spiderman5408/ssrpanel/master/user-config.json
	wget -N -P /root/shadowsocksr/ https://raw.githubusercontent.com/spiderman5408/ssrpanel/master/userapiconfig.py
	wget -N -P /root/shadowsocksr/ https://raw.githubusercontent.com/spiderman5408/ssrpanel/master/usermysql.json
	sed -i "s#Userip#${Userip}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbuser#${Dbuser}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbport#${Dbport}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbpassword#${Dbpassword}#" /root/shadowsocksr/usermysql.json
	sed -i "s#Dbname#${Dbname}#" /root/shadowsocksr/usermysql.json
	sed -i "s#UserNODE_ID#${UserNODE_ID}#" /root/shadowsocksr/usermysql.json
	yum -y install lsof lrzsz
	yum -y install python-devel
	yum -y install libffi-devel
	yum -y install openssl-devel
	yum -y install iptables
	systemctl stop firewalld.service
	systemctl disable firewalld.service
}
function install_node(){
	clear
	echo
    echo -e "\033[31m Add a node...\033[0m"
	echo
	sed -i '$a * hard nofile 512000\n* soft nofile 512000' /etc/security/limits.conf
	[ $(id -u) != "0" ] && { echo "错误: 您必须以root用户运行此脚本"; exit 1; }
	echo -e "如果你不知道，你可以直接回车。"
	echo -e "如果连接失败，请检查数据库远程访问是否打开。"
	read -p "请输入您的对接数据库IP(回车默认为本地IP地址):" Userip
	read -p "请输入数据库名称(回车默认为ssrpanel):" Dbname
	read -p "请输入数据库端口(回车默认为3306):" Dbport
	read -p "请输入数据库帐户(回车默认为root):" Dbuser
	read -p "请输入数据库密码(回车默认为root):" Dbpassword
	read -p "请输入您的节点编号(回车默认为1):  " UserNODE_ID
	IPAddress=`wget http://members.3322.org/dyndns/getip -O - -q ; echo`;
	Userip=${Userip:-"${IPAddress}"}
	Dbname=${Dbname:-"ssrpanel"}
	Dbport=${Dbport:-"3306"}
	Dbuser=${Dbuser:-"root"}
	Dbpassword=${Dbpassword:-"root"}
	UserNODE_ID=${UserNODE_ID:-"1"}
	install_ssr
    # 启用supervisord
	echo_supervisord_conf > /etc/supervisord.conf
	sed -i '$a [program:ssr]\ncommand = python /root/shadowsocksr/server.py\nuser = root\nautostart = true\nautorestart = true' /etc/supervisord.conf
	supervisord
	#iptables
	iptables -F
	iptables -X  
	iptables -I INPUT -p tcp -m tcp --dport 22:65535 -j ACCEPT
	iptables -I INPUT -p udp -m udp --dport 22:65535 -j ACCEPT
	iptables-save >/etc/sysconfig/iptables
	iptables-save >/etc/sysconfig/iptables
	echo 'iptables-restore /etc/sysconfig/iptables' >> /etc/rc.local
	echo "/usr/bin/supervisord -c /etc/supervisord.conf" >> /etc/rc.local
	chmod +x /etc/rc.d/rc.local
	touch /root/shadowsocksr/ssserver.log
	chmod 0777 /root/shadowsocksr/ssserver.log
	cd /home/wwwroot/default/storage/app/public/
	ln -S ssserver.log /root/shadowsocksr/ssserver.log
    chown www:www ssserver.log
	chmod 777 -R /home/wwwroot/default/storage/logs/
	clear
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	echo "#                    成功添加节点请登录到前端站点查看              #"
	echo "#                     正在重新启动系统使节点生效……                 #"
	echo "#              Author: marisn          Ssrpanel:ssrpanel           #"
	echo "#              Blog: http://blog.67cc.cn/                          #"
	echo "#              Github: https://github.com/marisn2017/ssrpanel      #"
	echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
	reboot
}
function install_BBR(){
     wget --no-check-certificate https://github.com/spiderman5408/across/raw/master/bbr.sh&&chmod +x bbr.sh&&./bbr.sh
}
function install_RS(){
     wget -N --no-check-certificate https://github.com/spiderman5408/serverspeeder/raw/master/serverspeeder.sh && bash serverspeeder.sh
}
Install_Ssrpanel_Web_to_Bt()
{
    Echo_Yellow "此脚本为ssrpanel对接宝塔，请确认你已经认真看了搭建前的教程？"
	read -p "y/n?" ABCD
	if [[ "$ABCD" != "y" ]];then
	Echo_Red "教程地址:https://sybk.tw/archives/commercial-version-of-oneclick-script-has-been-released.html"
	exit 0;
	fi
	clear
	echo -e "欢迎使用 [\033[34m ssrpanel 宝塔快速部署工具 \033[0m]"
	echo "----------------------------------------------------------------------------"
	echo -e "请注意这个要求：宝塔版本=\033[31m 5.9 \033[0m,php版本=\033[31m 7.1\033[0m ！"
	echo "----------------------------------------------------------------------------"
	echo -e "\033[1;5;33m请在搭建前认真看清楚搭建所需要的环境，请勿直接搭建\033[0m"
	echo "----------------------------------------------------------------------------"
	sleep 2
	read -p "请输入宝塔面板添加的网站域名：(请不要修改添加之后的默认地址，只输入域名即可)" Input_Web
	# if [["$Input_Web" == ""]];then
		# Echo_Red "请勿回车"
		# exit 0;
	# fi
	#read -p "请输入网站目录(eg:/www/wwwroot/www.baidu.com)[此配置很重要,错误导致将搭建失败]" Input_MU
	read -p "请输入宝塔面板添加的MySQL用户名：" Input_Dbuser
	Input_Dbuser=${Input_Dbuser:-"ssrpanel"}
	read -p "请输入宝塔面板添加的MySQL密码：" Input_Dbpwd
	Input_Dbpwd=${Input_Dbpwd:-"root"}
	sleep 1
	echo "请等待系统自动操作......"
	yum update -y
	yum install epel-* -y
	yum install gcc  gcc-c++ unzip zip   -y 
	vphp='7.1'
	version='71'
	Download_speed_test
	echo "正在安装fileinfo到服务器......";
	if [ ! -d "/www/server/php/71/src/ext/fileinfo" ];then
	wget -O ext-71.zip https://raw.githubusercontent.com/spiderman5408/donation_shell/master/ext-71.zip
	unzip -o ext-71.zip -d /www/server/php/71/ > /dev/null
	rm -f ext-71.zip
	fi
	cd /www/server/php/71/
	mv ext-71 ext
	cd /www/server/php/71/ext/fileinfo
	/www/server/php/71/bin/phpize
	./configure --with-php-config=/www/server/php/71/bin/php-config
	make && make install
	echo -e " extension = \"fileinfo.so\"\n" >> /www/server/php/71/etc/php.ini
	service php-fpm-71 reload
	echo '==============================================='
	echo 'fileinfo安装完成!'
	sleep 1
	echo "正在安装依赖环境......";
	sleep 2
	cd /www/wwwroot/${Input_Web}
	rm -rf index.html 404.html
	#下载官方源码
	git clone https://github.com/spiderman5408/ssrpanel_resource.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
	chown -R root:root *
	chmod -R 755 *
	chown -R www:www storage
	sed -i 's/proc_open,//g' /www/server/php/71/etc/php.ini
	sed -i 's/system,//g' /www/server/php/71/etc/php.ini
	sed -i 's/proc_get_status,//g' /www/server/php/71/etc/php.ini 
	sed -i 's/putenv,//g' /www/server/php/71/etc/php.ini    
	cd /www/wwwroot/${Input_Web}
    cp .env.example .env
	sed -i '/DB_DATABASE/c \DB_DATABASE='${Input_Dbuser}'' .env
	sed -i '/DB_USERNAME/c \DB_USERNAME='${Input_Dbuser}'' .env
	sed -i '/DB_PASSWORD/c \DB_PASSWORD='${Input_Dbpwd}'' .env
	mysql -u${Input_Dbuser} -p${Input_Dbpwd} ${Input_Dbuser} < /www/wwwroot/${Input_Web}/sql/db.sql >/dev/null 2>&1
	wget https://getcomposer.org/installer -O composer.phar
	php composer.phar
	php composer.phar install
	php artisan key:generate
	clear
	chown -R www:www storage/
	chmod -R 777 storage/
	sleep 3
	#修改伪静态以及默认路径
	sed -i "s/\/www\/wwwroot\/$Input_Web/\/www\/wwwroot\/$Input_Web\/public/g" /www/server/panel/vhost/nginx/${Input_Web}.conf
	echo '
	location / {
	  try_files $uri $uri/ /index.php$is_args$args;
	  }
	' >/www/server/panel/vhost/rewrite/${Input_Web}.conf
	echo "正在重启php&Nginx服务..."
	service php-fpm-71 reload
	service nginx reload
	echo "----------------------------------------------------------------------------"
	echo "部署完成，请打开http://$Input_Web即可浏览"
	echo "默认用户名&密码：admin   123456 第一次登陆请务必到后台修改密码！"
	echo "如果打不开站点，请到宝塔面板中软件管理重启nginx和php7.1"
	echo "这个原因触发几率<10%，原因是修改配置后需要重启Nginx服务和php服务才能正常运行"
	echo "----------------------------------------------------------------------------"
}

Install_Ssrpanel_Web()
{
    clear
    Echo_Green "Start configuring the site parameters..."
	read -p "设置数据库密码[回车默认为root]: " DB_PASS
	DB_PASS=${DB_PASS:-"root"}
	Echo_Green "你设置的密码为 ${DB_PASS}"
	echo -e "\033[1;5;31m即将开始搭建网站环境，此过程较耗时，请耐心等待...\033[0m"
	sleep 5
    if [[ `ps -ef | grep nginx |grep -v grep | wc -l` -ge 1 ]];then
	Echo_Red "提示本机存有nginx环境，跳过环境搭建"
	mkdir /data/wwwroot/default/
	else
	Install_Oneinstack
	cd /root/oneinstack && rm -rf addons.sh
	wget -N -P /root/oneinstack/ --no-check-certificate ${Download}/addons.sh  >/dev/null 2>&1
		if [[ ! -f "/root/oneinstack/addons.sh" ]];then
		wget -N -P /root/oneinstack/ --no-check-certificate https://raw.githubusercontent.com/spiderman5408/donation_shell/master/addons.sh
		echo "fileinfo环境未搭建" > /root/error.log
		fi
	chmod +x addons.sh && ./addons.sh
	fi
	clear
	echo -e "\033[1;5;31m即将开始安装所需依赖...\033[0m"
	sleep 2
	${PM} install unzip zip git -y >/dev/null 2>&1
	echo -e "\033[1;5;31m即将开始安装WEB环境...\033[0m"
	#进入网站目录
	cd /data/wwwroot/default/ 
	#删除首页静态文件
	rm -rf index.html 
	#测试节点ping
	Download_speed_test
	#下载官方源码
	if [[ ! -d "/data/wwwroot/default/config/" ]];then
	git clone https://github.com/spiderman5408/ssrpanel_resource.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
	fi
	#修改源码权限
	chown -R root:root *
	chmod -R 777 *
	chown -R www:www storage
	#修改网站配置文件
	# wget -N -P /data/wwwroot/default/config/ -c --no-check-certificate "https://blog.67cc.cn/shell/config_new.conf"  >/dev/null 2>&1
	# cd /data/wwwroot/default/config/
    # mv config_new.conf .config.php && chmod 755 .config.php
	echo -e "\033[1;5;31m即将开始下载修改网站配置...\033[0m"
	cp .env.example .env
	sed -i '/DB_PASSWORD/c \DB_PASSWORD='${DB_PASS}'' .env
	#修改nginx php配置
	wget -N -P  /usr/local/nginx/conf/ --no-check-certificate ${Download}/nginx.conf  >/dev/null 2>&1
	wget -N -P /usr/local/php/etc/ --no-check-certificate ${Download}/php.ini  >/dev/null 2>&1
	#重启nginx
	service nginx restart
	echo -e "\033[1;5;31m即将开始导入数据库...\033[0m"
	#导入数据
mysql -hlocalhost -uroot -p${DB_PASS} <<EOF
create database ssrpanel;
use ssrpanel;
source /data/wwwroot/default/sql/db.sql;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${DB_PASS}' WITH GRANT OPTION;
flush privileges;
EOF
	#进入网站目录
	echo -e "\033[1;5;31m即将开始安装网站所需依赖...\033[0m"
	cd /data/wwwroot/default/ 
	#安装依赖
	wget https://getcomposer.org/installer -O composer.phar
	php composer.phar
	php composer.phar install
	php artisan key:generate
	chown -R www:www storage/
	chmod -R 755 storage/
	#设置phpMyAdmin权限
	chmod -R 755 /data/wwwroot/default/phpMyAdmin/
	service nginx restart
    service php-fpm restart
	echo -e "\033[1;5;31m即将开始创建监控...\033[0m"
	#创建监控
	${PM} -y install vixie-cron crontabs
	#rm -rf /var/spool/cron/root
	echo "* * * * * php /data/wwwroot/default/artisan schedule:run >> /dev/null 2>&1" > /var/spool/cron/root
	echo -e "\033[1;5;31m即将开始设置防火墙...\033[0m"
	#设置iptables 
	iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 3306 -j ACCEPT
	iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 888 -j ACCEPT
	iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
	iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
	if [[ ${PM}  == "yum" ]];then
	/sbin/service crond restart #重启cron
	service iptables save #保存iptables规则
	elif [[ ${PM}  == "apt-get" ]];then
	/etc/init.d/cron restart #重启cron
	iptables-save > /etc/iptables.up.rules #保存iptables规则
	else
	Echo_Red "Error saving iptables rule and cron."
	fi
}
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
ulimit -c 0
rm -rf stable-script*
clear
check_system
sleep 2
echo "#############################################################################"
echo "#                      欢迎使用一键安装ssrpanel和节点脚本。                 #"
echo "#请选择您想要搭建的脚本:                                                    #"
echo "#1.  宝塔环境下搭建ssrpanel前端面板(不包括节点)                                   #"
echo "#2.  一键安装ssrpanel节点(可单独搭建)                                       #"
echo "#3.  一键搭建BBR加速                                                        #"
echo "#4.  一键搭建锐速加速                                                       #"
echo "#5.  ssrpanel官方升级脚本(可能没什么luan用)                                 #"
echo "#6.  日志分析（仅支持单机单节点）                                           #" 
echo "#7.  一键更改数据库密码(仅适用于已搭建前端)                                 #" 
echo "#8.  单独搭建ssrpanel                                 #" 
echo "#                                PS:建议请先搭建加速再搭建ssrpanel相关。    #"
echo "#                                     此脚本仅适用于Centos 7. X 64位 系统   #"
echo "#############################################################################"
echo
read num
if [[ $num == "1" ]]
then
Install_Ssrpanel_Web_to_Bt
elif [[ $num == "2" ]]
then
install_node
elif [[ $num == "3" ]]
then
install_BBR
elif [[ $num == "4" ]]
then
install_RS
elif [[ $num == "5" ]]
then
cd /home/wwwroot/default/
chmod a+x update.sh && sh update.sh
elif [[ $num == "6" ]]
then
install_log
elif [[ $num == "7" ]]
then
change_password
elif [[ $num == "8" ]]
then
Install_Ssrpanel_Web
else 
echo '输入错误';
exit 0;
fi;
