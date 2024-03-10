//熔炼的守护程序，主要负责建立和维护游戏中熔解的信息表，主要是物品与熔解产物的对应
//
//核心数据结构:
//1.下面两个mapping记录了熔炼出特殊物品的表
// mapping(string:int) ronglian_spec = ([13huojingjian:1,17duanshuijian:1,
//                                        物品  :    代码          
//                                      ....
//									  ])
//
// mapping(int:array) spec_info = ([1  :   ({ronglian_spec/shuanghuoshenjian,10}),
//                                代码               特殊物品                概率
//									....
//                                ])
//
//2.三个整数分别记录武器，防具，首饰的初始等级，物品的等级是有规律的
//  weapon 1+4n 
//  armor  2+4n
//  jewely 4+8n
//
//3.物品稀有度与熔炼属性的概率加成对应表
//  mapping(int:int) prob_add = ([稀有度:加成值])
//由liaocheng于07/6/1开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define RONGLIAN_CSV ROOT "/gamelib/data/material/ronglian.csv"
#define LEVEL_LIMIT 50

private mapping(string:array(int)) ronglian_spec = ([]);
private mapping(int:array) spec_info = ([]);
private mapping(string:array) spec_desc = ([]); //记录特殊熔炼的可视描述liaocheng于07/9/18添加
						//([spec_name:({spec_name_cn,item1_name_cn,item2_name_cn})])
private mapping(int:int) prob_add = ([3:2,4:2,5:4,6:8,7:16]);
private mapping(string:int) level_m = (["weapon":1,"armor":2,"jewelry":4]);
private int weapon = 1;
private int armor = 2;
private int jewelry = 4;

void create()
{
	load_csv();
}


void load_csv()
{
	werror("-----load ronglian.csv begain----\n");
	//ronglian.csv文件有5列
	//[0]代码，唯一标识
	//[1]物品一，如13huojingjian
	//[2]物品二, 如17duanshuijian
	//[3]特殊物品,如ronglian_spec/shuanghuoshenjian
	//[4]出特殊物品的概率
	ronglian_spec = ([]);
	spec_info = ([]);
	spec_desc = ([]);
	string ronglianData = Stdio.read_file(RONGLIAN_CSV);
	array(string) lines = ronglianData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				int id = (int)columns[0];
				if(!ronglian_spec[columns[1]])
					ronglian_spec[columns[1]] = ({id});
				else
					ronglian_spec[columns[1]] += ({id});
				if(!ronglian_spec[columns[2]])
					ronglian_spec[columns[2]] = ({id});
				else
					ronglian_spec[columns[2]] += ({id});
				int prob = (int)columns[4];
				spec_info[id] = ({columns[3],prob});
				spec_desc[columns[3]] = ({columns[5],columns[6],columns[7]});
			}
			else
				werror("------size of columns wrong in load_csv() of rongliand.pike------\n");
		}
	}
	else 
		werror("------read ronglian.csv wrong in gamelib/single/daemon/rongliand.pike------\n");
}

//获得可用于熔炼的物品列表，列表按物品type分为weapon armor jewelry
string query_can_ronglian(object player,string type,int num)
{
	string s_rtn = "";
	array all_obj = all_inventory(player);
	mapping(string:int) name_count=([]);
	mapping(int:array) tmp_m = player->ronglian_list;
	array tmp_arr1 = ({});
	array tmp_arr2 = ({});
	if(tmp_m[1])
		tmp_arr1 = tmp_m[1];
	if(tmp_m[2])
		tmp_arr2 = tmp_m[2];
	int flag ;
	foreach(all_obj,object ob){
		flag = 1;
		if(type == "weapon"){
			if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"){
				if(!ob["equiped"]){
					if(ob->query_item_rareLevel()>=3 || ob->query_item_from() != ""){
						string name = ob->query_name();
						if(sizeof(tmp_arr1)>0 && tmp_arr1[0] == name && (int)tmp_arr1[1] == name_count[name])
							flag = 0;
						if(sizeof(tmp_arr2)>0 && tmp_arr2[0] == name && (int)tmp_arr2[1] == name_count[name])
							flag = 0;
						if(flag)
							s_rtn += "["+ob->query_name_cn()+":viceskill_ronglian_add "+num+" 0 "+name+" "+name_count[name]+"]\n";
						name_count[name]++;
					}
				}
			}
		}
		else{
			if(ob->query_item_type() == type){
				if(!ob["equiped"]){
					if(ob->query_item_rareLevel()>=3 || ob->query_item_from() != ""){
						string name = ob->query_name();
						if(sizeof(tmp_arr1)>0 && tmp_arr1[0] == name && tmp_arr1[1] == name_count[name])
							flag = 0;
						if(sizeof(tmp_arr2)>0 && tmp_arr2[0] == name && tmp_arr2[1] == name_count[name])
							flag = 0;
						if(flag)
							s_rtn += "["+ob->query_name_cn()+":viceskill_ronglian_add "+num+" 0 "+name+" "+name_count[name]+"]\n";
						name_count[name]++;
					}
				}
			}
		}
	}
	return s_rtn;
}

//获得熔炼后的物品
object get_ronglian_item(object add_item1,object add_item2,int yushi_flag)
{
	string type1,type2,name1,name2;
	string get_type;
	int level1,level2,rare_level1,rare_level2;
	int get_level,get_luck;
	//首先判断是否可以出特殊物品
	name1 = add_item1->query_picture(); 
	name2 = add_item2->query_picture();
	if(name1 == "" || name2 == "")
		return 0;
	int spec_id = get_ronglian_spec_id(name1,name2);
	if(spec_id){
		if(name1 != name2){
			//有几率出特殊物品
			//int spec_id = ronglian_spec[name1];
			array tmp_a = spec_info[spec_id];
			string spec_name = tmp_a[0];
			int prob = tmp_a[1];
			switch(yushi_flag){
				case 1:
					prob +=20;
					break;
				case 2:
					prob +=30;	
					break;
				case 3:
					prob +=50;	
					break;
				case 4:
					prob +=100;
					break;
				default:
					prob +=0;
					break;
			}
			if((random(100)+1)<prob){
				//获得特殊物品啦~~
				werror("");
				object spec;
				mixed err = catch{
					spec = clone(ITEM_PATH+spec_name);
				};
				if(err || !spec)
					return 0;
				if(spec){
					werror("---- and we got it ----\n");
					return spec;
				}
			}
		}
	}
	//如果不出特殊物品，那么就按规则出相应的熔炼产物
	//1.获得产物的类别，w+w=w a+a=a j+j=j w+a=j
	type1 = add_item1->query_item_type();
	type2 = add_item2->query_item_type();
	if(type1 == "single_weapon" || type1 == "double_weapon")
		type1 = "weapon";
	if(type2 == "single_weapon" || type2 == "double_weapon")
		type2 = "weapon";
	if(type1 == type2)
		get_type = type1;
	else if(type1 != "jewelry" && type2 != "jewelry")
		get_type = "jewelry";
	else
		return 0;
	//2.获得产物的等级
	level1 = add_item1->query_item_canLevel();
	level2 = add_item2->query_item_canLevel();
	if(level1 <= level2)
		get_level = level1;
	else
		get_level = level2;
	if(get_type == "weapon"){
		for(int j=weapon;j<=LEVEL_LIMIT;j=j+4){
			if(get_level < j){
				get_level = j;
				break;
			}
		}
	}
	else if(get_type == "armor"){
		for(int j=armor;j<=LEVEL_LIMIT;j=j+4){
			if(get_level < j){
				get_level = j;
				break;
			}
		}
	}
	else if(get_type == "jewelry"){
		for(int j=jewelry;j<=LEVEL_LIMIT;j=j+8){
			if(get_level < j){
				get_level = j;
				break;
			}
		}
	}
	//3.获得幸运的加成
	if(add_item1->query_item_from() != "")
		rare_level1 = 7;
	else 
		rare_level1 = add_item1->query_item_rareLevel();
	if(add_item2->query_item_from() != "")
		rare_level2 = 7;
	else 
		rare_level2 = add_item2->query_item_rareLevel();
	get_luck = (prob_add[rare_level1]+prob_add[rare_level2])*100;
	werror("-----------get_luck = "+get_luck+"-----------\n");
	//4.最后获得物品
	object get_item = ITEMSD->get_ronglian_item(get_level,get_luck);
	if(get_item)
		return get_item;
	else 
		return 0;
}

//后台查看ronglian_spec结构的接口
string check_ronglian_spec()
{
	string s = "";
	if(ronglian_spec && sizeof(ronglian_spec)){
		foreach(indices(ronglian_spec),string item_name){
			array(int)tmp = ronglian_spec[item_name];
			s += item_name+" : ";
			for(int i=0;i<sizeof(tmp);i++)
				s += tmp[i]+", ";
			s += "\n------------\n";
		}
	}
	if(spec_info && sizeof(spec_info)){
		foreach(indices(spec_info),int id){
			s += "id="+id+", get_item="+spec_info[id][0]+", prob-"+spec_info[id][1]+"\n";
		}
	}
	return s;
}

//查看特殊熔炼信息的接口，由liaocheng于07/9/18添加
string query_spec_desc()
{
	string s_rtn = "";
	if(spec_desc && sizeof(spec_desc)){
		foreach(sort(indices(spec_desc)),string spec_name){
			if(sizeof(spec_name)){
				string spec_filename = ITEM_PATH + spec_name; 
				s_rtn += "["+spec_desc[spec_name][0]+":inv_other "+spec_filename+"]("+spec_desc[spec_name][1]+" + "+spec_desc[spec_name][2]+")\n"; 
			}
		}
	}
	return s_rtn;
}

//得到特殊熔炼的id，内部调用
int get_ronglian_spec_id(string name1,string name2)
{
	if(ronglian_spec[name1] && ronglian_spec[name2]){
		array(int) tmp = ronglian_spec[name1] & ronglian_spec[name2];
		werror("---- size of spec_id = "+sizeof(tmp)+" ----\n");
		if(sizeof(tmp)==1)
			return tmp[0];
	}
	return 0;
}
