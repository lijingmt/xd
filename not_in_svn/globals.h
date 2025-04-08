#ifndef __GLOBALS__
#define __GLOBALS__

#include <sys_config.h>

#define __NO_WIZARDS__

#define read_only(varname) mixed query_##varname(){return varname;}
#define read_write(varname) mixed query_##varname(){return varname;};void set_##varname(mixed v){varname=v;}
#define write_only(varname) void set_##varname(mixed v){varname=v;}

#define VARINFO(varname) werror(#varname+"=%O\n",(varname))

#define LOW_GLOBAL	   ((object)(SROOT "/system/single/globald"))

#define LOW_LOGIN_OB		SROOT "/system/clone/login"
#define LOW_USER_OB		SROOT "/system/clone/user"
#define LOW_VOID_OB		SROOT "/system/single/void"

#define LOW_BASE		SROOT "/system/inherit/base"
#define LOW_USER		SROOT "/system/inherit/user"
#define LOW_FILTER		SROOT "/system/inherit/filter"
#define LOW_DAEMON		SROOT "/system/inherit/daemon"

#define COMMAND_PREFIX		SROOT "/system/cmds/"

#define LOW_F_DBASE		SROOT "/system/inherit/feature/dbase"
#define LOW_F_CMDS		SROOT "/system/inherit/feature/cmds"
#define LOW_F_SAVE		SROOT "/system/inherit/feature/save"
#define LOW_F_ACCESS		SROOT "/system/inherit/feature/access"
#define LOW_F_HIDDEN		SROOT "/system/inherit/feature/hidden"

#define FILTER_PREFIX		SROOT "/system/filter/"

#define DATA_ROOT		"/usr/local/games/xdxdxd/udtestII/"//�û����ݸ�Ŀ¼
#define WEB_ROOT	        "/home/httpd/html/xdxdxd/xdtestII/"//ǰ̨ҳ���Ŀ¼
#define ITEM_PATH		ROOT "/gamelib/clone/item/"//��Ʒ��Ŀ¼
#define NPC_PATH		ROOT "/gamelib/clone/npc/"//��Ʒ��Ŀ¼
#define GAME_NAME		"xdtestII"//��Ϸ����
#define DATABASE_NAME           "xdtestII"//���������ݿ�
#define DATABASE_COUNT_NAME     "xd_game_db"//��Ϸ�������ݿ�
#define COUNT_TABLE_NAME        "xd_game_db"//ͳ�����ݱ���
#define GAME_NAME_S		"xdtestII"//��Ϸ������д 
#define GAME_NAME_CN		"�ɵ�����"//��Ϸ�������� 
#define GAME_URL		"xd.dogstart.com"//�ɵ���ҳ 
#define IP                      "127.0.0.1"//socket����IP
#define PORT                    9999//socket���Ӷ˿ں�
#define INDEX_URL               "222.73.44.147/xdxdxd/xdtestII/index.jsp"//��Ϸ��½ҳ
#define REG_URL                 "222.73.44.147/xdxdxd/xdtestII/regnew.jsp"//ע��ҳ
//#define ROOT		        "/usr/local/games/xiand0"//��Ϸ��Ŀ¼ ��sys_config.h�ж���
//#define SROOT		        "/usr/local/games/xiand0/lowlib"//��Ϸ�ײ��Ŀ¼ ��sys_config.h�ж���

#endif
