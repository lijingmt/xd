//矿物的守护程序，主要负责建立和维护游戏中矿物的信息表，包括矿物的刷新个数，刷新时间，矿物出现的地图等级，矿物的出产物等，并且还要负责矿物在游戏世界的刷新
//
//核心数据结构:
//1.矿物信息表:
// class kuang; 打算采用类来记录矿的信息 
//
// 下面这个mapping作为备用方案
// mapping(string:array(mixed)) kuang_m = 
//   (["tongkuang":({"铜矿",刷新数量,刷新时间(以分钟为单位),地图最低等级，地图最高等级，需要熟练度})
//                    [0]     [1]           [2]                 [3]            [4]          [5]
//       ...
//   ])
//2.矿物产出物表，该表记录玩家挖取矿物时，可能获得的物品:
// mapping(string:mapping(string:int)) get_m = 
//   (["tongkuang":(["tongkuangshi":100,"xuanhuangshi":10,]),
//                     出产物名  :  概率
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/kuangwu.csv中的内容来建立的。
//
//由liaocheng于07/5/23开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define KUANG_CSV ROOT "/gamelib/data/material/kuangwu.csv" //矿物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
//#define FLUSH_TIME 900
#define FLUSH_TIME 43200
//#define QUICK_TIME 900
#define QUICK_TIME 1020

class kuang
{
	//string name; //[0]文件名
	string name_cn;//[1]中文名
	int nums;//[2]刷新总数量
	int flush_time;//[3]刷新时间
	int mLevel_min;//[4]地图等级下限
	int mLevel_max;//[5]地图等级上限
	int skill_level;//[6]技能熟练度限制
	mapping(string:int) get_m = ([]); //[7]出产物品映射表
}

private mapping(string:kuang) kuangMap = ([]); //物品信息总表
private mapping(string:int) kuangNeed = ([]); //记录目前需要刷的矿数量
private mapping(string:array) quick_flush = ([]); //快速刷矿,在固定地点刷出矿,在玩家挖矿时别写入，
//([kuang_name:({房间1,房间2,房间3....})])
private int worker_refresh_started;
private int worker_assignment_generation;

private int worker_mode()
{
	return MAP_WORKERD->query_node_role()=="worker";
}

private int stable_room_slot(string name,int slot,int room_count)
{
	object hash;
	string digest;
	int value = 0;
	if(room_count<1)
		return -1;
	hash = Crypto.SHA256();
	hash->update("kuang|"+name+"|"+(string)slot);
	digest = String.string2hex(hash->digest());
	if(sizeof(digest)>=7)
		sscanf(digest[0..6],"%x",value);
	return value%room_count;
}

private int count_room_source(object room_ob,string name)
{
	int count;
	string source_path = MATERIAL_PATH+name;
	if(!room_ob)
		return 0;
	foreach(all_inventory(room_ob),object one){
		string path = one ? file_name(one) : "";
		if(path==source_path || has_prefix(path,source_path+"#"))
			count++;
	}
	return count;
}

private int spawn_worker_kuang(string name,string room)
{
	object room_ob;
	object source;
	mixed err;
	if(!kuangMap[name] || room=="" || search(room,"..")!=-1 ||
	   !MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
		return 0;
	err = catch { room_ob = (object)(ROOM_PATH+room); };
	if(err || !room_ob)
		return 0;
	err = catch {
		source = clone(MATERIAL_PATH+name);
		if(source)
			source->move(room_ob);
	};
	if(err || !source || environment(source)!=room_ob){
		if(source)
			destruct(source);
		return 0;
	}
	return 1;
}

private array(string) local_kuang_rooms(kuang one)
{
	array(string) result = ({});
	array(string) rooms;
	if(!one)
		return result;
	rooms = ROOMLEVELD->query_rooms(one->mLevel_min,one->mLevel_max);
	foreach(rooms,string room)
		if(MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
			result += ({room});
	return result;
}

private void reconcile_worker_kuang(string name)
{
	kuang one = kuangMap[name];
	array(string) rooms;
	mapping(string:int) desired = ([]);
	int missing;
	int desired_total;
	int existing_total;
	int spawned;
	if(!one){
		kuangNeed[name] = 0;
		return;
	}
	rooms = ROOMLEVELD->query_rooms(one->mLevel_min,one->mLevel_max);
	if(!sizeof(rooms)){
		kuangNeed[name] = 0;
		werror("[KUANGD][WORKER] no eligible rooms for %s\n",name);
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
		mixed err = catch { room_ob = (object)(ROOM_PATH+room); };
		int existing = !err && room_ob ? count_room_source(room_ob,name) : 0;
		int need = (int)desired[room]-existing;
		desired_total += (int)desired[room];
		existing_total += existing;
		for(int index=0;index<need;index++)
			if(spawn_worker_kuang(name,room))
				spawned++;
			else
				missing++;
	}
	kuangNeed[name] = missing;
	werror("[KUANGD][WORKER] generation=%d source=%s desired=%d existing=%d spawned=%d missing=%d\n",
		MAP_WORKERD->query_local_assignment_generation(),name,
		desired_total,existing_total,spawned,missing);
}

private void reconcile_worker_assignments()
{
	int generation = MAP_WORKERD->query_local_assignment_generation();
	if(generation<1 || generation==worker_assignment_generation)
		return;
	// A queued exact-room refill belongs to the previous assignment. Keeping
	// it would race the reconciliation pass and could create a duplicate node.
	quick_flush = ([]);
	foreach(indices(kuangMap),string name)
		reconcile_worker_kuang(name);
	worker_assignment_generation = generation;
}

private void fill_worker_kuang_need(string name)
{
	kuang one = kuangMap[name];
	int need = (int)kuangNeed[name];
	array(string) rooms;
	if(need<1)
		return;
	rooms = local_kuang_rooms(one);
	if(!sizeof(rooms))
		return;
	for(int index=0;index<need;index++){
		string room = rooms[random(sizeof(rooms))];
		if(spawn_worker_kuang(name,room) && kuangNeed[name]>0)
			kuangNeed[name]--;
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
	flush_kuang();
	call_out(quick_flush_kuang,QUICK_TIME);
}

protected void create()
{
	load_csv();
	if(worker_mode())
		call_out(start_worker_refresh,2);
	else{
		flush_kuang();
		//call_out(flush_kuang,FLUSH_TIME);
		call_out(quick_flush_kuang,QUICK_TIME);
	}
}


void load_csv()
{
	kuangMap = ([]);
	kuangNeed = ([]);
	string kuangData = Stdio.read_file(KUANG_CSV);
	array(string) lines = kuangData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			kuang tmpKuang = kuang();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				tmpKuang->name_cn = columns[1];
				tmpKuang->nums = (int)columns[2];
				tmpKuang->flush_time = (int)columns[3];
				tmpKuang->mLevel_min = (int)columns[4];
				tmpKuang->mLevel_max = (int)columns[5];
				tmpKuang->skill_level = (int)columns[6];
				array(string) tmpGets = columns[7]/"|";
				foreach(tmpGets,string eachget){
					if(eachget && sizeof(eachget)){
						array(string) tmp = eachget/":";
						int prob = (int)tmp[1];
						tmpKuang->get_m += ([tmp[0]:prob]);
					}
				}
				if(kuangMap[columns[0]] == 0)
					kuangMap[columns[0]] = tmpKuang;
				kuangNeed[columns[0]] = (int)columns[2];
			}
			else
				werror("------size of columns wrong in load_csv() of kuangd.pike------\n");
		}
	}
	else 
		werror("------read kuang.csv wrong in gamelib/single/daemon/kuangd.pike------\n");
}


//刷新矿的接口
void flush_kuang()
{
	if(worker_mode()){
		reconcile_worker_assignments();
		foreach(indices(kuangNeed),string name)
			fill_worker_kuang_need(name);
		quick_flush = ([]);
		call_out(flush_kuang,FLUSH_TIME);
		return;
	}
	foreach(indices(kuangNeed),string kuangname){
		int need_num = kuangNeed[kuangname];
		if(need_num > 0){
		//需要刷矿
			string s_log = "";
			string now=ctime(time());
			kuang tempKuang = kuangMap[kuangname];
			int roomlev_h = tempKuang->mLevel_max;
			int roomlev_l = tempKuang->mLevel_min;
			for(int i=0;i<need_num;i++){
				int roomlev = roomlev_l+random(roomlev_h-roomlev_l+1);
				string room = ROOMLEVELD->query_room(roomlev);
				if(room != ""){
					object kuang_ob;
					object room_ob;
					mixed err = catch{
						kuang_ob = clone(MATERIAL_PATH+kuangname);
						room_ob = (object)(ROOM_PATH+room);
					};
					if(kuang_ob && room_ob && !err){
						//Stdio.append_file(ROOT+"/log/flush_kuang.log",now[0..sizeof(now)-2]+":"+tempKuang->name_cn+"("+room+")\n");
						s_log += now[0..sizeof(now)-2]+":"+tempKuang->name_cn+"("+room+")\n";
						kuang_ob->move(ROOM_PATH+room);
						kuangNeed[kuangname]--;
					}
					else
						werror("------can't flush kuang : "+kuangname+"------\n");
				}
			}
			if(s_log != "")
				Stdio.append_file(ROOT+"/log/flush_kuang.log",s_log+"----------------------------\n");
		}
	}
	quick_flush = ([]); //清空矿物的快速刷新
	call_out(flush_kuang,FLUSH_TIME);
}

void quick_flush_kuang()
{
	if(worker_mode())
		reconcile_worker_assignments();
	if(sizeof(quick_flush)>0){
		foreach(indices(quick_flush),string name){
			int size = sizeof(quick_flush[name]);
			if(size>0){
				array(string) tmp = quick_flush[name];
				for(int i=0;i<size;i++){
					string room = tmp[i];
					if(worker_mode()){
						if(spawn_worker_kuang(name,room)){
							if(kuangNeed[name]>0)
								kuangNeed[name]--;
							string now=ctime(time());
							Stdio.append_file(ROOT+"/log/flush_kuang.log",now[0..sizeof(now)-2]+":quick_flush:"+kuangMap[name]->name_cn+"("+room+")\n----------------------\n");
						}
					}
					else{
						object ob = clone(MATERIAL_PATH+name);
						ob->move(ROOM_PATH+room);
						kuangNeed[name]--;
						string now=ctime(time());
						Stdio.append_file(ROOT+"/log/flush_kuang.log",now[0..sizeof(now)-2]+":quick_flush:"+ob->query_name_cn()+"("+room+")\n----------------------\n");
					}
				}
			}
		}
		quick_flush = ([]);
	}
	call_out(quick_flush_kuang,QUICK_TIME);
}

//获得需要采矿熟练度的接口
int query_need_level(string name)
{
	kuang tempKuang = kuangMap[name];
	if(tempKuang){
		return tempKuang->skill_level;	
	}
	else 
		return -1;

}

//获得出产物映射表的接口
mapping(string:int) query_get_m(string name)
{
	mapping(string:int) m_rtn = ([]);
	kuang tempKuang = kuangMap[name];
	if(tempKuang && sizeof(tempKuang->get_m)){
		m_rtn = tempKuang->get_m;
	}
	return m_rtn;
}

//矿被挖了后要设置待刷新矿的数量
void set_flush_num(string name,string room)
{
	if(!kuangMap[name])
		return;
	if(!kuangNeed[name])
		kuangNeed[name] = 1;
	else
		kuangNeed[name]++;
	// A legacy/unindexed room still contributes to the missing count and will
	// be replenished by the regular owner-aware pass; it is not a safe exact
	// quick-refresh destination.
	if(!room || room=="" || search(room,"..")!=-1)
		return;
	if(worker_mode() &&
	   !MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
		return;
	if(quick_flush == ([]))
		quick_flush[name] = ({room});
	else if(quick_flush[name] == 0)
		quick_flush[name] = ({room});
	else
		quick_flush[name] += ({room});
}
