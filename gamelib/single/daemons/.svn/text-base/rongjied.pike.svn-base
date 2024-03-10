//熔解的守护程序，主要负责建立和维护游戏中熔解的信息表，主要是物品与熔解产物的对应
//
//核心数据结构:
//1.下面这个mapping作为锻造的总表
//  定义了一个熔解的类 : rongjie 
// mapping(int:rongjie) rongjie_m
//
//2.等级下限数组,建立这个数组是为了更容易定位被熔解所属的等级范围
//  levelLimit = ({1,2,6,10,...});
//  这个数组在模块启动建立rongjie_m的时候填入
//上述结构都是通过读取ROOT/gamelib/data/material/rongjie.csv中的内容来建立的。
//
//由liaocheng于07/5/31开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define RONGJIE_CSV ROOT "/gamelib/data/material/rongjie.csv" //矿物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下

class rongjie
{
	string kuang; //[1]熔解出矿石的name,如tongkuangshi
	int kuang_num;//[2]熔解出矿石的个数
	string baoshi; //[3]熔解出宝石的name,如xuanhuangshi
	int baoshi_num; //[4]熔解出宝石个数的上限
}

private mapping(int:rongjie) rongjie_m = ([]); //熔解信息总表
private array(int) levelLimit = ({});
//物品稀有度与出宝石几率的对应表
//3,4为精致，5为神炼，6为天降，7为幻化
private mapping(int:int) prob = ([3:10,4:10,5:30,6:70,7:100,]);

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [RONGJIED start!]  =========\n");
	rongjie_m = ([]);
	string rongjieData = Stdio.read_file(RONGJIE_CSV);
	array(string) lines = rongjieData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			rongjie tmpRongjie = rongjie();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 5){
				int level = (int)columns[0];
				levelLimit += ({level});
				tmpRongjie->kuang = columns[1]; 
				tmpRongjie->kuang_num = (int)columns[2];
				tmpRongjie->baoshi = columns[3];
				tmpRongjie->baoshi_num = (int)columns[4];
				if(rongjie_m[level] == 0)
					rongjie_m[level] = tmpRongjie;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
		levelLimit = sort(levelLimit);
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [RONGJIED end!]  =========\n");
}

string query_can_rongjie(object player)
{
	string s_rtn = "";
	array all_obj = all_inventory(player);
	mapping(string:int) name_count=([]);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor"||ob->query_item_type()=="decorate"||ob->query_item_type()=="jewelry"){
			if(!ob["equiped"]){
				if(ob->query_item_rareLevel()>=1 || ob->query_item_from()!=""){
					string name = ob->query_name();
					s_rtn += "["+ob->query_name_cn()+":viceskill_rongjie_confirm 0 "+name+" "+name_count[name]+"]\n";
					name_count[name]++;
				}
			}
		}
	}
	return s_rtn;
}

//获得矿物
object get_kuang(int level)
{
	werror("-------get_kuang call-----------\n");
	int lev = 0; 
	for(int i=sizeof(levelLimit)-1;i>=0;i--){
		if(level > levelLimit[i]){
			lev = levelLimit[i];
			break;
		}
	}
	werror("---------lev = "+lev+"-------------\n");
	rongjie tmp = rongjie_m[lev];
	if(tmp){
		string kuang_name = tmp->kuang;
		object kuang = clone(MATERIAL_PATH+kuang_name);
		if(kuang){
			werror("------kuang name = "+kuang_name+"------\n");
			kuang->amount = tmp->kuang_num;
			return kuang;
		}
	}
	return 0;
}

//获得宝石
object get_baoshi(int level,int rare_level)
{
	int lev = 0; 
	for(int i=sizeof(levelLimit)-1;i<0;i--){
		if(level > levelLimit[i]){
			lev = levelLimit[i];
			break;
		}
	}
	int ran = prob[rare_level];
	if((random(100)+1) < ran){
		rongjie tmp = rongjie_m[lev];
		if(tmp){
			string baoshi_name = tmp->baoshi;
			int get_num = 1;
			if(tmp->baoshi_num > 1)
				get_num += random(tmp->baoshi_num);
			object baoshi = clone(MATERIAL_PATH+baoshi_name);
			if(baoshi){
				baoshi->amount = get_num;
				return baoshi;
			}
		}
	}
	return 0;
}

//这个调用是将上面两个调用综合在了一起，
array(object) get_rongjie_items(int level,int rare_level)
{
	array(object) a_rtn = ({});
	int lev = 0; 
	for(int i=sizeof(levelLimit)-1;i>=0;i--){
		if(level >= levelLimit[i]){
			lev = levelLimit[i];
			break;
		}
	}
	werror("---------lev = "+lev+"-------------\n");
	rongjie tmp = rongjie_m[lev];
	if(tmp){
		string kuang_name = tmp->kuang;
		object kuang = clone(MATERIAL_PATH+kuang_name);
		if(kuang){
			werror("------kuang name = "+kuang_name+"------\n");
			kuang->amount = tmp->kuang_num;
			a_rtn = ({kuang});
		}
		//得到出宝石的概率
		int ran = prob[rare_level];
		werror("----------get baoshi prob = "+ran+"------------\n");
		if((random(100)+1) < ran){
			string baoshi_name = tmp->baoshi;
			int get_num = 1;
			if(tmp->baoshi_num > 1)
				get_num += random(tmp->baoshi_num);
			object baoshi = clone(MATERIAL_PATH+baoshi_name);
			if(baoshi){
				baoshi->amount = get_num;
				a_rtn += ({baoshi});
			}
		}
	}
	return a_rtn;
}
