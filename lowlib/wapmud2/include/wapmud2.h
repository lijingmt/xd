#ifndef __WAPMUD2__
#define __WAPMUD2__
#include <mudlib/include/mudlib.h>

#define WAP_ROOM		SROOT "/wapmud2/inherit/room"//房间
#define WAP_NPC			SROOT "/wapmud2/inherit/npc"//npc
#define WAP_ITEM		SROOT "/wapmud2/inherit/item"//物品
#define WAP_COMBINE_ITEM	SROOT "/wapmud2/inherit/combine_item"//叠加物品
#define WAP_LIFE		SROOT "/wapmud2/inherit/life"//生物【家园】 Evan added 2008.9.8
#define WAP_USER		SROOT "/wapmud2/inherit/user"//角色

#define WAP_SKILL 		SROOT "/wapmud2/inherit/skill"//技能
#define WAP_WEAPON		SROOT "/wapmud2/inherit/weapon"//武器
#define WAP_ARMOR		SROOT "/wapmud2/inherit/armor"//防具
#define WAP_JEWELRY		SROOT "/wapmud2/inherit/jewelry"//首饰
#define WAP_DECORATE		SROOT "/wapmud2/inherit/decorate"//饰物
#define WAP_FOOD		SROOT "/wapmud2/inherit/food"//食物
#define WAP_SOURCE      	SROOT "/wapmud2/inherit/source"//材料源                                     
#define WAP_DANYAO      	SROOT "/wapmud2/inherit/danyao"//炼金的丹药
#define WAP_WATER		SROOT "/wapmud2/inherit/water"//饮料
#define WAP_BOOK		SROOT "/wapmud2/inherit/book"//书，学习技能
#define WAP_YUSHI               SROOT "/wapmud2/inherit/yushi"//玉石
#define WAP_BAOXIANG            SROOT "/wapmud2/inherit/baoxiang"//宝箱
#define WAP_HONGBAO             SROOT "/wapmud2/inherit/hongbao"//红包                                            
#define WAP_TRANSFER            SROOT "/wapmud2/inherit/transfer"//传送道具
#define WAP_INFANCY             SROOT "/wapmud2/inherit/infancy"//【家园】种子/树苗/幼崽/矿源
#define WAP_GROWN               SROOT "/wapmud2/inherit/grown"//【家园】树/花/草/动物/矿
#define WAP_FEED               	SROOT "/wapmud2/inherit/feed"//【家园】饲料
#define WAP_BAOSHI 		SROOT "/wapmud2/inherit/baoshi"//宝石

#define WAP_F_FIGHT			SROOT "/wapmud2/inherit/feature/fight"//战斗系统
#define WAP_F_CATCH_TELL		SROOT "/wapmud2/inherit/feature/catch_tell"//信息缓存
#define WAP_F_VIEW_LINKS		SROOT "/wapmud2/inherit/feature/links"//额外连接
#define WAP_F_VIEW_VALUE		SROOT "/wapmud2/inherit/feature/value"//价值->中文
#define WAP_F_VIEW_INVENTORY		SROOT "/wapmud2/inherit/feature/inventory"//世界->角色，物品视图
#define WAP_F_VIEW_EXITS		SROOT "/wapmud2/inherit/feature/exits"//出口描述
#define WAP_F_VIEWSTACK			SROOT "/wapmud2/inherit/feature/viewstack"//视图堆栈
#define WAP_F_VIEW_PICTURE		SROOT "/wapmud2/inherit/feature/picture"//页面图片
#define WAP_F_VIEW_SKILLS		SROOT "/wapmud2/inherit/feature/skills"//调用技能视图
#define WAP_F_QQLIST			SROOT "/wapmud2/inherit/feature/qqlist"//好友系统    
#define WAP_F_MBOX			SROOT "/wapmud2/inherit/feature/mbox"//邮箱系统

#define WAP_VIEWD		((object)(SROOT "/wapmud2/single/viewd"))//游戏视图系统

#define WAP_HONERD		((object)(SROOT "/wapmud2/single/honerd"))//游戏荣誉系统
//帮派守护模块
#define BANGD ((object)(SROOT "/wapmud2/single/bangd"))
//帮战守护模块
#define BANGZHAND ((object)(SROOT "/wapmud2/single/bangzhand"))
#endif
