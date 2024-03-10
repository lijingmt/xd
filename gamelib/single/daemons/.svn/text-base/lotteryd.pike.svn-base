//物品抽奖模块
//说明：以一种抽奖的方式来获得物品奖励，模块将列出一系列等级的奖项，每个奖项都有一个幸运数字，玩家可以参与抽奖，随机获得抽奖号码，号码==幸运数字的将被视为中奖，获得奖励。每个奖项都有个数，如一等奖2名，二等奖3名。每天（0点）开放一轮抽奖，所有奖项都会刷新。
//
//抽奖模块分为了两个部分：库存管理和抽奖管理
//1.库存管理就是从gamelib/data/lottery_info.csv里面读入每个奖项的信息，核心数据结构如下：
//   奖的等级:({({奖的物品文件，物品的个数}),({...})...})
//   mapping(int:array)lottery_store=([
//					1:({({honer/49yaoyuzhanxue,1}),({teyao/qinxinlu,5}),...}),
//				        2:({...}),
//				        ...
//			             ])
//
//2.抽奖管理记录此次开放抽奖的相关信息，包括中奖号码，奖项，剩余中奖次数，核心数据结构如下：
//   class award_info = {
//                          award_level; //中奖的级别
//			    award_name; //奖品的文件名
//			    award_name_cn; //奖品的中文名
//                          award_amount; //奖品的个数
//                          luck_num; //幸运数字
//                          count_left; //剩余中奖的次数
//			    price; //抽一次奖需要的花费
//                       }   
//   mapping(int:award_info)lottery_on=([1:award_info,....]);
//   mapping(int:array)lottery_range=([1:({1000,1100,2,2}),...]);//([奖级别:({取号下限,取号上限,中奖次数,花费})])
//  lottery_range是记录了每个等级奖的抽奖范围，幸运数字从这个范围类选取，玩家获得号码也从这个范围内获得
//
//简要的逻辑过程如下：
//1.模块在被加载时，会从lottery_info.csv里读入信息，存入库存的数据结构lottery_store里
//2.然后开放的新的抽奖，从库存的每个奖级别中随机取出一个物品作为奖品，将相关信息写入到数据结构award_info里，为这个
//  奖项生成一个幸运号码
//3.所有玩家的抽奖操作都以award_info为依据进行,玩家抽奖的过程就是获得随机数，然后与幸运数字作比较，与幸运数字相等
//  则中奖，将直接获得奖品。award_info->count_left减少，为零则说明该等级的奖项已被抽完。
//4.计时器保证24小时重新开放一轮抽奖
//
//由liaocheng于08/7/22开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define LOTTERY_INFO ROOT "/gamelib/data/lottery_info.csv" //掉落列表
#define ROUND_TIME 86400 //24小时一轮
//#define ROUND_TIME 300 //测试用

class award_info
{
	int award_level;//中奖的级别
	string award_name; //奖品的文件名
	string award_name_cn; //奖品的中文名
	int award_amount; //奖品的个数
	int luck_num; //幸运数字
	int count_left; //剩余中奖的次数
	int price; //抽奖的花费
}
private mapping(int:array)lottery_store = ([]); //奖品仓库
private mapping(int:array)reward_store = ([]); //特药奖励仓库
private mapping(int:award_info)lottery_on = ([]); //抽奖信息
private mapping(int:array)lottery_range = ([]); //抽奖的数字范围([1:({取号下限，取号上限，奖次，花费})])
private mapping(int:array)luck_boys = ([]); //([抽奖等级:({中奖玩家昵称}),...])
int dead_time; //记录此次抽奖结束，即新抽奖开始的时间点

void create()
{
	load_lottery_info();
	start_lottery(1);
}

void load_lottery_info()
{
	werror("==========  [LOTTERYD start !]  ==========\n");
	string lotteryData = Stdio.read_file(LOTTERY_INFO);
	array(string) lines = lotteryData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/",";
			if(sizeof(columns) >= 7){
				int lottery_lv = (int)columns[0];
				int count_lt = (int)columns[1];
				int num_min = (int)columns[2];
				int num_max = (int)columns[3];
				string award_s = columns[4];//奖品
				int price = (int)columns[5];
				string reward_s = columns[6];//特药
				//写入lottery_store映射表
				array tmp1 = award_s/"|";
				for(int i=0;i<sizeof(tmp1);i++){
					array tmp2 = tmp1[i]/":";
					string award_nm = tmp2[0];
					int award_amnt = (int)tmp2[1];
					if(!lottery_store[lottery_lv])
					{
						lottery_store[lottery_lv] = ({({award_nm,award_amnt})});
					}
					else{
						lottery_store[lottery_lv] += ({({award_nm,award_amnt})});
					}
				}

				//写入reward_store映射表
				array tmp3 = reward_s/"|";
				for(int i=0;i<sizeof(tmp3);i++){
					array tmp4 = tmp3[i]/":";
					string reward_nm = tmp4[0];
					int reward_amnt = (int)tmp4[1];
					if(!reward_store[lottery_lv])
						reward_store[lottery_lv] = ({({reward_nm,reward_amnt})});
					else
						reward_store[lottery_lv] += ({({reward_nm,reward_amnt})});
				}
				//写入lottery_range映射表
				lottery_range[lottery_lv] = ({num_min,num_max,count_lt,price});
			}
			else
				werror("===== Error! size of columns wrong =====\n");
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
	werror("===== everything is ok! =====\n");
	werror("==========  [LOTTERYD start !]  ==========\n");
}

//开始抽奖的模块
//arg = fg  fg=1则表示是系统或者模块重新加载而开始的抽奖，那么下一次开奖的时间就是0点到这个时刻的时间
//          !fg 则表示是自然结束此轮抽奖开始新一轮抽奖，则下次开奖时间是ROUND_TIME
//开始抽奖需要完成的操作有：1.更新lottery_on的内容（奖品信息，幸运数字），2.为下一轮开始计时
void start_lottery(void|int fg)
{
	//开始新的抽奖
	lottery_on = ([]);
	luck_boys = ([]);
	foreach(sort(indices(lottery_store)),int lv){
		array awards_arr1 = lottery_store[lv];
		//获得随机的奖品
		array award_arr2 = awards_arr1[random(sizeof(awards_arr1))];
		if(sizeof(award_arr2)==2){
			//获得奖品的信息
			string award_nm = award_arr2[0]; //奖品的文件名
			int award_amnt = award_arr2[1]; //奖品的个数
			object award;
			mixed err = catch{
				award = clone(ITEM_PATH+award_nm);
			};
			if(!err && award){
				string award_nm_cn = award->query_name_cn(); //奖品的中文名
				//抽奖的次数
				array num_arr = lottery_range[lv];
				int count_max = (int)num_arr[2];
				int need_price = (int)num_arr[3];
				//此次抽奖的幸运号码
				int luck_num = get_random_num(lv);
				//写入到lottery_on映射表里
				award_info tmpAward = award_info();
				tmpAward->award_level = lv;
				tmpAward->award_name = award_nm;
				tmpAward->award_name_cn = award_nm_cn;
				tmpAward->award_amount = award_amnt;
				tmpAward->luck_num = luck_num;
				tmpAward->count_left = count_max;
				tmpAward->price = need_price;
				lottery_on[lv] = tmpAward;
			}
			else{
				string now=ctime(time());
				string err_s = "["+now[0..sizeof(now)-2]+"][start_lottery()][clone "+award_nm+"][failed]\n";
				Stdio.append_file(ROOT+"/log/lottery_err.log",err_s);
				continue;
			}
		}
	}
	//为这一轮（下一轮开始）计时
	if(fg){
		mapping(string:int) now_time = localtime(time());
		int now_mday = now_time["mday"];
		int now_mon = now_time["mon"];
		int now_year = now_time["year"];
		//得到启动后第一次开放的时间
		int next_time = mktime(59,59,19,now_mday,now_mon,now_year);
		int need_time = next_time-time();
		dead_time = next_time;
		call_out(start_lottery,need_time);
	}
	else{
		dead_time = time()+ROUND_TIME;
		call_out(start_lottery,ROUND_TIME);
	}
	return;
}

//内部接口，获得随机数
//arg = lottery_lv 根据奖项的级别来获得相应数字范围的随机数.lottery_lv=0则表示在全范围内随机
int get_random_num(int lottery_lv)
{
	int i_rtn;
	int lv_tmp = lottery_lv;
	if(!lv_tmp)
		lv_tmp = get_random_lottery_level();
	array lottery_nums = lottery_range[lv_tmp];
	if(lottery_nums && sizeof(lottery_nums)==4){
		int num_min = lottery_nums[0];
		int num_max = lottery_nums[1];
		i_rtn = num_min+random(num_max-num_min+1);
	}
	return i_rtn;
}
int get_random_lottery_level(){
	int i_rtn;
	array arr = ({});
	foreach(sort(indices(lottery_on)),int lv){
		award_info tmpAward = lottery_on[lv];
		if(tmpAward->count_left > 0){
			arr +=({lv});
		}
	}
	if(sizeof(arr)){
		i_rtn = arr[random(sizeof(arr))];
	}
	return i_rtn;
}

//查询当前抽奖情况的接口，给出不同等级奖项的列表
string query_lottery_on()
{
	string s_rtn = "";
	foreach(sort(indices(lottery_on)),int lv){
		award_info tmpAward = lottery_on[lv];
		if(tmpAward){
			string left_s = "无";
			if(tmpAward->count_left)
				left_s = "余"+tmpAward->count_left;
			s_rtn += lv+"等奖：["+tmpAward->award_name_cn+":lottery_view_detail "+lv+"]x"+tmpAward->award_amount+"("+left_s+")("+tmpAward->luck_num+")\n";
		}
	}
	if(s_rtn == "")
		s_rtn = "暂未开放\n";
	return s_rtn;
}

//查询lv级别的抽奖的具体情况，包括奖品的详细信息，目前被抽中的情况，并根据是否有剩余来判断是否提供给玩家抽奖
//arg = lv 抽奖级别
string query_lottery_award_detail(int lv)
{
	string s_rtn = "";
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		string award_nm = tmpAward->award_name;
		object award;
		mixed err = catch{
			award = clone(ITEM_PATH+award_nm);
		};
		if(!err && award){
			s_rtn += lv+"等奖："+award->query_name_cn()+"x"+tmpAward->award_amount+"\n";
			s_rtn += award->query_picture_url()+"\n";
			s_rtn += award->query_desc()+"\n";
			if(!award->is_combine_item()&&award->query_item_type()!="book") 
				s_rtn += award->query_content()+"\n";
			else
				s_rtn += "--------\n";
			s_rtn += "幸运号码："+tmpAward->luck_num+"\n";
			s_rtn += "剩余奖次："+tmpAward->count_left+"\n";
			string s_tmp = "无";
			array boys = luck_boys[lv];
			if(boys && sizeof(boys)){
				s_tmp = "";
				for(int i=0;i<sizeof(boys);i++){
					s_tmp += boys[i];
					if(i != sizeof(boys)-1)
						s_tmp += ",";
				}
			}
			s_rtn += "中奖玩家："+s_tmp+"\n";
			s_rtn += "--------\n";
			if(tmpAward->count_left)
				s_rtn += "[抽上一抽:lottery_join_in "+lv+"]("+tmpAward->price+"碎玉/次)\n";
		}
	}
	return s_rtn;
}

//查询lv级别的花费
int get_lottery_award_price(int lv)
{
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		return tmpAward->price;
	}
	else
		return -1;
}

//查询lv级别抽奖剩余的次数
int get_lottery_award_left(int lv)
{
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		return tmpAward->count_left;
	}
	else
		return 0;
}

//查询lv级别的幸运号码
int get_lottery_award_luck_num(int lv)
{
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		return tmpAward->luck_num;
	}
	else
		return 0;
}
//查询lv级别抽奖的奖品中文名
string get_lottery_award_namecn(int lv)
{
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		return tmpAward->award_name_cn;
	}
	else
		return "";
}
//查询lv级别奖品的个数
int get_lottery_award_amount(int lv)
{
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		return tmpAward->award_amount;
	}
	else
		return 0;
}
//查询lv级别抽奖奖品的文件名
string get_lottery_award_name(int lv)
{
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		return tmpAward->award_name;
	}
	else
		return "";
}

//玩家参与抽奖，获得随机数字，如果数字和幸运数字相同，则要更新相应的lottery_on和luck_boys信息
int player_get_num(object player,int lv)
{
	int i_rtn = -1;
	award_info tmpAward = lottery_on[lv];
	if(tmpAward){
		i_rtn = get_random_num(lv);
		if(i_rtn == tmpAward->luck_num){
			tmpAward->count_left--;
			string player_namecn = player->query_name_cn();
			if(!luck_boys[lv])
				luck_boys[lv] = ({player_namecn});
			else
				luck_boys[lv] += ({player_namecn});
		}
	}
	return i_rtn;
}

//获得特药奖励物品
//add by caijie 080805
object get_reward_ob(int lv)
{
	array rw = reward_store[lv];
	int i = random(sizeof(rw));
	array tmp = rw[i];
	object rw_ob;
	mixed err = catch{
		rw_ob = clone(ITEM_PATH+tmp[0]);
	};
	if(!err&&rw_ob){
		if(rw_ob->is_combine_item())
			rw_ob->amount = tmp[1];
	}
	return rw_ob;
}


//获得奖励特药的概率,一等奖 34% ，二等奖 33%，三等奖 32%，依次递减
//add by caijie 080806
int get_reward_range(int lv)
{
	int range = 0;
	switch(lv){
		case 1: range = 34;
			break;
		case 2: range = 33;
			break;
		case 3: range = 32;
			break;
		case 4: range = 31;
			break;
		case 5: range = 30;
			break;
	}
	return range;
}
