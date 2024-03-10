/**************************************************************************************************************
 *地图搜索控制进程
 *由caijie写于2008/12/25
 *玩家点击地图后, 显示东南西北四个方向的房间最多5个
 ***************************************************************************************************************/


#include <globals.h>
#include <gamelib/include/gamelib.h>
#define NUM 5//当前房间的相邻房间的个数

private mapping(string:mapping(string:string)) all_map = ([]);
/*
	map=([当前房间英文名:(["east":向东方向的第1个房间-向东方向的第1个房间-...-向东方向的第5个房间,"west":"...","south":"...","north":"..."]),...]);
*/

void create()
{
}



//查询当前房间的direction方向的下一个房间
object query_next_room(object this_room,string direction){
	object room;
	string room_path = (this_room->exits)[direction];
	if(room_path&&sizeof(room_path)){
		mixed err = catch{
			room = clone(room_path);
		};
	}
	return room;
}

string query_map(object pre_room){
	string room_name = pre_room->query_name();
	mapping map_tmp = all_map[room_name];
	string s = "";
	if(map_tmp&&sizeof(map_tmp)){
		string dire_desc = map_tmp["north"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "北↑："+dire_desc+"\n";
		}
		dire_desc = map_tmp["west"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "西←："+dire_desc+"\n";
		}
		dire_desc = map_tmp["east"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "东→："+dire_desc+"\n";
		}
		dire_desc = map_tmp["south"];
		if(dire_desc&&sizeof(dire_desc)){
			s += "南↓："+dire_desc+"\n";
		}
	}
	else{
		//进行搜索
		object next_room,tmp_room;
		string direction = "north";
		//北
		s += "北↑：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
		direction = "west";
		s += "西←：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
		direction = "east";
		s += "东→：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
		direction = "south";
		s += "南↓：";
		tmp_room = pre_room;
		for(int i=0;i<NUM;i++){
			next_room = query_next_room(tmp_room,direction);
			if(!next_room){
				break;
			}
			else{
				if(!all_map[room_name]){
					all_map[room_name]=([]);
				}
				if(!all_map[room_name][direction]){
					all_map[room_name][direction]=next_room->query_name_cn();
					s += next_room->query_name_cn();
				}
				else{
					all_map[room_name][direction] += "-"+next_room->query_name_cn();
					s += "-"+next_room->query_name_cn();
				}
				tmp_room = next_room;
			}
		}
		s += "\n";
	}
	return s;
}
