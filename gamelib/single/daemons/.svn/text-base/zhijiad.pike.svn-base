//制甲的守护程序，主要负责建立和维护游戏中制甲配方的信息表，包括制甲配方的需要原材料，制甲出的产物，制甲需要的技能熟练度等
//
//核心数据结构:
//1.制甲配方的信息:
// class zhijia; 打算采用类来记录制甲的信息 
//
// 下面这个mapping作为制甲的总表
// ([序号:制甲信息])
// mapping(int:zhijia) zhijia_m 
//
//2.制甲材料表，该表记录玩家制甲某种物品时，需要的材料:
// mapping(string:array)) get_m = 
//   (["tongkuangshi":({"铜矿石",8}),
//                     出产物名 ,需要个数
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/zhijia.csv中的内容来建立的。
//
//由liaocheng于07/10/22开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define ZHIJIA_CSV ROOT "/gamelib/data/material/zhijia.csv" //矿物列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
class zhijia
{
	string type; //[1]配方种类，有:head,cloth,waste,hand,thou,shoes,other 分别为头，胸，手腕，手，裤子，鞋和其他
	string name_cn;//[2]制甲的物品名，如：粗布衣
	string name;//[3]制甲的物品文件名，如：hand/2cubuyi/2cubuyi
	int level;//[4]制甲物的等级
	int skill_level;//[5]需要的技能熟练度
	mapping(string:array) get_m = ([]); //[6]制甲材料，如:(["material/zb_suibu":({"碎布",5}),
	                                    //                  ...
					    //                 ])
}

private mapping(int:zhijia) zhijia_m = ([]); //物品信息总表

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [ZHIJIAD start!]  =========\n");
	zhijia_m = ([]);
	string zhijiaData = Stdio.read_file(ZHIJIA_CSV);
	array(string) lines = zhijiaData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			zhijia tmpZhijia = zhijia();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 7){
				tmpZhijia->type = columns[1];
				tmpZhijia->name_cn = columns[2];
				tmpZhijia->name = columns[3];
				tmpZhijia->level = (int)columns[4];
				tmpZhijia->skill_level = (int)columns[5];
				array(string) tmpNeeds = columns[6]/"|";
				foreach(tmpNeeds,string eachneed){
					if(eachneed && sizeof(eachneed)){
						array(string) tmp = eachneed/":";
						if(sizeof(tmp)!=3)
						werror("----columns[6]="+columns[6]+"---eachneed="+eachneed+"---\n");
						int nums = (int)tmp[2];
						tmpZhijia->get_m += ([tmp[0]:({tmp[1],nums})]);
					}
				}
				int id = (int)columns[0];
				if(zhijia_m[id] == 0)
					zhijia_m[id] = tmpZhijia;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [CITYD end!]  =========\n");
}

//获得需要制甲熟练度的接口
int query_need_level(int id)
{
	zhijia tempZhijia = zhijia_m[id];
	if(tempZhijia){
		return tempZhijia->skill_level;	
	}
	else 
		return -1;
}

//获得制甲产物信息
string query_produce_info(int id)
{
	string s_rtn = "";
	zhijia temp = zhijia_m[id];
	if(temp){
		object ob = (object)(ITEM_PATH+temp->name);
		if(ob){
			s_rtn += ob->query_name_cn()+"\n";
			s_rtn += ob->query_desc()+"\n";
			s_rtn += ob->query_content()+"\n";
		}
	}
	return s_rtn;
}

//获得制甲产物的文件名
string query_zhijia_item(int p_id)
{
	string s_rtn = "";
	zhijia tmp = zhijia_m[p_id];
	if(tmp){
		s_rtn = tmp->name;
	}
	return s_rtn;
}

//获得制甲物的等级
int query_item_level(int p_id)
{
	int lev = 0;	
	zhijia tmp = zhijia_m[p_id];
	if(tmp){
		lev = tmp->level;
	}
	return lev;
}

//获得已学配方的信息
string query_peifang(object player,string type)
{
	string s_rtn = "";
	string can = "";
	string cannot = "";
	player->material_m = ([]);
	player->baoshi_add = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && (ob->query_for_material() == "zhijia"||ob->query_for_material() == "caifeng/zhijia")){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	if(type !="" && sizeof(player["/zhijia/"+type])>0){
		foreach(indices(player["/zhijia/"+type]),int p_id){
			zhijia tmp = zhijia_m[p_id];
			if(tmp){
				s_rtn += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 0 none]"; 
				int num = can_make_num(player,p_id);
				if(num>0)
					can += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 1 none]("+num+")\n";
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 0 none]\n";
			}
		}
	}
	s_rtn = can+cannot;
	return s_rtn;
}

//获得玩家当前能制甲某个物品的个数
int can_make_num(object player,int p_id)
{
	int count = 0;
	int num2 = 0;
	zhijia tmp1 = zhijia_m[p_id];
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
	zhijia tmp = zhijia_m[p_id];
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

//获得玩家当前能制甲的物品列表
string query_can_zhijia(object player,string type)
{
	string s_rtn = "";
	player->material_m = ([]);
	player->baoshi_add = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && (ob->query_for_material() == "zhijia" || ob->query_for_material() == "moxian")){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	if(type != "" && sizeof(player["/zhijia/"+type])>0){
		foreach(indices(player["/zhijia/"+type]),int p_id){
			zhijia tmp = zhijia_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	/*
	if(type == "head" && sizeof(player["/zhijia/head"])>0){
		foreach(indices(player["/zhijia/head"]),int p_id){
			zhijia tmp = zhijia_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	else if(type == "cloth" && sizeof(player["/zhijia/cloth"])>0){
		foreach(indices(player["/zhijia/cloth"]),int p_id){
			zhijia tmp = zhijia_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	else if(type == "waste" && sizeof(player["/zhijia/waste"])>0){
		foreach(indices(player["/zhijia/waste"]),int p_id){
			zhijia tmp = zhijia_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	else if(type == "hand" && sizeof(player["/zhijia/hand"])>0){
		foreach(indices(player["/zhijia/hand"]),int p_id){
			zhijia tmp = zhijia_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					s_rtn += "["+tmp->name_cn+":viceskill_pf_detail zhijia "+p_id+" 1 none]"; 
					s_rtn += "("+num+")\n";
				}
			}
		}
	}
	*/
	return s_rtn;
}

//获得出产物映射表的接口
mapping(string:array) query_get_m(int p_id)
{
	mapping(string:array) m_rtn = ([]);
	zhijia tempZhijia = zhijia_m[p_id];
	if(tempZhijia && sizeof(tempZhijia->get_m)){
		m_rtn = tempZhijia->get_m;
	}
	return m_rtn;
}

//刷新玩家拥有的制甲材料表
void flush_material_m(object player)
{
	player->material_m = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && (ob->query_for_material() == "zhijia" || ob->query_for_material() == "moxian")){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	return;
}
