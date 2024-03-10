#########################################################################
# File Name: restart.sh
# Author: genglut
# Mail: genglut@163.com
# Created Time: Sun 27 Feb 2022 04:42:55 PM CST
#########################################################################
#!/bin/bash


while true
do
	read -r -p "确定要重启游戏服务？ [Y/n] " input

	case $input in
		[yY][eE][sS]|[yY])
			echo "正在重启游戏服务......"
			/usr/local/games/xiand/all_restart.pike &
			exit 1
			;;

		[nN][oO]|[nN])
			echo "终止操作"
			exit 1	       	
			;;

		*)
		echo "无效输入..."
			;;
	esac
done




#pike8 /usr/local/games/xiand/all_restart.pike &
