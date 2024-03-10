#include <globals.h>
#include <command.h>
#include <wapmud2/include/wapmud2.h>
inherit MUD_ITEM;
inherit WAP_F_VIEW_LINKS;
inherit WAP_F_VIEW_VALUE;
inherit WAP_F_VIEW_PICTURE;
static mapping(int:string) rareLevel = ([
	0:"【普通】",
	1:"【一般】",
	2:"【稀有】",
	3:"【罕见】",
]);

//生物 通用继承的基本属性
private string life_type;//生物类别： 动物 animal  植物 plant  矿物 ore 其它 other(矿物会随着时间推移不断汇聚，可以认为具有类似于"生命生长"的特性)
string query_life_type(){return life_type;}
void set_life_type(string s){ life_type= s;}

private int life_level=0;//生物自身等级
int query_life_level(){return life_level;}
void set_life_level(int a){ life_level= a;}

private int homeLevel_limit=0;//生物培育 需要的房间等级
int query_homeLevel_limit(){return homeLevel_limit;}
void set_homeLevel_limit(int a){ homeLevel_limit= a;}

private int life_rareLevel=0;//生物稀有程度
int query_life_rareLevel(){return life_rareLevel;}
void set_life_rareLevel(int a){ life_rareLevel= a;}

string query_rare_level(){
	return rareLevel[life_rareLevel]; 
}

//生物的初始生命
private int init_life=0;
void set_init_life(int a){init_life=a;}
int query_init_life(){return init_life;}
//生物的终止生命
private int final_life=0;
void set_final_life(int a){final_life=a;}
int query_final_life(){return final_life;}
//生物的当前生命
private int current_life=0;
void set_current_life(int a){current_life=a;}
int query_current_life(){return current_life;}
//生长速度 
private int grow_speed = 0;
void set_grow_speed(int a){grow_speed=a;}
int query_grow_speed(){return grow_speed;}
//成熟时间
private int dead_time = 0;
void set_dead_time(int a){dead_time=a;}
int query_dead_time(){return dead_time;}

private string initer=(this_object()->add_heart_beat(heart_beat_action,600),"");

private void heart_beat_action(){
	object life = this_object();
	if(life->current_life < 0) life->current_life=0;
	if(life->current_life < life->final_life)
	{
		life->current_life += life->grow_speed;
		if(life->current_life>life->final_life)
		{
			life->current_life = life->final_life;
		}
	}
}
