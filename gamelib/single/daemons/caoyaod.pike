//草药的守护程序，主要负责建立和维护游戏中草药的信息表，包括草药的刷新个数，刷新时间，草药出现的地图等级，草药的出产物等，并且还要负责草药在游戏世界的刷新
//
//核心数据结构:
//1.草药信息表:
// class caoyao; 打算采用类来记录草药的信息 
//
// 下面这个mapping作为备用方案
// mapping(string:array(mixed)) caoyao_m = 
//   (["tongcaoyao":({"草药名",刷新数量,刷新时间(以分钟为单位),地图最低等级，地图最高等级，需要熟练度})
//                    [0]     [1]           [2]                 [3]            [4]          [5]
//       ...
//   ])
//2.草药产出物表，该表记录玩家采药时，可能获得的物品，虽然采药一般不会获得其他物品，但接口还是留在这儿:
// mapping(string:mapping(string:int)) get_m = 
//   (["tongcaoyao":(["tongcaoyaoshi":100,"xuanhuangshi":10,]),
//                     出产物名  :  概率
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/caoyao.csv中的内容来建立的。
//
//由liaocheng于07/5/25开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define CAOYAO_CSV ROOT "/gamelib/data/material/caoyao.csv" //草药物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
#define ROOM_PATH ROOT "/gamelib/d/" //房间根目录
//#define FLUSH_TIME 900
//草药的刷新时间比较多样性，这也是这个守护模块的难点
//#define FLUSH_TIME 120 //测试用，循环执行flush_caoyao()的时间间隔
#define FLUSH_TIME 900 //正式用，6分钟为一单位..
//#define FLUSH_TIME 300 //2024版正式用，6分钟为一单位，每5分钟增加一次15，也就是说原来15分钟的，压缩到5分钟一次刷新了，60分钟的压缩到20分钟刷新一次
#define MAX_TIME 360  //刷新时间最长的草药的刷新时间
#define MAX_ITEMS_PER_ROOM 10  //每个房间最多容纳的物品数量，超过则不再添加草药

class caoyao
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

private mapping(string:caoyao) caoyaoMap = ([]); //物品信息总表
private mapping(string:int) caoyaoNeed = ([]); //记录目前需要刷的草药数量
private mapping(string:array) quick_flush = ([]); //快速刷草药,在固定地点刷出草药,在caoyao_flush中被赋值
//([caoyao_name:({time,房间1,房间2,房间3....})])
private mapping(int:array(string)) caoyao_flush_time = ([]);//以刷新时间为索引的映射表,时间为15分钟的倍数
//([15:({caoyao1,caoyao2}),
//  30:({caoyao3,caoyao5}), 
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

private int stable_room_slot(string name,int slot,int room_count)
{
	object hash;
	string digest;
	int value = 0;
	if(room_count<1)
		return -1;
	hash = Crypto.SHA256();
	hash->update("caoyao|"+name+"|"+(string)slot);
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

private int spawn_worker_caoyao(string name,string room)
{
	object room_ob;
	object source;
	mixed err;
	if(!caoyaoMap[name] || room=="" || search(room,"..")!=-1 ||
	   !MAP_WORKERD->local_worker_owns_room("/gamelib/d/"+room))
		return 0;
	err = catch { room_ob = (object)(ROOM_PATH+room); };
	if(err || !room_ob || sizeof(all_inventory(room_ob))>=MAX_ITEMS_PER_ROOM)
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

private array(string) local_caoyao_rooms(caoyao one)
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

private void reconcile_worker_caoyao(string name)
{
	caoyao one = caoyaoMap[name];
	array(string) rooms;
	mapping(string:int) desired = ([]);
	int missing;
	int desired_total;
	int existing_total;
	int spawned;
	if(!one){
		caoyaoNeed[name] = 0;
		return;
	}
	rooms = ROOMLEVELD->query_rooms(one->mLevel_min,one->mLevel_max);
	if(!sizeof(rooms)){
		caoyaoNeed[name] = 0;
		werror("[CAOYAOD][WORKER] no eligible rooms for %s\n",name);
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
			if(spawn_worker_caoyao(name,room))
				spawned++;
			else
				missing++;
	}
	caoyaoNeed[name] = missing;
	worker_initialized[name] = 1;
	werror("[CAOYAOD][WORKER] generation=%d source=%s desired=%d existing=%d spawned=%d missing=%d\n",
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

private void reconcile_all_worker_caoyao()
{
	foreach(indices(caoyaoMap),string name)
		reconcile_worker_caoyao(name);
}

private void fill_worker_caoyao_need(string name)
{
	caoyao one = caoyaoMap[name];
	int need = (int)caoyaoNeed[name];
	array(string) rooms;
	int attempts = need*4;
	if(need<1)
		return;
	rooms = local_caoyao_rooms(one);
	if(!sizeof(rooms))
		return;
	for(int index=0;index<attempts && caoyaoNeed[name]>0;index++){
		string room = rooms[random(sizeof(rooms))];
		if(spawn_worker_caoyao(name,room))
			caoyaoNeed[name]--;
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
	// A restart must restore every configured herb immediately, including the
	// 30/60-minute varieties. The cadence below remains unchanged and only
	// governs replenishment after players gather them.
	if(refresh_worker_generation())
		reconcile_all_worker_caoyao();
	call_out(flush_caoyao,FLUSH_TIME);
}

protected void create()
{
	load_csv();
	if(worker_mode())
		call_out(start_worker_refresh,2);
	else
		flush_caoyao();
	
	//call_out(flush_caoyao,FLUSH_TIME);
}

void load_csv()
{
	
	caoyaoMap = ([]);
	caoyaoNeed = ([]);
	caoyao_flush_time = ([]);
	string caoyaoData = Stdio.read_file(CAOYAO_CSV);
	array(string) lines = caoyaoData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			caoyao tmpCaoyao = caoyao();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				tmpCaoyao->name_cn = columns[1];
				tmpCaoyao->nums = (int)columns[2];
				tmpCaoyao->flush_time = (int)columns[3];
				//写入到刷新时间表中
				if(caoyao_flush_time[tmpCaoyao->flush_time] == 0)
					caoyao_flush_time[tmpCaoyao->flush_time] = ({columns[0]});
				else
					caoyao_flush_time[tmpCaoyao->flush_time] += ({columns[0]});
				tmpCaoyao->mLevel_min = (int)columns[4];
				tmpCaoyao->mLevel_max = (int)columns[5];
				tmpCaoyao->skill_level = (int)columns[6];
				array(string) tmpGets = columns[7]/"|";
				foreach(tmpGets,string eachget){
					if(eachget && sizeof(eachget)){
						array(string) tmp = eachget/":";
						int prob = (int)tmp[1];
						tmpCaoyao->get_m += ([tmp[0]:prob]);
					}
				}
				if(caoyaoMap[columns[0]] == 0)
					caoyaoMap[columns[0]] = tmpCaoyao;
				caoyaoNeed[columns[0]] = (int)columns[2];
			}
			else
				werror("------size of columns wrong in load_csv() of caoyaod.pike------\n");
		}
	}
	else 
		werror("------read caoyao.csv wrong in gamelib/single/daemon/caoyaod.pike------\n");



}


//刷新草药的接口
void flush_caoyao()
{
	flush_count += 15; //刷新时间是15的倍数
	string now=ctime(time());
	if(worker_mode()){
		if(refresh_worker_generation())
			reconcile_all_worker_caoyao();
		foreach(indices(caoyao_flush_time),int worker_time)
			if(flush_count%worker_time==0){
				array(string) names = caoyao_flush_time[worker_time];
				foreach(names,string name)
					if(!worker_initialized[name])
						reconcile_worker_caoyao(name);
					else
						fill_worker_caoyao_need(name);
			}
		if(flush_count>=MAX_TIME)
			flush_count = 0;
		call_out(flush_caoyao,FLUSH_TIME);
		return;
	}
	int need_reload = 1;
	foreach(indices(caoyaoNeed),string str_name){
		if(caoyaoNeed[str_name]>=2){
			Stdio.append_file(ROOT+"/log/flush_caoyao.log","--------no need to reload csv ----"+str_name+"------"+caoyaoNeed[str_name]+"----------\n");
			need_reload = 0;
			break;
		}
	}
	if(need_reload){
		Stdio.append_file(ROOT+"/log/flush_caoyao.log","--------reload csv --------------------\n");
		load_csv();
	}
	foreach(indices(caoyao_flush_time),int time){
		if(flush_count%time == 0){
		//到刷新时间了
			array(string) tmp_flush = caoyao_flush_time[time];
			if(tmp_flush && sizeof(tmp_flush)){
				int size = sizeof(tmp_flush);
				for(int i=0;i<size;i++){
					string caoyaoname = tmp_flush[i];
					Stdio.append_file(ROOT+"/log/flush_caoyao.log","-----------------caoyaoNeed[caoyaoname]:"+caoyaoNeed[caoyaoname]+"-----------\n");
					if(caoyaoNeed[caoyaoname]){
						int need_num = caoyaoNeed[caoyaoname];
						Stdio.append_file(ROOT+"/log/flush_caoyao.log",now[0..sizeof(now)-2]+":此次刷新 "+caoyaoname+" "+need_num+"株\n");
						caoyao tempCaoyao = caoyaoMap[caoyaoname];
						int roomlev_h = tempCaoyao->mLevel_max;
						int roomlev_l = tempCaoyao->mLevel_min;
						for(int j=0;j<need_num;j++){
							int roomlev = roomlev_l+random(roomlev_h-roomlev_l+1);
							string room = ROOMLEVELD->query_room(roomlev);
							if(room != ""){
								// 检查房间内已有的物品数量，超过MAX_ITEMS_PER_ROOM则跳过
								mixed err = catch{
									string room_path = ROOM_PATH+room;
									object room_ob = load_object(room_path);
									if(room_ob){
										array(object) items = all_inventory(room_ob);
										int item_count = sizeof(items);
										if(item_count >= MAX_ITEMS_PER_ROOM){
											// 房间内物品已满，跳过此次刷新
											continue;
										}
									}
								};
								if(err){
									werror("caoyaod: ERROR checking room %s: %O\n", room, err);
								}
								object caoyao_ob = clone(MATERIAL_PATH+caoyaoname);
								if(caoyao_ob){
									Stdio.append_file(ROOT+"/log/flush_caoyao.log",now[0..sizeof(now)-2]+":"+tempCaoyao->name_cn+"("+room+")\n");
									caoyao_ob->move(ROOM_PATH+room);
									caoyaoNeed[caoyaoname]--;
								}
								else
									werror("------can't flush caoyao : "+caoyaoname+"------\n");
							}
							//else
							//	werror("------get room wrong with roomlevel = "+roomlev+"------\n");
						}
					}
				}
			}
			Stdio.append_file(ROOT+"/log/flush_caoyao.log","----------------------------\n");
		}
	}
	if(flush_count >= MAX_TIME)
		flush_count = 0;
	call_out(flush_caoyao,FLUSH_TIME);
}

//获得需要采药熟练度的接口
int query_need_level(string name)
{
	caoyao tempCaoyao = caoyaoMap[name];
	if(tempCaoyao){
		return tempCaoyao->skill_level;	
	}
	else 
		return -1;

}

//获得出产物映射表的接口
mapping(string:int) query_get_m(string name)
{
	mapping(string:int) m_rtn = ([]);
	caoyao tempCaoyao = caoyaoMap[name];
	if(tempCaoyao && sizeof(tempCaoyao->get_m)){
		m_rtn = tempCaoyao->get_m;
	}
	return m_rtn;
}

//草药被挖了后要设置待刷新草药的数量
void set_flush_num(string name)
{
	if(!caoyaoMap[name])
		return;
	if(!caoyaoNeed[name])
		caoyaoNeed[name] = 1;
	else
		caoyaoNeed[name]++;
}
