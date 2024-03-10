//主要是读取房间等级，建立房间名与等级的映射表，并提供接口给需要与房间等级挂钩的模块调用，如kuangd.pike 和caoyaod.pike
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define ROOM_LEV DATA_ROOT "room_level.log" //房间等级文件

//等级:({房间1,房间2,....}) 如1:({jinaodao/xiangshudongsiceng,...})它含有上层目录
private mapping(int:array(string)) room_level = ([]);
//房间名与含上层目录的名的对应([xiangshudongsiceng:jinaodao/xiangshudongsiceng])
private mapping(string:string) quick_room_level = ([]);

//以等级分的传送阵映射表
private mapping(int:array(string)) human_transfer_room = ([
	10:({"kunlunshan/xianzhenxuyugong","huangjiazhuang/jianzhenhuangjiazhuang"}),
	15:({"jiangjunmu/xianzhenjiangjunmu"}),
	20:({"liangjinghu/xianzhenliangjinghu"}),
	25:({"plshuige/xianzhenpenglaishuige"}),
	30:({"muye/xianzhenmuye"}),
	40:({"waihai/xianzhenwaihai","liuguangpingyuan/xianzhenliuguangping"}),
	45:({"yandigu/xianzhenyandigu"}),
	50:({"plxianjing/xianzhenplxianjing"})
]);
private mapping(int:array(string)) monst_transfer_room = ([
	10:({"wugongdong/yaozhenwugongdongxue","jinaodao/yaozhenbiyougong"}),
	15:({"fushoushan/yaozhenfushoushan"}),
	20:({"liangjinghu/yaozhenliangjinghu"}),
	25:({"plshuige/yaozhenpenglaishuige"}),
	30:({"muye/yaozhenmuye"}),
	40:({"waihai/yaozhenwaihai","liuguangpingyuan/yaozhenliuguangpingy"}),
	45:({"fuxishan/yaozhenfuxigong"}),
	50:({"plxianjing/yaozhenplxianjing"})
]);

void create()
{
	load_file();
}

void load_file()
{
	room_level = ([]);
	quick_room_level = ([]);
	string fileData = Stdio.read_file(ROOM_LEV);
	array(string) lines = fileData/"\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/"|";
			if(sizeof(columns) == 3){
				int level = (int)columns[0];
				if(room_level[level] == 0){
					room_level[level] = ({columns[1]});	
					array(string) tmp1 = columns[1]/"/";
					quick_room_level[tmp1[1]] = columns[1];
				}
				else{
					room_level[level] += ({columns[1]});	
					array(string) tmp1 = columns[1]/"/";
					quick_room_level[tmp1[1]] = columns[1];
				}
			}
			else
				werror("------size of columns wrong in load_file() of roomLeveld.pike------\n");
		}
	}
	else
		werror("------read room_level.log wrong in gamelib/single/daemon/roomLeveld.pike------\n");
}

//返回一个房间路径的接口，返回值是d/以后的目录，如"jinaodao/maocaowu"
string query_room(int level)
{
	if(room_level[level] && sizeof(room_level[level])){
		array(string) tmp_rooms =  room_level[level];
		int index = random(sizeof(tmp_rooms));
		return tmp_rooms[index];
	}
	else 
		return "";
}

string query_room_quick(string room_name)
{
	if(quick_room_level[room_name] && sizeof(quick_room_level[room_name]))
		return quick_room_level[room_name];
	else
		return "";
}

mapping(int:array(string)) query_transfer_list(string race)
{
	if(race == "monst")
		return monst_transfer_room;
	else if(race == "human")
		return human_transfer_room;
	else
		return 0;
}
