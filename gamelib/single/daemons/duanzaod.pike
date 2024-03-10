//锻造的守护程序，主要负责建立和维护游戏中锻造配方的信息表，包括矿物的锻造配方的需要原材料，锻造出的产物，锻造需要的技能熟练度等
//
//核心数据结构:
//1.锻造配方的信息:
// class duanzao; 打算采用类来记录锻造的信息 
//
// 下面这个mapping作为锻造的总表
// ([序号:锻造信息])
// mapping(int:duanzao) duanzao_m 
//
//2.锻造材料表，该表记录玩家锻造某种物品时，需要的材料:
// mapping(string:array)) get_m = 
//   (["tongkuangshi":({"铜矿石",8}),
//                     出产物名 ,需要个数
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/duanzao.csv中的内容来建立的。
//
//由liaocheng于07/5/28开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define DUANZAO_CSV ROOT "/gamelib/data/material/duanzao.csv" //矿物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
class duanzao
{
	string type; //[1]配方种类，有:d_weapon,s_weapon,m_weapon,armor
	string name_cn;//[2]锻造的物品名，如：桃木剑
	string name;//[3]锻造的物品文件名，如：weapon/1taomujian/1taomujian
	int level;//[4]锻造物的等级
	int skill_level;//[5]需要的技能熟练度
	mapping(string:array) get_m = ([]); //[6]锻造材料，如:(["material/tongduanzao":({"铜矿",5}),
	                                    //                  ...
										//                 ])
}

private mapping(int:duanzao) duanzao_m = ([]); //物品信息总表

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [DUANZAOD start!]  =========\n");
	duanzao_m = ([]);
	string duanzaoData = Stdio.read_file(DUANZAO_CSV);
	array(string) lines = duanzaoData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			duanzao tmpDuanzao = duanzao();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 7){
				tmpDuanzao->type = columns[1];
				tmpDuanzao->name_cn = columns[2];
				tmpDuanzao->name = columns[3];
				tmpDuanzao->level = (int)columns[4];
				tmpDuanzao->skill_level = (int)columns[5];
				array(string) tmpNeeds = columns[6]/"|";
				foreach(tmpNeeds,string eachneed){
					if(eachneed && sizeof(eachneed)){
						array(string) tmp = eachneed/":";
						/*
						if(sizeof(tmp)!=3)
						werror("----columns[2]="+columns[2]+"---eachneed="+eachneed+"---\n");
						*/
						int nums = (int)tmp[2];
						tmpDuanzao->get_m += ([tmp[0]:({tmp[1],nums})]);
					}
				}
				int id = (int)columns[0];
				if(duanzao_m[id] == 0)
					duanzao_m[id] = tmpDuanzao;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [DUANZAOD end!]  =========\n");
}

//获得需要采矿熟练度的接口
int query_need_level(int id)
{
	duanzao tempDuanzao = duanzao_m[id];
	if(tempDuanzao){
		return tempDuanzao->skill_level;	
	}
	else 
		return -1;
}

//获得锻造产物信息
string query_produce_info(int id)
{
	string s_rtn = "";
	duanzao temp = duanzao_m[id];
	if(temp){
		object ob = clone(ITEM_PATH+temp->name);
		if(ob){
			s_rtn += ob->query_name_cn()+"\n";
			s_rtn += ob->query_desc()+"\n";
			s_rtn += ob->query_content()+"\n";
		}
	}
	return s_rtn;
}

//获得锻造产物的文件名
string query_duanzao_item(int p_id)
{
	string s_rtn = "";
	duanzao tmp = duanzao_m[p_id];
	if(tmp){
		s_rtn = tmp->name;
	}
	return s_rtn;
}

//获得锻造物的等级
int query_item_level(int p_id)
{
	int lev = 0;	
	duanzao tmp = duanzao_m[p_id];
	if(tmp){
		lev = tmp->level;
	}
	return lev;
}

//获得已学配方的信息
string query_peifang(object player,string type)
{
	string s_rtn = "";
	player->material_m = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && ob->query_for_material() == "duanzao"){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	if(type == "m_weapon" && sizeof(player["/duanzao/m_weapon"])>0){
		foreach(indices(player["/duanzao/m_weapon"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 0 none]"; 
				int num = can_make_num(player,p_id);
				if(num>0)
					s_rtn += "("+num+")\n";
				else
					s_rtn += "\n";
			}
		}
	}
	else if(type == "s_weapon" && sizeof(player["/duanzao/s_weapon"])>0){
		foreach(indices(player["/duanzao/s_weapon"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 0 none]"; 
				int num = can_make_num(player,p_id);
				if(num>0)
					s_rtn += "("+num+")\n";
				else
					s_rtn += "\n";
			}
		}
	}
	else if(type == "d_weapon" && sizeof(player["/duanzao/d_weapon"])>0){
		foreach(indices(player["/duanzao/d_weapon"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 0 none]"; 
				int num = can_make_num(player,p_id);
				if(num>0)
					s_rtn += "("+num+")\n";
				else
					s_rtn += "\n";
			}
		}
	}
	else if(type == "armor" && sizeof(player["/duanzao/armor"])>0){
		foreach(indices(player["/duanzao/armor"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 0 none]"; 
				int num = can_make_num(player,p_id);
				if(num>0)
					s_rtn += "("+num+")\n";
				else
					s_rtn += "\n";
			}
		}
	}
	return s_rtn;
}

//获得玩家当前能锻造某个物品的个数
int can_make_num(object player,int p_id)
{
	int count = 0;
	int num2 = 0;
	duanzao tmp1 = duanzao_m[p_id];
	flush_material_m(player);
	foreach(indices(tmp1->get_m),string name){
		array tmp_arr = tmp1->get_m[name];
		int need = tmp_arr[1];
		if(need > player->material_m[name]){
			count = 0;
			break;
		}
		else{
			num2 = (int)(player->material_m[name]/need);
			if(count == 0 || count > num2)
				count = num2;
		}
	}
	return count;	
}

//获得配方材料列表，以及玩家身上以后的材料个数
string query_material_detail(object player,int p_id)
{
	string s_rtn = "";
	duanzao tmp = duanzao_m[p_id];
	if(tmp){
		foreach(indices(tmp->get_m),string name){
			array tmp_arr = tmp->get_m[name];
			string name_cn = tmp_arr[0];
			int need = tmp_arr[1];
			int now_have = player->material_m[name];
			s_rtn += name_cn+"x"+need;
			if(now_have > 0 )
				s_rtn += "("+now_have+")\n";
			else 
				s_rtn += "\n";
		}
	}
	return s_rtn;
}

//获得某个配方的具体信息
string query_pf_detail(object player,int p_id)
{	
	string s_rtn = "";
	s_rtn += query_produce_info(p_id);
	//s_rtn += "--------\n";
	s_rtn += query_material_detail(player,p_id);
	return s_rtn;
}

//获得玩家当前能锻造的物品列表
string query_can_duanzao(object player,string type)
{
	string s_rtn = "";
	player->material_m = ([]);
	player->baoshi_add = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && (ob->query_for_material() == "duanzao" || ob->query_for_material() == "baoshi")){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	if(type == "m_weapon" && sizeof(player["/duanzao/m_weapon"])>0){
		foreach(indices(player["/duanzao/m_weapon"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	else if(type == "s_weapon" && sizeof(player["/duanzao/s_weapon"])>0){
		foreach(indices(player["/duanzao/s_weapon"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	else if(type == "d_weapon" && sizeof(player["/duanzao/d_weapon"])>0){
		foreach(indices(player["/duanzao/d_weapon"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	else if(type == "armor" && sizeof(player["/duanzao/armor"])>0){
		foreach(indices(player["/duanzao/armor"]),int p_id){
			duanzao tmp = duanzao_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail duanzao "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	return s_rtn;
}

//获得出产物映射表的接口
mapping(string:array) query_get_m(int p_id)
{
	mapping(string:array) m_rtn = ([]);
	duanzao tempDuanzao = duanzao_m[p_id];
	if(tempDuanzao && sizeof(tempDuanzao->get_m)){
		m_rtn = tempDuanzao->get_m;
	}
	return m_rtn;
}

//刷新玩家拥有的锻造材料表
void flush_material_m(object player)
{
	player->material_m = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && (ob->query_for_material() == "duanzao" || ob->query_for_material() == "baoshi")){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	return;
}
