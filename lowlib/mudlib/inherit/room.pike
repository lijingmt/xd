#include <globals.h>
#include <mudlib/include/mudlib.h>
#include <gamelib/include/gamelib.h>
#define LEAVE_TIME 20 //离开保留时间
inherit LOW_BASE;
inherit LOW_F_DBASE;
inherit MUD_F_INIT;
inherit MUD_F_ITEMS;

mapping exits=([]);//(["west":ROOT+"/wapmud2/d/someroom"])
mapping closed_exits=([]);//([string DIRECTORY:int|string|program|object KEY])
mapping opened_exits=([]);//([string DIRECTORY:int|string|program|object KEY])
mapping hidden_exits=([]);//([string DIRECTORY:string|program|object KEY_OBJECT])
mapping switch_exits=([]);//([string DIRECTORY:({({string VAR,int VAL_MIN,int VAL_MAX,string DEST})})])
mapping guarded_exits=([]);//([string DIRECTORY:string|program|object GUARDER])
int reset_interval=30;
private mapping leaveMSG=([]);//纪录任务信息([string userid:array({玩家中文名,离开方向,时间,(<看过的玩家id>)})])
private mapping remainMSG=([]);//该房间的剩余信息([int 时间:string 信息,<看过的玩家id>])
private mapping arriveMSG=([]);//该房间的来人信息([int 时间:string 信息,<看过的玩家id>])
string guard_msg;
string get_guard_msg(object guarder,string dir){
	if(guard_msg)
		return guard_msg;
	else
		return guarder->name_cn+"挡住了你的去路。";
}
int is_room(){
	return 1;
}
//override item类的函数，用来动态调整npc的等级
int dongtai_npc_start_level=50;


void add_items(array(string|program) _items){
	object me= this_player();
	object env=environment(me);
	foreach(_items,string|program s){
		int adjust=0;//刷新npc级别调整，如果是地狱，则增加3级		
		//werror("----add_items -> player=["+me->name+"]----\n");
		if(me->gamelevel=="putong") adjust=0;
		else if(me->gamelevel=="emeng") adjust=5;
		else if(me->gamelevel=="diyu") adjust=10;
		object t_ob = 0;
		object ob=0;
		mixed err=catch{
			//等级大于50级以上才开启动态NPC
			int fb_status = FBD->query_fb_memebers(me->fb_id,me->query_name());//0 为非副本，1为副本
			//int fb_status = search(fb_arr,this_object()->name);
			//werror("======fb_status "+fb_status +"\n");
			if(env->is_peaceful()!=1&&me->query_level()>=dongtai_npc_start_level && fb_status == 0)
				t_ob=MUD_ROOMD->get_npc_level(s-ROOT,me->query_level()+adjust);//生成文件名不变的npc对象，再赋予对应等级/强度
		};
		if(!err&&t_ob) ob=t_ob;
		else ob=new(s);
		/////////////////////////////////////
		//object ob=new(s);
		//动态调整npc等级
		//ob->_npcLevel=this_player()->query_level();
		//ob->setup_npc();
		//动态调整npc等级
		//werror("===========add items npc:"+file_name(ob)+"\n");
		//({内存唯一副本，内存中的拷贝，该物件刷新时间，当前时间})
		items+=({({((program)s),ob,ob->_flushtime,time()})});
		ob->move(this_object());
	}
}
/*
此方法重构override了底层的reset times，每次用户进入房间，都会调用这个方法检查房间的npc

房间触发器try_reset，玩家进入房间时触发，检测距离上次重置差值30秒后，触发reset_items方法，再检测是否是第一个进入的玩家，再调用重置npc等级为玩家等级
所以，其实可以把差值30秒去掉，只要玩家进入，就触发该reset_items方法
先用30秒做测试
 */

void reset_items()
{
	::reset_items();//调用底层的reset方法
	object me= this_player();
	//werror("----reset_items -> player=["+me->name+"]----\n");
	//等级大于50级以上才开启动态NPC
	int fb_status = FBD->query_fb_memebers(me->fb_id,me->query_name());
	//werror("======fb_status "+fb_status +"\n");
	if(me->query_level()>=dongtai_npc_start_level && fb_status == 0){
		MUD_ROOMD->refresh_room_npc_to_currentlevel(me);//动态刷新当前要去的目标房间npclevel 为玩家的等级
	}
	
	////werror("===reset to refresh room npc to current me level\n");
}
private int last_reset;
private void try_reset(){
	//此处设置了30秒钟的间隔，来刷npc的刷新间隔时间，也就是说，只要有玩家进来比头一个晚30秒，就可以刷新ncp
	if(time()-last_reset>reset_interval){
		last_reset=time();
		reset_items();
		if(this_object()->is("store")){
			this_object()->reset_boss();
		}
		closed_exits+=opened_exits;
		opened_exits=([]);
	}
}
/*
 * 增加一个离开纪录
 * object user 离开的人
 */
void addLeaveInfo(object user){
	leaveMSG+=([user->name:({user->name_cn,user->leave_direction,time(),(<>)})]);
}
/*
* 整理房间离开信息，删除过期信息
*/
void trimLeaveInfo(){
	array names = indices(leaveMSG);
	foreach(names,string name){
		array t = leaveMSG[name];
		if(t[2]<time()-LEAVE_TIME){
			m_delete(leaveMSG,name);
		}
	}
	while(sizeof(leaveMSG)>3){//最多显示3条信息
		array names = indices(leaveMSG);
		string deleteName="";
		int time = 0;
		foreach(names,string name){
			array t = leaveMSG[name];
			if(t[2]>time){
				deleteName = name;
			}
		}
		m_delete(leaveMSG,deleteName);
	}
}
//删除该用户的离开信息
void deleteLeaveInfo(string name){
		m_delete(leaveMSG,name);
}
//显示最近的离开信息
string query_leave(string username){
	trimLeaveInfo();
	string returnString="";
	array names = indices(leaveMSG);
	foreach(names,string name){
		array t = leaveMSG[name];
		if(t[3][username]) continue;
		leaveMSG[name][3]+=(<username>);
		returnString+=t[0]+"向"+(["east":"东","west":"西","north":"北","south":"南"])[t[1]]+"离开。\n";
	}
	return returnString;
}
/*
 * 增加一条信息
*/
void addRemainMSG(string msg,multiset except){
		remainMSG+=([gethrtime():({msg,except})]);
}
/**
* 得到剩余信息的大小
*/
private int getRemainMSGSize(){
	array names = indices(remainMSG);
	int size=0;
	foreach(names,int name){
		size+=sizeof(remainMSG[name][0]);
	}
	return size;
}
/*
 * 整理房间离开信息，删除过期信息
*/
void trimRemainMSG(){
	array names = indices(remainMSG);
		foreach(names,int name){
			if(name/1000000<time()-LEAVE_TIME){
				m_delete(remainMSG,name);
			}
		}
	while(sizeof(remainMSG)>2){//最多2条信息
		array names = indices(remainMSG);
		int deleteName=0;
		int time = 0;
		foreach(names,int name){
			if(name>time){
				deleteName = name;
			}
		}
		m_delete(remainMSG,deleteName);
	}
}
//显示最新的遗留信息
string query_remain_msg(string username){
	trimRemainMSG();
	string returnMSG="";
	array names = indices(remainMSG);
	foreach(names,int name){
		if(remainMSG[name][1][username]) continue;
		remainMSG[name][1]+=(<username>);
		returnMSG+=remainMSG[name][0]+"\n";
	}
	return returnMSG;
}
/*
* 增加一条来人信息
*/
void addArriveMSG(object user){
		arriveMSG+=([user->name:({user->name_cn,time(),(<user->name>)})]);
}
/*
* 整理房间离开信息，删除过期信息
*/
void trimArriveMSG(){
	array names = indices(arriveMSG);
		foreach(names,int name){
			if(arriveMSG[name][1]<time()-10){
				m_delete(arriveMSG,name);
			}
		}
		while(sizeof(arriveMSG)>3){//最多显示3条信息
		array names = indices(arriveMSG);
		int deleteName=0;
		int time = 0;
		foreach(names,int name){
			if(arriveMSG[name][1]>time){
				deleteName = name;
			}
		}
		m_delete(arriveMSG,deleteName);
	}
}
//显示最新的遗留信息
string query_arrive_msg(string username){
	trimArriveMSG();
	string returnMSG="";
	array names = indices(arriveMSG);
	foreach(names,int name){
		if(arriveMSG[name][2][username]) continue;
		arriveMSG[name][2]+=(<username>);
		returnMSG+=arriveMSG[name][0]+"来到了这里。\n";
	}
	return returnMSG;
}
//删除该用户的离开信息
void deleteArriveInfo(string name){
		m_delete(arriveMSG,name);
}
private string initer=(add_init(try_reset),"");
