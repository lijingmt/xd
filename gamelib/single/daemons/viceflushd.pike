//掉落制皮，织布材料的怪刷新守护程序，主要负责建立和维护游戏中这种特殊怪的信息表，包括怪物的刷新个数，刷新时间，怪物出现的地图等级，并且还要负责怪物在游戏世界的刷新
//
//核心数据结构:
//1.怪物信息表:
// class vicenpc; 打算采用类来记录怪物的信息 
//
// 下面这个mapping作为备用方案
// mapping(string:array(mixed)) vicenpc_m = 
//   (["tongvicenpc":({"怪物名",刷新数量,刷新时间(以分钟为单位),地图最低等级，地图最高等级，需要熟练度})
//                    [0]     [1]           [2]                 [3]            [4]          [5]
//       ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/vicenpc.csv中的内容来建立的。
//
//由liaocheng于07/10/22开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define VICENPC_CSV ROOT "/gamelib/data/material/vicenpc.csv" //怪物物列表
#define VICENPC_PATH ROOT "/gamelib/clone/npc/vice_npc/" //所有这类物品文件都放在此目录下
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
//#define FLUSH_TIME 900
//怪物的刷新时间比较多样性，这也是这个守护模块的难点
//#define FLUSH_TIME 120 //测试用，循环执行flush_vicenpc()的时间间隔
#define FLUSH_TIME 900 //正式用，15分钟为一单位
#define MAX_TIME 360  //刷新时间最长的怪物的刷新时间

class vicenpc
{
	//string name; //[0]文件名
	string name_cn;//[1]中文名
	int nums;//[2]刷新总数量
	int flush_time;//[3]刷新时间
	int mLevel_min;//[4]地图等级下限
	int mLevel_max;//[5]地图等级上限
}

private mapping(string:vicenpc) vicenpcMap = ([]); //物品信息总表
private mapping(string:int) vicenpcNeed = ([]); //记录目前需要刷的怪物数量
private mapping(int:array(string)) vicenpc_flush_time = ([]);//以刷新时间为索引的映射表,时间为15分钟的倍数
//([15:({vicenpc1,vicenpc2}),
//  30:({vicenpc3,vicenpc5}), 
// ...
//  ])
private int flush_count = 0;
private int worker_refresh_started;
private int worker_assignment_generation;
private mapping(string:int) worker_initialized = ([]);

private int worker_mode()
{
	return MAP_WORKERD->query_node_role()=="worker";
}

private int gateway_mode()
{
	return MAP_WORKERD->query_node_role()=="gateway";
}

private int stable_room_slot(string name,int slot,int room_count)
{
	object hash;
	string digest;
	int value;
	if(room_count<1)
		return -1;
	hash = Crypto.SHA256();
	hash->update("vice_npc|"+name+"|"+(string)slot);
	digest = String.string2hex(hash->digest());
	if(sizeof(digest)>=7)
		sscanf(digest[0..6],"%x",value);
	return value%room_count;
}

private int count_room_vicenpc(object room_ob,string name)
{
	int count;
	string source_path = VICENPC_PATH+name;
	if(!room_ob)
		return 0;
	foreach(all_inventory(room_ob),object one){
		string path = one ? file_name(one) : "";
		if(path==source_path || has_prefix(path,source_path+"#"))
			count++;
	}
	return count;
}

private int spawn_worker_vicenpc(string name,string room)
{
	object room_ob;
	object npc;
	mixed err;
	if(!vicenpcMap[name] || room=="" || search(room,"..")!=-1 ||
	   !MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
		return 0;
	err = catch { room_ob=(object)(ROOM_PATH+room); };
	if(err || !room_ob)
		return 0;
	err = catch{
		npc = clone(VICENPC_PATH+name);
		if(npc)
			npc->move(room_ob);
	};
	if(err || !npc || environment(npc)!=room_ob){
		if(npc)
			destruct(npc);
		return 0;
	}
	return 1;
}

private void reconcile_worker_vicenpc(string name)
{
	vicenpc one = vicenpcMap[name];
	array(string) rooms;
	mapping(string:int) desired = ([]);
	int missing;
	int desired_total;
	int existing_total;
	int spawned;
	if(!one){
		vicenpcNeed[name] = 0;
		return;
	}
	rooms = ROOMLEVELD->query_rooms(one->mLevel_min,one->mLevel_max);
	if(!sizeof(rooms)){
		vicenpcNeed[name] = 0;
		werror("[VICEFLUSHD][WORKER] no eligible rooms for %s\n",name);
		return;
	}
	for(int slot=0;slot<one->nums;slot++){
		int index = stable_room_slot(name,slot,sizeof(rooms));
		string room = index>=0 ? rooms[index] : "";
		if(room!="" &&
		   MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
			desired[room] = (int)desired[room]+1;
	}
	foreach(indices(desired),string room){
		object room_ob;
		mixed err = catch { room_ob=(object)(ROOM_PATH+room); };
		int existing = !err && room_ob ? count_room_vicenpc(room_ob,name) : 0;
		int need = max(0,(int)desired[room]-existing);
		desired_total += (int)desired[room];
		existing_total += existing;
		for(int index=0;index<need;index++)
			if(spawn_worker_vicenpc(name,room))
				spawned++;
			else
				missing++;
	}
	vicenpcNeed[name] = missing;
	worker_initialized[name] = 1;
	if(spawned || missing)
		werror("[VICEFLUSHD][WORKER] generation=%d npc=%s desired=%d existing=%d spawned=%d missing=%d\n",
			MAP_WORKERD->query_local_assignment_generation(),name,
			desired_total,existing_total,spawned,missing);
}

private int refresh_worker_generation()
{
	int generation = MAP_WORKERD->query_local_assignment_generation();
	if(generation<1 || generation==worker_assignment_generation)
		return 0;
	worker_assignment_generation = generation;
	worker_initialized = ([]);
	return 1;
}

private void reconcile_all_worker_vicenpc()
{
	foreach(indices(vicenpcMap),string name)
		reconcile_worker_vicenpc(name);
	werror("[VICEFLUSHD][WORKER] generation=%d reconciled_npcs=%d\n",
		MAP_WORKERD->query_local_assignment_generation(),sizeof(vicenpcMap));
}

private void fill_worker_vicenpc_need(string name)
{
	int need = (int)vicenpcNeed[name];
	array(string) rooms;
	mapping(string:int) desired = ([]);
	if(need<1)
		return;
	rooms = ROOMLEVELD->query_rooms(vicenpcMap[name]->mLevel_min,
		vicenpcMap[name]->mLevel_max);
	if(!sizeof(rooms))
		return;
	for(int slot=0;slot<vicenpcMap[name]->nums;slot++){
		int index = stable_room_slot(name,slot,sizeof(rooms));
		string room = index>=0 ? rooms[index] : "";
		if(room!="" &&
		   MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
			desired[room] = (int)desired[room]+1;
	}
	foreach(indices(desired),string room){
		object room_ob;
		mixed err = catch { room_ob=(object)(ROOM_PATH+room); };
		int existing = !err && room_ob ? count_room_vicenpc(room_ob,name) : 0;
		int room_missing = max(0,(int)desired[room]-existing);
		for(int index=0;index<room_missing && vicenpcNeed[name]>0;index++)
			if(spawn_worker_vicenpc(name,room))
				vicenpcNeed[name]--;
	}
}

void start_worker_refresh()
{
	if(!worker_mode() || worker_refresh_started)
		return;
	if(!MAP_WORKERD->local_affinity_assignments_ready()){
		call_out(start_worker_refresh,2);
		return;
	}
	worker_refresh_started = 1;
	if(refresh_worker_generation())
		reconcile_all_worker_vicenpc();
	call_out(flush_vicenpc,FLUSH_TIME);
}

protected void create()
{
	load_csv();
	if(worker_mode())
		call_out(start_worker_refresh,2);
	else if(!gateway_mode())
		flush_vicenpc();
//	call_out(flush_vicenpc,FLUSH_TIME);
}

void load_csv()
{
	vicenpcMap = ([]);
	vicenpcNeed = ([]);
	vicenpc_flush_time = ([]);
	worker_initialized = ([]);
	string vicenpcData = Stdio.read_file(VICENPC_CSV);
	array(string) lines = vicenpcData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			vicenpc tmpVicenpc = vicenpc();
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 6){
				tmpVicenpc->name_cn = columns[1];
				tmpVicenpc->nums = (int)columns[2];
				tmpVicenpc->flush_time = (int)columns[3];
				//写入到刷新时间表中
				if(vicenpc_flush_time[tmpVicenpc->flush_time] == 0)
					vicenpc_flush_time[tmpVicenpc->flush_time] = ({columns[0]});
				else
					vicenpc_flush_time[tmpVicenpc->flush_time] += ({columns[0]});
				tmpVicenpc->mLevel_min = (int)columns[4];
				tmpVicenpc->mLevel_max = (int)columns[5];
				if(vicenpcMap[columns[0]] == 0)
					vicenpcMap[columns[0]] = tmpVicenpc;
				vicenpcNeed[columns[0]] = (int)columns[2];
			}
			else
				werror("------size of columns wrong in load_csv() of viceflushd.pike------\n");
		}
	}
	else 
		werror("------read vicenpc.csv wrong in gamelib/single/daemon/viceflushd.pike------\n");
}


//刷新怪物的接口
void flush_vicenpc()
{
	flush_count += 15; //刷新时间是15的倍数
	string now=ctime(time());
	if(worker_mode()){
		if(refresh_worker_generation())
			reconcile_all_worker_vicenpc();
		foreach(indices(vicenpc_flush_time),int worker_time)
			if(flush_count%worker_time==0)
				foreach(vicenpc_flush_time[worker_time],string name)
					if(!worker_initialized[name])
						reconcile_worker_vicenpc(name);
					else
						fill_worker_vicenpc_need(name);
		if(flush_count>=MAX_TIME)
			flush_count = 0;
		call_out(flush_vicenpc,FLUSH_TIME);
		return;
	}
	if(gateway_mode())
		return;
	foreach(indices(vicenpc_flush_time),int time){
		if(flush_count%time == 0){
		//到刷新时间了
			array(string) tmp_flush = vicenpc_flush_time[time];
			if(tmp_flush && sizeof(tmp_flush)){
				int size = sizeof(tmp_flush);
				for(int i=0;i<size;i++){
					string vicenpcname = tmp_flush[i];
					if(vicenpcNeed[vicenpcname]){
						int need_num = vicenpcNeed[vicenpcname];
						Stdio.append_file(ROOT+"/log/flush_vicenpc.log",now[0..sizeof(now)-2]+":flush "+vicenpcname+" "+need_num+"\n");
						vicenpc tempVicenpc = vicenpcMap[vicenpcname];
						int roomlev_h = tempVicenpc->mLevel_max;
						int roomlev_l = tempVicenpc->mLevel_min;
						for(int j=0;j<need_num;j++){
							int roomlev = roomlev_l+random(roomlev_h-roomlev_l+1);
							string room = ROOMLEVELD->query_room(roomlev);
							if(room != ""){
								object vicenpc_ob = clone(VICENPC_PATH+vicenpcname);
								if(vicenpc_ob){
									Stdio.append_file(ROOT+"/log/flush_vicenpc.log",now[0..sizeof(now)-2]+":"+tempVicenpc->name_cn+"("+room+")\n");
									vicenpc_ob->move(ROOM_PATH+room);
									vicenpcNeed[vicenpcname]--;
								}
								else
									werror("------can't flush vicenpc : "+vicenpcname+"------\n");
							}
							//else
							//	werror("------get room wrong with roomlevel = "+roomlev+"------\n");
						}
					}
				}
			}
			Stdio.append_file(ROOT+"/log/flush_vicenpc.log","----------------------------\n");
		}
	}
	if(flush_count >= MAX_TIME)
		flush_count = 0;
	call_out(flush_vicenpc,FLUSH_TIME);
}

//怪物被挖了后要设置待刷新怪物的数量
void set_flush_num(string name)
{
	if(gateway_mode() || !vicenpcMap[name])
		return;
	if(!vicenpcNeed[name])
		vicenpcNeed[name] = 1;
	else
		vicenpcNeed[name]++;
}

mapping(string:mixed) query_worker_contract_for_test(string name)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !vicenpcMap[name])
		return (["ok":0]);
	return (["ok":1,"name_cn":vicenpcMap[name]->name_cn,
		"nums":vicenpcMap[name]->nums,
		"min_level":vicenpcMap[name]->mLevel_min,
		"max_level":vicenpcMap[name]->mLevel_max,
		"stable_slot":stable_room_slot(name,0,97)]);
}
