//用于活动的奖励发放
//
//核心数据结构:
//1.定义了一个奖励的类 : gift_list
//
//上述结构都是通过读取ROOT/gamelib/data/gift.csv中的内容来建立的。
//
//由liaocheng于07/10/25开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define GIFT_CSV ROOT "/gamelib/data/gifts.csv" //掉落列表
#define SAVE_TIME 3600

class gift_list
{
	string user_name_cn;//玩家的中文名
	mapping(string:array(mixed)) gifts_info;//奖励的信息([gift_name:({gift_name_cn,num,have_num})])
}

private mapping(string:gift_list) gift_m = ([]); //奖励总表

void create()
{
	load_csv();
	call_out(save_gift_info,SAVE_TIME);
}

void load_csv()
{
	werror("==========  [GIFTD start!]  =========\n");
	gift_m = ([]);
	string giftData = Stdio.read_file(GIFT_CSV);
	array(string) lines = giftData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			gift_list tmpGift = gift_list();
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 6){
				string user_name = columns[0];
				tmpGift->user_name_cn = columns[1];
				string gift_name = columns[2];
				string gift_name_cn = columns[3];
				int num = (int)columns[4];//物品数量
				int have_num = (int)columns[5];//目前已被领取的数量
				if(gift_m[user_name] == 0){
					tmpGift->gifts_info = ([gift_name:({gift_name_cn,num,have_num})]);
					gift_m[user_name] = tmpGift;
				}
				else{
					gift_m[user_name]->gifts_info += ([gift_name:({gift_name_cn,num,have_num})]);
				}
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok!  =====\n");
	werror("==========  [GIFTD end!]  =========\n");
}

//每隔一段时间保存一下奖励信息
void save_gift_info(int|void fg)
{
	string now=ctime(time());
	string writeBack = "";
	if(gift_m && sizeof(gift_m)){
		foreach(sort(indices(gift_m)),string user_name){
			gift_list tmpGift = gift_m[user_name];
			string user_name_cn = tmpGift->user_name_cn;
			foreach(sort(indices(tmpGift->gifts_info)),string gift_name){
				array(mixed) tmp_arr = tmpGift->gifts_info[gift_name];
				if(sizeof(tmp_arr) == 3){
					writeBack += user_name+","+user_name_cn+","+gift_name+","+tmp_arr[0]+","+tmp_arr[1]+","+tmp_arr[2]+"\r\n";
				}
			}
		}
			
	}
	mixed err=catch
	{
		Stdio.write_file(GIFT_CSV,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/gift_err.log",now[0..sizeof(now)-2]+":rewrite gifts.csv failed\n");
	}
	if(!fg)
		call_out(save_gift_info,SAVE_TIME);
	return;
}

//获得领奖的列表，根据玩家帐号来判断是否开放[领取]链接
string query_gift_info(string user_name)
{
	string s_rtn = "";
	if(gift_m && sizeof(gift_m)){
		int i = 1;
		foreach(sort(indices(gift_m)),string player_name){
			gift_list tmp_list = gift_m[player_name];
			s_rtn += i+"."+tmp_list->user_name_cn+"：";
			foreach(sort(indices(tmp_list->gifts_info)),string gift_name){
				array(mixed) tmp_arr = tmp_list->gifts_info[gift_name];
				if(sizeof(tmp_arr) == 3){
					if(gift_name == "money"){
						int value = (int)tmp_arr[1];
						s_rtn += MUD_MONEYD->query_other_money_cn(value);
						if(tmp_arr[2] == 0 && player_name == user_name){
							s_rtn += "（[领取:gift_take money "+tmp_arr[1]+"]） ";
						}
						else if(tmp_arr[2] == tmp_arr[1] && player_name == user_name)
							s_rtn += "（已领取） ";
					}
					else{
						int can_take = (int)tmp_arr[1]-(int)tmp_arr[2];
						if(can_take < 0)
							can_take =0;
						string item_file = ITEM_PATH+gift_name;
						s_rtn += "["+tmp_arr[0]+":inv_other "+item_file+"]";
						if(player_name == user_name){
							if(can_take > 0){
								s_rtn += "x"+can_take+"（[领取:gift_take "+gift_name+" 1]） ";
							}
							else
								s_rtn += "（已领取） ";
						}
						else{
							s_rtn += "x"+tmp_arr[1]+" ";
						}
					}
				}
			}
			s_rtn += "\n";
			i++;
		}
	}
	return s_rtn;
}

//用于判断是否能够领取奖品，防止玩家刷
int if_can_take(string user_name,string gift_name)
{
	int can = 0;
	if(gift_m[user_name] && sizeof(gift_m[user_name])){
		gift_list tmpGift = gift_m[user_name];
		if(tmpGift->gifts_info[gift_name]){
			array(mixed) tmp_arr = tmpGift->gifts_info[gift_name];
			if(sizeof(tmp_arr) == 3){
				can = tmp_arr[1]-tmp_arr[2];
				if(can < 0)
					can = 0;
			}
		}
	}
	if(can >0)
		can = 1;
	return can;
}

//当玩家领取物品后将刷新信息
void flush_gift_m(string user_name,string gift_name,int num)
{
	if(gift_m[user_name] && sizeof(gift_m[user_name])){
		gift_list tmpGift = gift_m[user_name];
		if(tmpGift->gifts_info[gift_name]){
			array(mixed) tmp_arr = tmpGift->gifts_info[gift_name];
			if(sizeof(tmp_arr) == 3){
				tmp_arr[2] += num;
			}
		}
	}
}
