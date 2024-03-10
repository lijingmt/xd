/**************************************************************************************************************
 *兑换物品守护模块
 *由caijie写于2008/12/3
 ***************************************************************************************************************/
#include <globals.h>
#include <gamelib/include/gamelib.h>

#define ITEM_LIST  ROOT "/gamelib/data/items_exchanged.csv" //替换路径

class item
{
	string name_cn;//[1]中文名
	string type;//[2]物品类别 如武器，重甲
	string zhenying;//[3]阵营
	string need_name;//[4]需要的物品名
	int need_num;//[5]需要物品的数量
}


private static mapping(string:item) exchange_item_list = ([]);

void create(){
	load_list();
}

void load_list()
{
	exchange_item_list = ([]);
	array(string) map_tmp = ({});
	string liandanData = Stdio.read_file(ITEM_LIST);
	array(string) lines = liandanData/"\r\n";
	if(lines&&sizeof(lines)){
		map_tmp = lines-({""});
	}
	else
		werror("===== [home] sorry, i did not get the File: gamelib/etc/home/map_level =====\n");
	int num = sizeof(map_tmp);
	if(num>1){
		for(int i=1;i<num;i++){
			item tmpExc = item();
			array(string) columns = map_tmp[i]/",";
			if(sizeof(columns) == 6){
				tmpExc->name_cn = columns[1];
				tmpExc->type = columns[2];
				tmpExc->zhenying = columns[3];
				tmpExc->need_name = columns[4];
				tmpExc->need_num = (int)columns[5];
				if(columns[0]!=""){
					if(exchange_item_list[columns[0]]==0){
						exchange_item_list[columns[0]]=tmpExc;
					}
				}
			}
			else 
				 werror("------size of columns wrong in load_csv() of exchange.pike------\n");
		}
	}
	else{
		werror("--------the file of gamelib/data/items_exchanged.csv is blank--\n");
	}
}

//获得物品列表
string query_equip_list(string zhenying,string type,string cmds){
	string s = "";
	//werror("--zhenying="+zhenying+"---type="+type+"---cmds="+cmds+"--\n");
	if(sizeof(exchange_item_list)){
		foreach(indices(exchange_item_list),string eachname){
			item tmp = exchange_item_list[eachname];
	//werror("--zhenying="+tmp->zhenying+"---type="+tmp->type+"---cmds="+cmds+"--\n");
			if(tmp->zhenying==zhenying&&tmp->type==type){
				s += "["+tmp->name_cn+":"+cmds+" "+tmp->type+" "+eachname+" "+tmp->need_name+" "+tmp->need_num+" 0]\n";
			}
		}
	}
	//werror("----s="+s+"----\n");
	return s;
}
