//用于新副业织布，制皮所需材料的特殊怪物掉落的守护程序，主要负责这些材料的掉落
//
//核心数据结构:
//1.定义了一个掉落列表的类 : droplist
//  droplist里有一个为普通材料的掉落数组 normal_arr; 一个为特殊材料的掉落array spec_arr
//
//  每个npc都对应一个掉落列表类,从而形成一个总的副业材料掉落映射表
// mapping(string:droplist) vicedrop_m
//
//上述结构都是通过读取ROOT/gamelib/data/vicedrop.csv中的内容来建立的。
//
//由liaocheng于07/10/17开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define VICEDROP_CSV ROOT "/gamelib/data/vicedrop.csv" //掉落列表

class droplist
{
	array(string) normal_arr;//普通材料掉落表
	array(string) spec_arr;//特殊材料掉落表
}

private mapping(string:droplist) vicedrop_m = ([]); //npc掉落总表

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [VICEDROPD start!]  =========\n");
	vicedrop_m = ([]);
	string vicedropData = Stdio.read_file(VICEDROP_CSV);
	array(string) lines = vicedropData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			droplist tmpVicedrop = droplist();
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 3){
				string npc_name = columns[0];
				tmpVicedrop->normal_arr = columns[1]/"|";
				tmpVicedrop->spec_arr = columns[2]/"|";
				if(vicedrop_m[npc_name] == 0)
					vicedrop_m[npc_name] = tmpVicedrop;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [VICEDROPD end!]  =========\n");
}

//获得掉落的装备
string get_vicedrop_item(string npc_name)
{
	droplist tmplist = vicedrop_m[npc_name];
	if(tmplist && sizeof(tmplist)){
		return(tmplist->normal_arr[random(sizeof(tmplist->normal_arr))]);
	}
	else
		return "";
}

//获得掉落的特殊东西
string get_vicedrop_spec(string npc_name)
{
	droplist tmplist = vicedrop_m[npc_name];
	if(tmplist && sizeof(tmplist)){
		return(tmplist->spec_arr[random(sizeof(tmplist->spec_arr))]);
	}
	else
		return "";
}

//判断是否掉落材料
int can_vicedrop(string npc_name)
{
	int rtn = 0;
	if(vicedrop_m[npc_name]&&sizeof(vicedrop_m[npc_name]))
		rtn = 1;
	return rtn;
}

//获得掉落装备的个数
int get_drop_nums()
{
	int drop_num = 1;
	int np = random(100);
	if(np<20)
		drop_num = 3;
	else if(np<50)
		drop_num = 2;
	return drop_num;
}
