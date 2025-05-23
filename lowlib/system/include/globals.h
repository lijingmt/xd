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

#define WEB_ROOT	        "/home/httpd/html/xd/"  //前台页面根目录
#define DATA_ROOT		ROOT "/data_xiand/"//用户数据根目录
#define GAME_BASE_DATA_ROOT	ROOT "/gamelib/data/"        //游戏基础数据根目录（各区一致的数据）
#define GAME_EXTEND_DATA_ROOT	ROOT "/gamelib/etc/"         //游戏扩展数据根目录（各区不一致的数据）
#define ITEM_PATH		ROOT "/gamelib/clone/item/"  //物品根目录
#define NPC_PATH		ROOT "/gamelib/clone/npc/"   //物品根目录
#define GAME_NAME		"xd"//游戏区名
#define DATABASE_NAME           "xiand"//拍卖行数据库
#define DATABASE_COUNT_NAME     "xd_game_db"//游戏资料数据库
#define COUNT_TABLE_NAME        "xd_game_db"//统计数据表名
#define GAME_NAME_S		"xd"//游戏区名简写 
#define GAME_NAME_CN		"天下仙道网游一区"//游戏区中文名 
#define GAME_AREA		"xd01" //用于区分不同区的字段，有一些区限制等级，可以用这个字段区分 
//#define GAME_URL		"xd.dogstart.com"//仙道首页 
#define GAME_URL		"tx.wapmud.com"//仙道首页 
#define IP                      "127.0.0.1"//socket连接IP
#define PORT                    13800//socket连接端口号
#define INDEX_URL               "tx.wapmud.com/xd/pc.jsp"//游戏登陆页
#define REG_URL                 "tx.wapmud.com/xd/pc.jsp"//注册页
//#define ROOT		        "/usr/local/games/xiand00"//游戏根目录 在sys_config.h中定义
//#define SROOT		        "/usr/local/games/xiand00/lowlib"//游戏底层根目录 在sys_config.h中定义

#endif
