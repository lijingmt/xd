/********************************************* 游戏间货币兑换守护程序 ********************************************
1.有两个主要部分：兑换的操作，兑换总量的控制
  兑换的操作：换出和领取两方面，由数据库作为中转。换出将向数据库写入信息，领取根据数据库里的信息来获得。
  兑换总量的控制：仙道天下作为主动换出区,入的总量<=出的总量。棋牌作为被动换出区，出的总量<=入的总量

2.数据表的设计：
  数据表fee_exchange_info记录了兑换的所有信息，格式为：
  id|from_game|from_user|from_usercn|from_time|exchange_fee|to_game|to_user|fetch_status|fetch_time
    （1）id：数据id，作为主键，自增长。
    （2）from_game：换出的游戏区代号，如仙道的xd1,xdx,xdy，天下的tx1，tx2…棋牌的qp0等。
    （3）from_user：执行换出的玩家帐号。
    （4）from_usercn：执行换出的玩家昵称。
    （5）from_time：执行换出的时间，格式为mysql的标准时间格式，如：2008-07-30 11:09:20。
    （6）exchange_fee：兑换的数量，在这里所有的游戏区都是以1角等值的货币为单位写入到此项。
    （7）to_game：兑换到的游戏区。
    （8）to_user：兑换到的玩家帐号。
    （9）fetch_status：领取标识，=0表示未领取，=1表示已领取。
    （10）fetch_time：若已领取，此项记录领取的时间。

3.兑换总量控制的出入量表设计：
  class exchange_amount{
  	int in_amount; //入的量
	int out_amount; //出的量
  }
  mapping(string:exchange_amount) amount_m = ([游戏区:出入量])
  出入量信息将存储在文件gamelib/etc/fee_exchange.infos，每次加载时也会从该文件读入
  文件格式：game_id,out_amount,in_amount
****************************************************************************************************************/
#include <gamelib/include/gamelib.h>
#define EXCHANGE_INFOS ROOT "/gamelib/etc/fee_exchange.infos"
#define SAVE_TIME 3600 //回写fee_exchange.infos的时间
//#define SAVE_TIME 120 //回写fee_exchange.infos的时间
inherit LOW_DAEMON;
Sql.Sql db;
string dbSql = "mysql://root:34ccpalm@game_database:22334/pokegame_tongji";
mapping optionsMap = ([]);
object obt;

//出入量的数据结构定义
class exchange_amount{
	int out_amount; //出的量
  	int in_amount; //入的量
}
private mapping(string:exchange_amount) amount_m = ([]);
//游戏区代码与中文名的映射表
private mapping(string:string) game_id_cn = (["xd1":"仙道幻世区",
					       "xdx":"仙道傲天区",
					       "xdy":"仙道歃血区",
					       "qp0":"欢乐棋牌",
					       "tx1":"天下霸业",
					       "tx2":"九州风雷",
					       "tx5":"铁血丹心",
					       "tx7":"剑舞江湖",
					       "tx11":"天地纵横",
					       "tx14":"龙腾四海"
					      ]);
void create()
{
	//db=Sql.Sql(dbSql,optionsMap);
	obt= System.Time();
	//加载出入量信息
	load_exchange_amount_infos();
	call_out(write_back_infos,SAVE_TIME);
}

//加载出入量信息：
//1.从文件gamelib/etc/fee_exchange.infos文件中读入
void load_exchange_amount_infos()
{
	string file_data = Stdio.read_file(EXCHANGE_INFOS);
	int now = time();
	if(file_data){
		array lines = file_data/"\n";
		if(lines && sizeof(lines)){
			for(int i=0;i<sizeof(lines);i++){
				array columns = lines[i]/",";
				if(sizeof(columns)==3){
					exchange_amount tmpExchangemnt = exchange_amount();
					tmpExchangemnt->out_amount = (int)columns[1];
					tmpExchangemnt->in_amount = (int)columns[2];
					if(!amount_m[columns[0]])
						amount_m[columns[0]] = tmpExchangemnt;
				}
			}
		}
	}
	return;
}

//回写fee_exchange.infos文件
void write_back_infos(int|void fg)
{
	string write_s = "";
	foreach(sort(indices(amount_m)),string game_id){
		exchange_amount tmp_a = amount_m[game_id];
		write_s += game_id+","+tmp_a->out_amount+","+tmp_a->in_amount+"\n";
	}
	Stdio.write_file(EXCHANGE_INFOS,write_s);
	if(!fg)
		call_out(write_back_infos,SAVE_TIME);
	return;
}

//获得领取列表的接口
string query_fetch_list(string player_name)
{
	string s_rtn = "";
	string sql_s = "select id,from_game,from_usercn,exchange_fee from fee_exchange_info where to_game='"+GAME_NAME_S+"' and to_user = '"+player_name+"' and fetch_status=0";
	array(mapping(string:mixed)) result = ({});
	mixed err = catch {
		//if(!db)
		//	db=Sql.Sql(dbSql,optionsMap);
		//result = db->query(sql_s);
	};
	if(!err && sizeof(result)){
		for(int i=0;i<sizeof(result);i++){
			mapping(string:mixed) tmpInfo = result[i];
			int id = (int)tmpInfo["id"];
			int ante_fee = (int)tmpInfo["exchange_fee"];
			string from_game = tmpInfo["from_game"];
			string from_usercn = tmpInfo["from_usercn"];
			s_rtn += "["+YUSHID->query_yushi_add_fee_desc(ante_fee,1)+":fee_exchange_fetch_confirm "+id+" "+from_game+"](来自："+from_usercn+"-"+game_id_cn[from_game]+")\n";
		}
	}
	if(s_rtn == "")
		s_rtn = "暂无数据\n";
	return s_rtn;
}

//领取对换来的筹码
//返回 -1表示没有这条领取记录，0表示已经领取过，>0表示领取成功,其值是领取的筹码数
int fetch_fee(object player,int id,string from_game)
{
	string player_name = player->query_name();
	//首先判断是否id合法
	int fg = is_exchange_id_ok(player_name,id);
	if(fg == 0)
		return 0;
	else if(fg == -1)
		return -1;
	else if(fg > 0){
		int ante_fee = fg;
		//修改数据表项，完成添加玉石操作
		string fetch_time = MUD_TIMESD->get_mysql_timedesc();
		string sql_s = "update fee_exchange_info set fetch_status=1,fetch_time='"+fetch_time+"' where id="+id;
		mixed err = catch{
		//	if(!db)
		//		db=Sql.Sql(dbSql,optionsMap);
		//	db->query(sql_s);
		};
		if(err){
			return -1;
		}
		player->command("yushi_add_fee "+ante_fee+" 1");
		//出入量刷新
		if(amount_m[from_game]){
			amount_m[from_game]->in_amount += ante_fee;
		}
		else{
			exchange_amount tmpExchangemnt = exchange_amount();
			tmpExchangemnt->in_amount = ante_fee;
			tmpExchangemnt->out_amount = 0;
			amount_m[from_game] = tmpExchangemnt;
		}
		return ante_fee;
	}
	else 
		return -1;
}

//判断兑换id是否合法
int is_exchange_id_ok(string player_name,int id)
{
	int i_rtn;
	string sql_s = "select fetch_status,exchange_fee from fee_exchange_info where id = "+id+" and to_user='"+player_name+"'";
	array(mapping(string:mixed)) result = ({});
	mixed err = catch {
		//if(!db)
		//	db=Sql.Sql(dbSql,optionsMap);
		//result = db->query(sql_s);
	};
	if(!err && sizeof(result)){
		int fetch_status = (int)result[0]["fetch_status"];
		int ante_fee = (int)result[0]["exchange_fee"];
		if(fetch_status)
			i_rtn = 0;
		else
			i_rtn = ante_fee;
	}
	else
		i_rtn = -1;
	return i_rtn;
}

string query_to_game_cn(string to_game)
{
	return game_id_cn[to_game];
}

int query_out_amount(string to_game)
{
	int i_rtn;
	exchange_amount tmpExchangemnt = amount_m[to_game];
	if(tmpExchangemnt){
		i_rtn = tmpExchangemnt->in_amount - tmpExchangemnt->out_amount;
		if(i_rtn < 0)
			i_rtn = 0;
	}
	return i_rtn;
}

//向游戏区兑换调用的接口，完成将兑换信息写入数据库的操作
int exchange_to(object from_player,string to_game,string to_user,int ante_fee)
{
	int i_rtn;
	string from_user = from_player->query_name();
	string from_usercn = from_player->query_name_cn();
	string from_time = MUD_TIMESD->get_mysql_timedesc();
	string sql_s = "insert into fee_exchange_info (from_game,from_user,from_usercn,from_time,exchange_fee,to_game,to_user,fetch_status) values ('"+GAME_NAME_S+"','"+from_user+"','"+from_usercn+"','"+from_time+"',"+ante_fee+",'"+to_game+"','"+to_user+"',0)";
	mixed err = catch{
		//if(!db)
		//	db=Sql.Sql(dbSql,optionsMap);
		//db->query(sql_s);
	};
	if(err){
		return 0;
	}
	//刷新出入量
	exchange_amount tmpExchangemnt = amount_m[to_game];
	if(tmpExchangemnt){
		tmpExchangemnt->out_amount += ante_fee;
	}
	else{
		tmpExchangemnt = exchange_amount();
		tmpExchangemnt->out_amount = ante_fee;
		amount_m[to_game] = tmpExchangemnt;
	}
	return 1;
}
