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

//副本内部房间路径:副本名。地图飞行、重登恢复和紧急脱离
//共用这份反向索引，避免玩家进入未绑定队伍的公共基础房间。
private mapping(string:string) fb_room_name = ([]);

//走出副本后回到的地图，一般在副本入口处,副本名:离开后的地图文件
private mapping(string:string) fb_leave = ([]);

// 安全入口目录的展示名；未知新副本回退到配置ID，不影响旧CSV兼容。
private mapping(string:string) fb_display_name = ([
	"mingfu":"冥府","duwuguiyu":"毒雾鬼域","youlan":"幽澜秘境",
	"lvxie":"绿血深渊","jiaolong":"蛟龙巢穴","bawangmoku":"霸王魔窟",
	"lingranzhiyan_h":"灵燃之焰（仙）","hunfeizhijing_h":"魂飞之井（仙）",
	"posanzhidi_h":"魄散之眼（仙）","lingranzhiyan_m":"灵燃之焰（妖）",
	"hunfeizhijing_m":"魂飞之井（妖）","posanzhidi_m":"魄散之眼（妖）",
	"huyaodong":"狐妖洞","youanzhaoze":"幽暗沼泽",
	"yunshuixianjing":"云水仙境","yunraotiangong":"云绕天宫",
]);

//副本id:([玩家1id:1，玩家2id:1...])，此mapping记录了当前在副本中的玩家id
private mapping(string:mapping(string:int)) fb_members = ([]);

protected void create()
{
	fb_leave = ([]);
	fb_members = ([]);
	fb_map = ([]);
	fb_room_name = ([]);
	load_csv();
	call_out(flush_fb_map,FLUSH_TIME);
}

private string normalize_fb_room_path(string|zero room_path)
{
	string prefix;
	if(!room_path || room_path=="")
		return "";
	room_path = (room_path/"#")[0];
	prefix = ROOT+"/gamelib/d/";
	if(has_prefix(room_path,prefix))
		return room_path[sizeof(prefix)..];
	if(has_prefix(room_path,"/gamelib/d/"))
		return room_path[sizeof("/gamelib/d/")..];
	if(has_prefix(room_path,"gamelib/d/"))
		return room_path[sizeof("gamelib/d/")..];
	return room_path;
}

void load_csv()
{
	werror("==========  [FBD start!]  =========\n");
	fb_room = ([]);
	fb_room_name = ([]);
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
					fb_room_name[normalize_fb_room_path(room)] = fb_name;
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
					object|zero room = 0; 
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
	if(rooms && room_num>=0 && room_num<sizeof(rooms)){
		return (object)rooms[room_num];
	}
	return 0;
}

//从基础程序路径或带 #序号的克隆路径反查副本名。
string query_fb_name_by_room_path(string|zero room_path)
{
	string normalized = normalize_fb_room_path(room_path);
	if(normalized!="" && fb_room_name[normalized])
		return fb_room_name[normalized];
	return "";
}

int is_fb_room_path(string|zero room_path)
{
	return query_fb_name_by_room_path(room_path)!="";
}

string query_fb_name_by_id(string|zero fb_id)
{
	array(string) parts;
	if(!fb_id || fb_id=="")
		return "";
	parts = fb_id/"/";
	if(sizeof(parts)==2 && fb_room[parts[1]])
		return parts[1];
	return "";
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

//玩家通过飞行、复活或其他非 fb_leave 路径离开时也要解绑，
//否则副本成员表和动态怪判定会长期残留。
void detach_fb_member(object player)
{
	string old_fb_id;
	if(!player)
		return;
	old_fb_id = (string)(player->fb_id || "");
	if(old_fb_id!="")
		delete_fb_members(old_fb_id,player->query_name());
	player->fb_id = 0;
}
//查阅玩家是否在副本里面，判断副本不打开动态npc的条件
int query_fb_memebers(string|zero fb_id,string player_name){
	//werror("=======query fb status\n");
	if(!fb_id) return 0;
	if(search(fb_id,"posanzhidi") != -1) return 0;//如果是这里的地图，则依然打开动态npc，不受副本的影响
	if(fb_members[fb_id] && fb_members[fb_id][player_name]) return 1;
	return 0;
}
//获得玩家离开时的应该回到的地图文件,如congxianzhen/congxianzhen
string query_fb_leave_room(string|zero fb_name)
{
	string s_rtn = "";
	if(fb_name && fb_leave[fb_name])
		s_rtn = fb_leave[fb_name];
	return s_rtn;
}

mapping(string:string) query_safe_fb_entrance(string|zero fb_name)
{
	if(!fb_name || fb_name=="" || !fb_room[fb_name] || !fb_leave[fb_name])
		return ([]);
	return ([
		"id":fb_name,
		"name":fb_display_name[fb_name] || fb_name,
		"path":fb_leave[fb_name],
	]);
}

array(mapping(string:string)) query_safe_fb_catalog()
{
	array(mapping(string:string)) result = ({});
	foreach(sort(indices(fb_room)),string fb_name){
		mapping(string:string) entry = query_safe_fb_entrance(fb_name);
		if(sizeof(entry))
			result += ({entry});
	}
	return result;
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
