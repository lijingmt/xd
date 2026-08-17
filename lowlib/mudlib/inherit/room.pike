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
int dongtai_npc_start_level=70;
private int last_autofight_pressure_check;
private int autofight_training_capacity;
private int autofight_training_slots;
private int autofight_initial_population;
private int autofight_pressure_refresh_seconds;
private int autofight_pressure_budget;
private int autofight_pressure_check_seconds=15;

private int is_autofight_normal_spawn(object ob)
{
	string npc_type;
	if(!ob || !ob->is("npc"))
		return 0;
	if(ob->_boss || ob->_tasknpc || ob->_meritocrat || ob->_rare)
		return 0;
	if(functionp(ob->query_summon_type))
		return 0;
	npc_type=ob->query_npc_type();
	if(npc_type=="city_keeper" || npc_type=="city_guarder" ||
	   npc_type=="city_lord" || npc_type=="illusion_sidequest")
		return 0;
	return 1;
}


void add_items(array(string|program) _items){
	object me= this_player();
	object env=me ? environment(me) : 0;
	foreach(_items,string|program s){
		int adjust=0;//刷新npc级别调整，如果是地狱，则增加3级
		//werror("----add_items -> player=["+(me?me->name:"none")+"]----\n");
		if(me){
			if(me->gamelevel=="putong") adjust=0;
			else if(me->gamelevel=="emeng") adjust=5;
			else if(me->gamelevel=="diyu") adjust=10;
		}
		object|zero t_ob = 0;
		object|zero ob=0;
		mixed err=catch{
			//达到70级后才开启动态NPC
			int fb_status = me ? FBD->query_fb_memebers(me->fb_id,me->query_name()) : 1;//0 为非副本，1为副本
			//int fb_status = search(fb_arr,this_object()->name);
			//werror("======fb_status "+fb_status +"\n");
			if(me && env && env->is_peaceful()!=1&&me->query_level()>=dongtai_npc_start_level && fb_status == 0)
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
		items+=({({((program)s),ob,ob->_flushtime,time(),
			is_autofight_normal_spawn(ob)})});
		ob->move(this_object());
	}
}

// 公共中立猎场可以显式声明挂机容量与普通怪槽位。默认房间不调用
// 此接口，因此原有地图的刷怪数量、刷新节奏和掉落经济完全不变。
void configure_autofight_training_population(string npc_path,int slots,
	int capacity,int refresh_seconds,int budget,int check_seconds)
{
	program npc_program;
	int npc_flush_seconds;
	int initial_population;
	if(!npc_path || npc_path=="" || slots<1 || capacity<1)
		return;
	if(slots>32)
		slots=32;
	if(capacity>slots)
		capacity=slots;
	if(refresh_seconds<3)
		refresh_seconds=3;
	if(budget<1)
		budget=1;
	if(budget>slots)
		budget=slots;
	if(check_seconds<1)
		check_seconds=1;
	autofight_training_capacity=capacity;
	autofight_training_slots=slots;
	autofight_pressure_refresh_seconds=refresh_seconds;
	autofight_pressure_budget=budget;
	autofight_pressure_check_seconds=check_seconds;
	initial_population=min(4,slots);
	autofight_initial_population=initial_population;
	for(int i=0;i<initial_population;i++)
		add_items(({npc_path}));
	if(sizeof(items)<1)
		return;
	npc_program=items[sizeof(items)-1][0];
	npc_flush_seconds=max(300,(int)items[sizeof(items)-1][2]);
	// 潜在槽位不在房间加载时创建对象；挂机压力到来后按人数补齐。
	// 五分钟的普通重置兜底仍保留，避免接口异常造成永久空槽。
	for(int i=initial_population;i<slots;i++)
		items+=({({npc_program,0,npc_flush_seconds,
			time()-refresh_seconds,1})});
}

int query_autofight_training_capacity()
{
	return autofight_training_capacity;
}

// 只对自动挂机指定练级房开放：人数越多，原有普通怪槽位越快补齐。
// 不增加房间原始槽位总量，也不加速 Boss、精英、任务或召唤单位。
mapping query_autofight_pressure_policy(int active_players,
	void|int overflow_room)
{
	int enabled=1;
	int refresh_seconds=90;
	int budget=1;
	if(autofight_training_capacity>0){
		int target_population=active_players+2;
		if(target_population<autofight_initial_population)
			target_population=autofight_initial_population;
		if(target_population>autofight_training_slots)
			target_population=autofight_training_slots;
		return ([
			"enabled":active_players>0,
			"refresh_seconds":autofight_pressure_refresh_seconds,
			"budget":autofight_pressure_budget,
			"target_population":target_population,
		]);
	}
	if(active_players<2 && !overflow_room)
		enabled=0;
	if(active_players>=3){
		refresh_seconds=75;
		budget=2;
	}
	if(active_players>=4){
		refresh_seconds=60;
		budget=3;
	}
	return ([
		"enabled":enabled,
		"refresh_seconds":refresh_seconds,
		"budget":budget,
	]);
}

int query_autofight_pressure_check_ready()
{
	return time()-last_autofight_pressure_check>=
		autofight_pressure_check_seconds;
}

int refresh_autofight_normal_npcs(object me,int active_players,
	void|int overflow_room)
{
	mapping policy;
	int refresh_seconds;
	int budget;
	int target_population;
	int alive_normal;
	int spawned=0;
	if(!me || this_object()->is("peaceful"))
		return 0;
	policy=query_autofight_pressure_policy(active_players,overflow_room);
	if(!(int)policy["enabled"])
		return 0;
	if(!query_autofight_pressure_check_ready())
		return 0;
	last_autofight_pressure_check=time();
	refresh_seconds=(int)policy["refresh_seconds"];
	budget=(int)policy["budget"];
	target_population=(int)policy["target_population"];
	if(target_population>0){
		for(int i=0;i<sizeof(items);i++){
			array one=items[i];
			if(one && sizeof(one)>=5 && (int)one[4] && one[1])
				alive_normal++;
		}
		if(alive_normal>=target_population)
			return 0;
		budget=min(budget,target_population-alive_normal);
	}
	for(int i=0;i<sizeof(items) && spawned<budget;i++){
		array one=items[i];
		object ob;
		mixed err;
		if(!one || sizeof(one)<5 || one[1] || !(int)one[4])
			continue;
		if((int)one[2]<=refresh_seconds || (int)one[2]>5*60)
			continue;
		if(time()-(int)one[3]<refresh_seconds)
			continue;
		err=catch{
			ob=new(one[0]);
			if(!is_autofight_normal_spawn(ob)){
				if(ob)
					destruct(ob);
				ob=0;
			}
			if(ob && me->query_level()>=dongtai_npc_start_level &&
			   me->query_level()<ENDGAME_MAP_MIN_LEVEL){
				ob->_npcLevel=me->query_level();
				ob->setup_npc_dongtai(me);
			}
			if(ob && ob->move(this_object())!=1){
				destruct(ob);
				ob=0;
			}
		};
		if(err || !ob){
			if(ob)
				destruct(ob);
			continue;
		}
		one[1]=ob;
		one[3]=time();
		spawned++;
	}
	return spawned;
}

mapping query_autofight_spawn_status()
{
	int normal_slots=0;
	int alive_normal=0;
	for(int i=0;i<sizeof(items);i++){
		array one=items[i];
		if(!one || sizeof(one)<5 || !(int)one[4])
			continue;
		normal_slots++;
		if(one[1])
			alive_normal++;
	}
	return ([
		"normal_slots":normal_slots,
		"alive_normal":alive_normal,
		"last_pressure_check":last_autofight_pressure_check,
		"training_capacity":autofight_training_capacity,
		"training_slots":autofight_training_slots,
		"initial_population":autofight_initial_population,
		"pressure_refresh_seconds":autofight_pressure_refresh_seconds,
		"pressure_budget":autofight_pressure_budget,
		"pressure_check_seconds":autofight_pressure_check_seconds,
	]);
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
	if(!me) return;
	//werror("----reset_items -> player=["+me->name+"]----\n");
	//达到70级后才开启动态NPC
	int fb_status = FBD->query_fb_memebers(me->fb_id,me->query_name());
	//werror("======fb_status "+fb_status +"\n");
	if(me->query_level()>=dongtai_npc_start_level && fb_status == 0){
		MUD_ROOMD->refresh_room_npc_to_currentlevel(me);//动态刷新当前要去的目标房间npclevel 为玩家的等级
	}
	else if(me->query_level()<dongtai_npc_start_level){
		MUD_ROOMD->restore_low_level_room_npcs(me);
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
		if(!LOGICALZONED->can_user_interact(username,name))
			continue;
		if(t[3][username]) continue;
		leaveMSG[name][3]+=(<username>);
		returnString+=t[0]+"向"+(["east":"东","west":"西","north":"北","south":"南"])[t[1]]+"离开。\n";
	}
	return returnString;
}
/*
 * 增加一条信息
*/
void addRemainMSG(string msg,multiset except,void|string source_id){
		remainMSG+=([gethrtime():({msg,except,source_id || ""})]);
}
/*
 * 整理房间离开信息，删除过期信息
*/
void trimRemainMSG(){
	array names = indices(remainMSG);
		foreach(names,string name){
			if(name/1000000<time()-LEAVE_TIME){
				m_delete(remainMSG,name);
			}
		}
	while(sizeof(remainMSG)>2){//最多2条信息
		array names = indices(remainMSG);
		string deleteName="";
		int time = 0;
		foreach(names,string name){
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
		if(sizeof(remainMSG[name])>2 && remainMSG[name][2]!="" &&
		   !LOGICALZONED->can_user_interact(username,remainMSG[name][2]))
			continue;
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
	foreach(names,string name){
		if(!LOGICALZONED->can_user_interact(username,name))
			continue;
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
