//为实现伪副本结构而建立的守护模块，主要是维护队伍号到副本地址的映射表
//

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define ROOM_PATH ROOT "/gamelib/d/" //副本房间目录
#define FUBEN_CSV ROOT "/gamelib/data/fb.csv" //副本列表
#define FLUSH_TIME 420

//主要的映射表，"队伍id/fb_name":（{房间1的地址，房间2的地址....}）
private mapping(string:array(object)) fb_map = ([]);

//副本名:（{房间1的文件名，房间2的文件名....}）
private mapping(string:array(string)) fb_room = ([]);

//走出副本后回到的地图，一般在副本入口处,副本名:离开后的地图文件
private mapping(string:string) fb_leave = ([]);

//副本id:([玩家1id:1，玩家2id:1...])，此mapping记录了当前在副本中的玩家id
private mapping(string:mapping(string:int)) fb_members = ([]);

void create()
{
	fb_leave = ([]);
	fb_members = ([]);
	fb_map = ([]);
	load_csv();
	call_out(flush_fb_map,FLUSH_TIME);
}

void load_csv()
{
	werror("==========  [FBD start!]  =========\n");
	fb_room = ([]);
	string fbData = Stdio.read_file(FUBEN_CSV);
	array(string) lines = fbData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/",";
			if(sizeof(columns) == 3){
				string fb_name = columns[0];
				fb_room[fb_name] = ({});
				array(string) tmp = columns[1]/":";
				tmp -= ({});
				foreach(tmp,string room){
					if(fb_room[fb_name] == 0)
						fb_room[fb_name] = ({room});
					else
						fb_room[fb_name] += ({room});
				}
				fb_leave[fb_name] = columns[2];
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [FBD end!]  =========\n");
}

object query_fb_room(string room_name,int room_num,string team_id,int flag)
{
	string fb_id = team_id+"/"+room_name;
	if(fb_map[fb_id] == 0){
		//没有记录
		if(flag == 0){
			//从外面进入副本，则新建个副本记录
			array(string) tmp = fb_room[room_name];
			if(tmp && sizeof(tmp)){
				for(int i=0;i<sizeof(tmp);i++){
					/////////////////////////////////////////////
					object room = 0; 
					string new_room_path = ROOM_PATH+tmp[i];
					program p = compile_file(new_room_path);
					//加入到当前进程的master中的programs中
					if(p){
						master()->programs[new_room_path]=p;
						room=clone(p);
					}
					/////////////////////////////////////////////
					if(room){
						if(i==0)
							fb_map[fb_id] = ({room});
						else
							fb_map[fb_id] += ({room});
					}
				}
			}
		}
		else if(flag == 1){
			//在副本内部队伍重组，则冲送回复活点
			return 0;
		}
	}
	array(object) rooms = fb_map[fb_id];
	if(room_num<sizeof(rooms)){
		return (object)rooms[room_num];
	}
}

//玩家进入副本时，fb_members要加入此玩家的id
void add_fb_members(string fb_id,string player_name)
{
	if(fb_members[fb_id] == 0)
		fb_members[fb_id] = ([player_name:1]);
	else if(!fb_members[fb_id][player_name]) 
		fb_members[fb_id][player_name] = 1;
}

//玩家出副本时，fb_members要删除玩家的id
void delete_fb_members(string fb_id,string player_name)
{	
	if(fb_members[fb_id] && fb_members[fb_id][player_name])
		m_delete(fb_members[fb_id],player_name);
}
//查阅玩家是否在副本里面，判断副本不打开动态npc的条件
int query_fb_memebers(string fb_id,string player_name){
	//werror("=======query fb status\n");
	if(!fb_id) return 0;
	if(search(fb_id,"posanzhidi") != -1) return 0;//如果是这里的地图，则依然打开动态npc，不受副本的影响
	if(fb_members[fb_id] && fb_members[fb_id][player_name]) return 1;
	return 0;
}
//获得玩家离开时的应该回到的地图文件,如congxianzhen/congxianzhen
string query_fb_leave_room(string fb_name)
{
	string s_rtn = "";
	if(fb_leave[fb_name])
		s_rtn = fb_leave[fb_name];
	return s_rtn;
}

void flush_fb_map()
{
	if(fb_map && sizeof(fb_map)){
		foreach(indices(fb_map),string fb_id){
			array(string) tmp = fb_id/"/";
			if(sizeof(tmp) == 2){
				string team_id = tmp[0];
				foreach(indices(fb_members[fb_id]),string name){
					if(name && sizeof(name)){
						object ob = find_player(name);
						if(!ob)
							m_delete(fb_members[fb_id],name);
					}
				}
				if(TERMD->query_termId(team_id) == 0){
					array(object) maps = fb_map[fb_id];
					if(sizeof(fb_members[fb_id]) == 0){
						foreach(maps,object tmp_ob){
							tmp_ob->remove();
						}
						m_delete(fb_map,fb_id);
						m_delete(fb_members,fb_id);
					}
					//else{
					//	foreach(indices(fb_members[fb_id]),string name){
					//		object ob = find_player(name);
					//		if(!ob)
					//			m_delete(fb_members[fb_id],name);
					//	}
					//}
				}
			}
		}
	}
	call_out(flush_fb_map,FLUSH_TIME);
}

string check_fb()
{
	string s_rtn = "here we go ";
	int fb_nums = sizeof(fb_map);
	if(fb_map && fb_nums){
		s_rtn += "now fb total："+fb_nums+"\n";
		foreach(indices(fb_map),string fb_id){
			s_rtn += fb_id+"：";
			if(fb_members[fb_id]){
				foreach(indices(fb_members[fb_id]),string player_name){
					s_rtn += player_name+",";
				}
				s_rtn += "\n";
			}
			else
				s_rtn += "no players in\n";
		}
	}
	else 
		s_rtn += "no fb exist\n";
	return s_rtn;
}
