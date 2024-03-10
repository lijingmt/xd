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

#define WEB_ROOT	        "/home/httpd/html/xd/"  //ǰ̨ҳ���Ŀ¼
#define DATA_ROOT		"/usr/local/games/data_xiand/"//�û����ݸ�Ŀ¼
#define GAME_BASE_DATA_ROOT	ROOT "/gamelib/data/"        //��Ϸ�������ݸ�Ŀ¼������һ�µ����ݣ�
#define GAME_EXTEND_DATA_ROOT	ROOT "/gamelib/etc/"         //��Ϸ��չ���ݸ�Ŀ¼��������һ�µ����ݣ�
#define ITEM_PATH		ROOT "/gamelib/clone/item/"  //��Ʒ��Ŀ¼
#define NPC_PATH		ROOT "/gamelib/clone/npc/"   //��Ʒ��Ŀ¼
#define GAME_NAME		"xd"//��Ϸ����
#define DATABASE_NAME           "xiand"//���������ݿ�
#define DATABASE_COUNT_NAME     "xd_game_db"//��Ϸ�������ݿ�
#define COUNT_TABLE_NAME        "xd_game_db"//ͳ�����ݱ���
#define GAME_NAME_S		"xd"//��Ϸ������д 
#define GAME_NAME_CN		"�����ɵ�����һ��"//��Ϸ�������� 
//#define GAME_URL		"xd.dogstart.com"//�ɵ���ҳ 
#define GAME_URL		"tx.wapmud.com"//�ɵ���ҳ 
#define IP                      "127.0.0.1"//socket����IP
#define PORT                    13800//socket���Ӷ˿ں�
#define INDEX_URL               "tx.wapmud.com/xd/pc.jsp"//��Ϸ��½ҳ
#define REG_URL                 "tx.wapmud.com/xd/pc.jsp"//ע��ҳ
//#define ROOT		        "/usr/local/games/xiand00"//��Ϸ��Ŀ¼ ��sys_config.h�ж���
//#define SROOT		        "/usr/local/games/xiand00/lowlib"//��Ϸ�ײ��Ŀ¼ ��sys_config.h�ж���

#endif
