//boss掉落的守护程序，主要负责boss死亡后的装备物品掉落
//
//核心数据结构:
//1.定义了一个掉落列表的类 : droplist
//  droplist里有两个掉落数组，一个为装备的掉落数组 item_arr; 一个为材料配方的掉落数字 other_arr
//
//  每个boss都对应一个掉落列表类,从而形成一个总的boss掉落映射表
// mapping(string:droplist) bossdrop_m
//
//上述结构都是通过读取ROOT/gamelib/data/bossdrop.csv中的内容来建立的。
//
//由liaocheng于07/6/20开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define BOSSDROP_CSV ROOT "/gamelib/data/bossdrop.csv" //boss掉落列表

class droplist
{
	array(string) item_arr;//装备的掉落数组
	array(string) other_arr;//材料配方的掉落数组
	string spec_item;//100%掉落的特殊物品，比如霸王魔窟的boss会掉落霸王徽记
}

private mapping(string:droplist) bossdrop_m = ([]); //boss掉落总表

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [BOSSDROPD start!]  =========\n");
	bossdrop_m = ([]);
	string bossdropData = Stdio.read_file(BOSSDROP_CSV);
	array(string) lines = bossdropData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			droplist tmpBossdrop = droplist();
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 4){
				string boss_name = columns[0];
				tmpBossdrop->item_arr = columns[1]/"|";
				tmpBossdrop->other_arr = columns[2]/"|";
				tmpBossdrop->spec_item = columns[3];
				if(bossdrop_m[boss_name] == 0)
					bossdrop_m[boss_name] = tmpBossdrop;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [BOSSDROPD end!]  =========\n");
}

//获取boss特殊物品，如霸王魔窟boss的霸王徽记
//由lioacheng于07/12/11添加                                                                     
string get_bossdrop_specitem(string boss_name)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		if(tmplist->spec_item)
			return(tmplist->spec_item);
		else
			return "";
	}
	else
		return "";
}

//获得掉落的装备
string get_bossdrop_item(string boss_name)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		return(tmplist->item_arr[random(sizeof(tmplist->item_arr))]);
	}
	else
		return "";
}

//获得掉落的其他东西
string get_bossdrop_other(string boss_name)
{
	droplist tmplist = bossdrop_m[boss_name];
	if(tmplist && sizeof(tmplist)){
		return(tmplist->other_arr[random(sizeof(tmplist->other_arr))]);
	}
	else
		return "";
}

//获得掉落装备的个数
int get_drop_nums()
{
	int drop_num = 1;
	int np = random(100);
	if(np<10)
		drop_num = 3;
	else if(np<30)
		drop_num = 2;
	return drop_num;
}
