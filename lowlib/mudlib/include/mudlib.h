#ifndef __MUDLIB__
#define __MUDLIB__
#include <globals.h>

#define MUD_USER		SROOT "/mudlib/inherit/user"//继承人物基本属性
#define MUD_ITEM		SROOT "/mudlib/inherit/item"//继承物品基本属性
#define MUD_COMBINE_ITEM	SROOT "/mudlib/inherit/combine_item"//继承物品复数基本属性
#define MUD_NPC			SROOT "/mudlib/inherit/npc"//继承怪物基本属性
#define MUD_ROOM		SROOT "/mudlib/inherit/room"//继承房间基本属性

#define MUD_VIEW		SROOT "/mudlib/clone/view"//视图表示基本方法调用

#define MUD_F_EQUIP		SROOT "/mudlib/inherit/feature/equip"//物品的装备类别中可装备属性继承
#define MUD_WEAPON		SROOT "/mudlib/inherit/weapon"//物品中武器属性继承
#define MUD_ARMOR		SROOT "/mudlib/inherit/armor"//物品中防具属性继承
#define MUD_JEWELRY		SROOT "/mudlib/inherit/jewelry"//物品中首饰属性继承
#define MUD_DECORAT		SROOT "/mudlib/inherit/decorat"//物品中饰物属性继承
#define MUD_MATERIAL		SROOT "/mudlib/inherit/material"//物品中原材料属性继承

//#define MUD_DESCRIB		SROOT "/mudlib/inherit/describ"//物品中按属性组合描述属性继承

//物品中的书
#define MUD_F_READ		SROOT "/mudlib/inherit/feature/readed"//物品中书的继承方法
#define MUD_BOOK		SROOT "/mudlib/inherit/book"//物品的书类别中属性继承
#define MUD_BOX			SROOT "/mudlib/inherit/box"//物品的箱子类别中属性继承
//矿源等基本材料来源物品
#define MUD_SOURCE		SROOT "/mudlib/inherit/source"
//炼金的丹药
#define MUD_DANYAO		SROOT "/mudlib/inherit/danyao"
//用于收费玉石，由liaocheng于07/11/7添加
#define MUD_YUSHI               SROOT "/mudlib/inherit/yushi"
//食物类中固体食物
#define MUD_F_EATED		SROOT "/mudlib/inherit/feature/eated"//物品的非装备类别中可食用属性继承
#define MUD_FOOD		SROOT "/mudlib/inherit/food"//物品的食品食物类别中属性继承
//食物类中液体饮料
#define MUD_F_DRINKED		SROOT "/mudlib/inherit/feature/drinked"//物品的非装备类别中可饮用属性继承
#define MUD_WATER		SROOT "/mudlib/inherit/water"//物品的食品药水类别中属性继承

#define MUD_F_CHAR		SROOT "/mudlib/inherit/feature/char"//所有角色基本属性继承
#define MUD_F_ATTACK		SROOT "/mudlib/inherit/feature/attack"//所有角色战斗属性继承
#define MUD_F_HEARTBEAT 	SROOT "/mudlib/inherit/feature/heartbeat"//心跳方法继承
#define MUD_F_INIT		SROOT "/mudlib/inherit/feature/init"//所有物品初始化方法继承
#define MUD_F_ITEMS		SROOT "/mudlib/inherit/feature/items"//物品世界影射
#define MUD_F_LIFES		SROOT "/mudlib/inherit/feature/lifes"//生物世界影射

//玩家等级////////////////////////////////
#define MUD_F_LEVEL		SROOT "/mudlib/inherit/feature/level"//角色等级，经验值属性

//技能系统////////////////////////////////
#define MUD_SKILLSD		((object)(SROOT "/mudlib/single/skillsd"))//技能存储器
#define MUD_SKILL		SROOT "/mudlib/inherit/skill"//技能基本属性继承


//家园系统 infancy        added by Evan 2008.09.04
#define MUD_INFANCY             SROOT "/mudlib/inherit/infancy"// 种子/树苗/矿源 等生长基础物品
//end of Evan added 2008.09.04

//由liaocheng于07/08/23添加，用于人推人系统
#define MUD_PRESENTD        	((object)(SROOT "/mudlib/single/presentd"))

#define MUD_EMOTED		((object)(SROOT "/mudlib/single/emoted"))//动作表情系统
#define MUD_APPEARANCED 	((object)(SROOT "/mudlib/single/appearanced"))//容貌描述系统
#define MUD_CHINESED		((object)(SROOT "/mudlib/single/chinesed"))//数字转换中文系统
#define MUD_MONEYD		((object)(SROOT "/mudlib/single/moneyd"))//通用金钱处理系统
#define MUD_STORED		((object)(SROOT "/mudlib/single/stored"))//游戏中商店买卖系统
#define MUD_ROOMD 		((object)(SROOT "/mudlib/single/roomd.pike"))//动态刷新房间npc等级

#define MUD_F_GHOST		SROOT "/mudlib/inherit/feature/ghost"//死亡处理流程

#define MUD_TIMESD 		((object)(SROOT "/mudlib/single/timesd.pike"))//时间接口，统计用

#define STACK_NUM		30//复数物品的堆叠数目上限

#endif
