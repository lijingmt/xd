#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
inherit WAP_ROOM;
inherit WAP_F_VIEW_INVENTORY;
inherit WAP_F_VIEW_EXITS;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;
//家园系统中，房间的特殊属性       
private string homeId = "";                    //home唯一标识，该home对应的路径
private string masterId = "";                  //主人ID
private string masterName = "";                //主人中文名
private string customName = "";                //家园自定义名称
private string customDesc = "";                //家园自定义描述  
private array(string) allowedUser = ({});      //允许进入home的用户ID列表
private int priceYushi = 0;                    //购买home需要的玉石
private int priceMoney = 0;                    //购买home需要的money
private string flatPath = "";                  //home所在的flat的路径    homeId = flatPath + num(该home在这个flat中的序号) 
private string areaName = "";                  //home所在的area名
private string slotName = "";                  //home所在的slot名
private string flatName = "";                  //home所在的flat名
private string roomName = "";                  //房间名( ore plant animal main door ...)
private string roomNameCn = "";                //房间中文名（矿山 花园 牧场 前厅 门厅 ...）
private mapping(string:mapping(int:object)) lifes = ([]); //家园中养殖的所有生物
private string door = "";                      //门信息
private string dog = "";                       //看门狗信息
private array(string) userIn = ({});           //home中的玩家
private array(string) functionRoom = ({});     //home中的功能房间
private string flyTarget = "";                 //"飞天小屋"的传送目的地
//added by caijie 08/10/27
private int level_limit = 0;                   //功能房间的家园等级限制
private int used_times = 0;                    //功能房间的使用次数
private string buff_type = "";		       //功能类型
private string buff_kind = "";		       //功能效果类型
private int buff_value = 0;		       //功能效果值
private int effect_time;		       //功能效果持续时间
private int wait_time;			       //实现效果需要花费的时间
private string oprate_desc;		       //功能房间的操作描述
//added end
private int homeLv;                            //家园等级


private string initer=((set_room_type("home")),""); 

//设置功能房间的操作描述
void set_oprate_desc(string s){
	oprate_desc = s;
}
string query_oprate_desc(){
	return oprate_desc;
}
//设置功能房间的家园等级限制
void set_level_limit(int lv){
	 level_limit = lv;
}
int query_level_limit(){
	 return level_limit;
}

//设置功能房间的可使用次数
void set_used_times(int times){
	used_times = times;
}
int query_used_times(){
	return used_times;
}

//设置功能房间的功能类型
void set_buff_type(string s){
	buff_type = s;
}
string query_buff_type(){
	return buff_type;
}

//设置效果类型
void set_buff_kind(string s){
	buff_kind = s;
}
string query_buff_kind(){
	return buff_kind;
}

//设置效果值
void set_buff_value(int vl){
	buff_value = vl;
}
int query_buff_value(){
	return buff_value;
}

//设置效果持续时间
void set_effect_time(int t){
	effect_time = t;
}
int query_effect_time(){
	return effect_time;
}

//练功、吃饭等操作所需要花费的时间
void set_wait_time(int t){
	wait_time = t;
}
int query_wait_time(){
	return wait_time;
}
//add end caijie

void set_homeId(string s){
	 homeId = s;
}
string query_homeId(){
	return homeId;
} 

void set_masterId(string s){
	 masterId = s;
}
string query_masterId(){
	return masterId;
} 

void set_masterName(string s){
	masterName = s;
}
string query_masterName(){
	return masterName;
} 
void set_customName(string s){
	customName = s;
}
string query_customName(){
	return customName;
} 
void set_customDesc(string s){
	 customDesc = s;
}
string query_customDesc(){
	return customDesc;
} 

void set_allowedUser(array(string)s){
	allowedUser = s;
}
array(string) query_allowedUser(){
	return allowedUser;
} 
void set_priceYushi(int s){
	priceYushi = s;
}
int query_priceYushi(){
	return priceYushi;
} 
void set_priceMoney(int s){
	priceMoney = s;
}
int query_priceMoney(){
	return priceMoney;
} 

void set_flatPath(string s){
	 flatPath = s;
}
string query_flatPath(){
	return flatPath;
} 
void set_areaName(string s){
	 areaName = s;
}
string query_areaName(){
	return areaName;
} 
void set_slotName(string s){
	 slotName = s;
}
string query_slotName(){
	return slotName;
} 
void set_flatName(string s){
	 flatName = s;
}
string query_flatName(){
	return flatName;
} 
void set_roomName(string s){
	 roomName = s;
}
string query_roomName(){
	return roomName;
} 
void set_roomNameCn(string s){
	 roomNameCn = s;
}
string query_roomNameCn(){
	return roomNameCn;
} 
void set_lifes(mapping s){
	 lifes = s;
}
mapping query_lifes(){
	return lifes;
} 
void set_door(string s){
	 door = s;
}
string query_door(){
	return door;
} 
void set_dog(string s){
	 dog = s;
}
string query_dog(){
	return dog;
} 
void set_userIn(array(string)s){
	userIn = s;
}
array(string) query_userIn(){
	return userIn;
} 
void set_functionRoom(array(string)s){
	functionRoom = s;
}
array(string) query_functionRoom(){
	return functionRoom;
} 
void set_flyTarget(string s){
	 flyTarget = s;
}
string query_flyTarget(){
	return flyTarget;
} 
void set_homeLv(int s){
	 homeLv = s;
}
int query_homeLv(){
	return homeLv;
} 
