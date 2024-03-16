//炼丹的守护程序，主要负责建立和维护游戏中炼丹配方的信息表，包括矿物的炼丹配方的需要原材料，炼丹出的产物，炼丹需要的技能熟练度等
//
//核心数据结构:
//1.炼丹配方的信息:
// class liandan; 打算采用类来记录炼丹的信息 
//
// 下面这个mapping作为炼丹的总表
// ([序号:炼丹信息])
// mapping(int:liandan) liandan_m 
//
//2.炼丹材料表，该表记录玩家炼丹某种物品时，需要的材料:
// mapping(string:array)) get_m = 
//   (["muhudie":({"木蝴蝶",8}),
//              材料中文名 ,需要个数
//      ...
//   ])
//
//上述结构都是通过读取ROOT/gamelib/data/material/liandan.csv中的内容来建立的。
//
//由liaocheng于07/5/28开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define LIANDAN_CSV ROOT "/gamelib/data/material/liandan.csv" //炼丹列表
#define MATERIAL_PATH ROOT "/gamelib/clone/item/material/" //所有这类物品文件都放在此目录下
#define TIME_DELAY 1800 //药效持续时间

class liandan
{
	string type; //[1]配方种类，有:
	string name_cn;//[2]炼丹的物品名，如：小环丹
	string name;//[3]炼丹的物品文件名，如：liandan/xxxx
	int level;//[4]炼丹物的等级
	int skill_level;//[5]需要的技能熟练度
	mapping(string:array) get_m = ([]); //[6]炼丹材料，如:(["material/muhudie":({"木蝴蝶",5}),
	                                    //                  ...
										//                 ])
}

private mapping(int:liandan) liandan_m = ([]); //物品信息总表

//在丹药效果持续时间上，我打算用call_out,remove_call_out来控制，下面的mapping记录了各类药食用后调用call_out返回的id
private mapping(string:int) call_out_id = ([]);

void create()
{
	load_csv();
}


void load_csv()
{
	werror("==========  [LIANDAND start!]  =========\n");
	liandan_m = ([]);
	string liandanData = Stdio.read_file(LIANDAN_CSV);
	array(string) lines = liandanData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			liandan tmpLiandan = liandan();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 7){
				tmpLiandan->type = columns[1];
				tmpLiandan->name_cn = columns[2];
				//werror("------liandan of "+columns[2]+"is ok-------\n");
				tmpLiandan->name = columns[3];
				tmpLiandan->level = (int)columns[4];
				tmpLiandan->skill_level = (int)columns[5];
				array(string) tmpNeeds = columns[6]/"|";
				foreach(tmpNeeds,string eachneed){
					if(eachneed && sizeof(eachneed)){
						array(string) tmp = eachneed/":";
						/*
						if(sizeof(tmp)!=3)
						werror("----columns[6]="+columns[6]+"---eachneed="+eachneed+"---\n");
						else{
						*/
						int nums = (int)tmp[2];
						tmpLiandan->get_m += ([tmp[0]:({tmp[1],nums})]);
						//}
					}
				}
				int id = (int)columns[0];
				if(liandan_m[id] == 0)
					liandan_m[id] = tmpLiandan;
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [LIANDAND end!]  =========\n");
}

//获得需要炼丹熟练度的接口
int query_need_level(int id)
{
	liandan tempLiandan = liandan_m[id];
	if(tempLiandan){
		return tempLiandan->skill_level;	
	}
	else 
		return -1;
}

//获得炼丹产物信息
string query_produce_info(int id)
{
	string s_rtn = "";
	liandan temp = liandan_m[id];
	if(temp){
		object ob = clone(ITEM_PATH+temp->name);
		if(ob){
			s_rtn += ob->query_name_cn()+"\n";
			s_rtn += ob->query_desc()+"\n";
			//s_rtn += ob->query_content()+"\n";
		}
	}
	return s_rtn;
}

//获得炼丹产物的文件名
string query_liandan_item(int p_id)
{
	string s_rtn = "";
	liandan tmp = liandan_m[p_id];
	if(tmp){
		s_rtn = tmp->name;
	}
	return s_rtn;
}

//获得炼丹物的等级
int query_item_level(int p_id)
{
	int lev = 0;	
	liandan tmp = liandan_m[p_id];
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
	int flag = 0;
	player->material_m = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && ob->query_for_material() == "liandan"){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	if(type == "attri_base" && sizeof(player["/liandan/attri_base"])>0){
		foreach(indices(player["/liandan/attri_base"]),int p_id){
			liandan tmp = liandan_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					can += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 1 none]("+num+")\n";
				}
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 0 none]\n"; 
			}
		}
	}
	else if(type == "attri_vice" && sizeof(player["/liandan/attri_vice"])>0){
		foreach(indices(player["/liandan/attri_vice"]),int p_id){
			liandan tmp = liandan_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					can += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 1 none]("+num+")\n";
				}
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 0 none]\n"; 
			}
		}
	}
	else if(type == "attri_defend" && sizeof(player["/liandan/attri_defend"])>0){
		foreach(indices(player["/liandan/attri_defend"]),int p_id){
			liandan tmp = liandan_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					can += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 1 none]("+num+")\n";
				}
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 0 none]\n"; 
			}
		}
	}
	else if(type == "attri_attack" && sizeof(player["/liandan/attri_attack"])>0){
		foreach(indices(player["/liandan/attri_attack"]),int p_id){
			liandan tmp = liandan_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					can += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 1 none]("+num+")\n";
				}
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 0 none]\n"; 
			}
		}
	}
	else if(type == "spec" && sizeof(player["/liandan/spec"])>0){
		foreach(indices(player["/liandan/spec"]),int p_id){
			liandan tmp = liandan_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					can += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 1 none]("+num+")\n";
				}
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 0 none]\n"; 
			}
		}
	}
	else if(type == "normal" && sizeof(player["/liandan/normal"])>0){
		foreach(indices(player["/liandan/normal"]),int p_id){
			liandan tmp = liandan_m[p_id];
			if(tmp){
				int num = can_make_num(player,p_id);
				if(num>0){
					can += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 1 none]("+num+")\n";
				}
				else
					cannot += "["+tmp->name_cn+":viceskill_pf_detail liandan "+p_id+" 0 none]\n"; 
			}
		}
	}
	s_rtn = can+cannot;
	return s_rtn;
}

//获得玩家当前能炼丹某个物品的个数
int can_make_num(object player,int p_id)
{
	int count = 0;
	int num2 = 0;
	liandan tmp1 = liandan_m[p_id];
	flush_material_m(player);
	foreach(indices(tmp1->get_m),string name){
		array tmp_arr = tmp1->get_m[name];
		int need = tmp_arr[1];
		if(need>0 && need > player->material_m[name]){
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
	liandan tmp = liandan_m[p_id];
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

//食用丹药时被调用，主要是相关丹药持续时间的操作
int eat_danyao(object player,object yao)
{
	string kind = yao->query_danyao_kind(); //丹药大类，如attri_base ...等
	string type = yao->query_danyao_type(); //丹药效果类型，如str
	string effect_value = yao->query_effect_value(); //丹药效果值
	string name_cn = yao->query_name_cn();
	string name = yao->query_name();
	int timedelay = yao->query_danyao_timedelay();
	int start_time = time();
	if(kind == "spec"){
		if(type == "hind")
			player->hind = 1;
		else if(type == "sucide"){
			player->sucide = 1;
			player->set_life(0);
			return 1;
		}
	}
	//特殊药品食用，由liaocheng于07/11/21添加
	else if(kind == "te_exp" || kind == "te_honer" || kind == "te_luck" || kind == "te_attack" || kind == "te_vice" || kind == "te_defend" || kind == "te_base"){
		string path = file_name(yao);  
		array(string) dir = path/"/";
		//werror("========dir[8]="+dir[8]+"====\n");
		if(timedelay==0){
			//player->type += effect_value;
			player->set_base_add(type,effect_value);
			return 1;
		}
		if(dir[8]!="zhongqiuyuebing"){
			if(!player["/plus/daily/teyao_map"])
				player["/plus/daily/teyao_map"] = ([]);                                 
			if(!player["/plus/daily/teyao_map"][kind])                                      
				player["/plus/daily/teyao_map"][kind] = 1;

			else if(player["/plus/daily/teyao_map"][kind]>=player->query_max_yao()) //各个vip等级不同的最大上限                              
				return 2;//超出食用次数限制                                             
			else                                                                            
			player["/plus/daily/teyao_map"][kind]++;           
		}
		player->set_buff(kind,0,type);                                                  
		player->set_buff(kind,1,effect_value);                                          
		player->set_buff(kind,2,timedelay/60);//由于char.pike中是以1min为一心跳          
		player["/teyao/"+kind] = ({type,effect_value,timedelay/60,name_cn});            
		return 1;                                                                       
	}
	player->set_buff(kind,0,type);
	player->set_buff(kind,1,effect_value);
	player->set_buff(kind,2,timedelay/60);//由于char.pike中是以30s为一心跳
	player["/danyao/"+kind] = name_cn;
	return 1;
}

//获得出产物映射表的接口
mapping(string:array) query_get_m(int p_id)
{
	mapping(string:array) m_rtn = ([]);
	liandan tempLiandan = liandan_m[p_id];
	if(tempLiandan && sizeof(tempLiandan->get_m)){
		m_rtn = tempLiandan->get_m;
	}
	return m_rtn;
}


//刷新玩家拥有的炼丹材料表
void flush_material_m(object player)
{
	player->material_m = ([]);
	array(object) all_obj = all_inventory(player);
	//得到玩家身上材料个数的映射表
	foreach(all_obj,object ob){
		if(ob->is_combine_item() && ob->query_for_material() == "liandan"){
			if(player->material_m[ob->query_name()] == 0)
				player->material_m[ob->query_name()] = ob->amount;
			else
				player->material_m[ob->query_name()] += ob->amount;
		}
	}
	return;
}
