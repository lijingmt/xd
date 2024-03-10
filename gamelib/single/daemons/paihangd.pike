//此为玩家个人排行的守护模块，完成基于金钱，综合实力的排行
//由liaocheng于07/09/03开发
//实现思路为使用统计数据库里的日登陆信息，获得排序
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

#define TIME_UNIT 600 //每10分钟统计一次在线数据
#define UPDATE_TIME 86400 //更新时间间隔为24小时
#define TOP_NUM 30 //每种排行取前30名
#define TOP_DAY 10 //取10天内的数据
//#define UPDATE_TIME 20 //更新时间间隔为40秒 测试用
Sql.Sql db;
string dbSql = "mysql://root:34ccpalm@gamelog_database:22334/xd_game_db";
//mapping optionsMap = (["mysql_charset_name":"gb2312"]);
mapping optionsMap = ([]);
mapping optionsMapOfFee = ([]);
object obt;
/*mapping allTypeDesc = ([
		"mark":"综合实力",
		"account":"财富",
		"all_fee":"捐赠",
		"home_bi":"私家小店(金钱)",
		"home_yu":"私家小店(玉石)",
		])
*/
array all_type = ({"mark","account","all_fee","home_bi","home_yu","honerpt","lunhuipt"});
mapping(string:array(mapping(string:mixed))) all_info=([]);
void create()
{
	//db=Sql.Sql(dbSql,optionsMap);
	obt= System.Time();
	/*
	for(int i=0;i<sizeof(all_type);i++)
	{
		string type = all_type[i];
		if(type&&sizeof(type))
		{
			update_toplist(type,1);
		}
	}

	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	int now_mon = now_time["mon"];
	int now_year = now_time["year"];

	//综合排行
	//得到启动后第一次自动更新排行榜的时间
	int update_time_mark = mktime(0,58,23,now_mday,now_mon,now_year);
	//由此获得距离现在还有多少时间更新
	int need_time_mark = update_time_mark - time();
	//	need_time_mark = 40; //测试用
	for(int i=0;i<sizeof(all_type);i++)
	{
		string type = all_type[i];
		if(type&&sizeof(type))
			call_out(update_toplist,need_time_mark,type,0);
	}
	*/

	//金钱排行
	/*int update_time_account = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_account = update_time_account - time();

	int update_time_home_yushi = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_home_yushi = update_time_home_yushi - time();

	int update_time_home_money = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_home_money = update_time_home_money - time();
	
	//捐赠排行
	int update_time_fee = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_fee = update_time_fee - time();
	*/
	//call_out(update_mark_toplist,need_time_mark);
	//call_out(update_account_toplist,need_time_account);
	//call_out(update_home_yushi_toplist,need_time_home_yushi);
	//call_out(update_home_money_toplist,need_time_home_money);*/
	
}
//外部调用接口
array(mapping(string:mixed)) query_toplist(string type)
{
	if(type && sizeof(type))
	{
		if(all_info[type] && sizeof(all_info[type]))
			return all_info[type];
		else 
			return ({});
	}
	else
		return ({});
}
//更新排行信息的接口
void update_toplist(string type,int fg)
{
	all_info[type] = flush_toplist(type);
	if(!fg)
		call_out(update_toplist,UPDATE_TIME,type,0);
	return;
}
//更新排行的操作
array(mapping(string:mixed)) flush_toplist(string type)
{
	array(mapping(string:mixed)) result = ({});
	mapping(string:int) limit_time = localtime(time()-3600*24*TOP_DAY);
	int limit_mday = limit_time["mday"];
	string day = limit_mday+"";
	if(limit_mday < 10)
		day = "0"+limit_mday;

	int limit_mon = limit_time["mon"]+1;
	string mon = limit_mon+"";
	if(limit_mon < 10)
		mon = "0"+limit_mon;

	int limit_year = limit_time["year"]+1900;
	

	//db=Sql.Sql(dbSql,optionsMap);
	string time_limit = limit_year+"-" + mon + "-" + day;
	string querySql = "select distinct(id),name_cn,level,bangid,raceId,profeId,mark,all_fee,lunhuipt from xd_daily_user A,(select id as bid,max(day_login_time) max_time from xd_daily_user where day_login_time >'"+time_limit+"' group by id) B where A.area='"+GAME_NAME_S+"' and A.day_login_time >'"+ time_limit +"' and A.name_cn !=\"\" and A.id=B.bid and A.day_login_time = B.max_time  order by abs("+type+") desc limit "+TOP_NUM+";";
	//werror("====== "+ querySql+" =======\n");
	mixed catchResult = catch {
		//if(!db)
		//	db=Sql.Sql(dbSql,optionsMap);
		//result = db->query(querySql);
	};
	if(catchResult)
	{
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+"："+querySql+" in query_mark_toplist wrong!\n");
		return ({});
	}
	return result;
}
/*
//更新综合实力排行榜
void update_mark_toplist(int fg)
{
	mark_toplist = flush_mark_toplist();
	if(!fg)
		call_out(update_mark_toplist,UPDATE_TIME);
	return;
}
array(mapping(string:mixed)) flush_mark_toplist()
{
	array(mapping(string:mixed)) result = ({});
	//localtime()返回的时间格式参见pike文档，需要做一些调整才能用于sql查询	
	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	string day = now_mday+"";
	if(now_mday < 10)
		day = "0"+now_mday;

	int now_mon = now_time["mon"]+1;
	string mon = now_mon+"";
	if(now_mon < 10)
		mon = "0"+now_mon;

	int now_year = now_time["year"]+1900;
	
	db=Sql.Sql(dbSql,optionsMap);
	string time_limit = now_year+"-"+mon;
	
	string querySql = "select distinct id,name_cn,level,bangid,raceId,profeId,mark from xd_daily_user where area='"+GAME_NAME_S+"' and day_login_time like '"+time_limit+"%'and name_cn != \"\" order by mark desc limit 50;";
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		result = db->query(querySql);
	};
	if(catchResult)
	{
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+"："+querySql+" in query_mark_toplist wrong!\n");
		return ({});
	}
	//db操作结束
	return result;
}

//更新金钱排行榜
void update_account_toplist(int fg)
{
	account_toplist = flush_account_toplist();
	if(!fg)
		call_out(update_account_toplist,UPDATE_TIME);
	return;
}

//金钱排行查询
array(mapping(string:mixed)) flush_account_toplist()
{
	array(mapping(string:mixed)) result = ({});

	//localtime()返回的时间格式参见pike文档，需要做一些调整才能用于sql查询	
	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	string day = now_mday+"";
	if(now_mday < 10)
		day = "0"+now_mday;
	
	int now_mon = now_time["mon"]+1;
	string mon = now_mon+"";
	if(now_mon < 10)
		mon = "0"+now_mon;
	
	int now_year = now_time["year"]+1900;
	
	db=Sql.Sql(dbSql,optionsMap);
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct id,name_cn,level,bangid,raceId,profeId,account from xd_daily_user where area='"+ GAME_NAME_S +"' and day_login_time like '"+time_limit+"%' and name_cn != \"\" order by account desc limit 50;";
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		result = db->query(querySql);
		//werror("----"+querySql+"----\n");
	};
	if(catchResult)
	{
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+"："+querySql+" in query_account_toplist wrong!\n");
		return ({});
	}
	//db操作结束
	return result;
}

//外部获得排行的接口
array(mapping(string:mixed)) query_mark_toplist()
{
	if(mark_toplist && sizeof(mark_toplist))
		return mark_toplist;
	else 
		return ({});
}
array(mapping(string:mixed)) query_account_toplist()
{
	if(account_toplist && sizeof(account_toplist))
		return account_toplist;
	else 
		return ({});
}
//更新私家小店销量（玉石）排行榜
void update_home_yushi_toplist(int fg)
{
	home_yushi_toplist = flush_home_yushi_toplist();
	if(!fg)
		call_out(update_home_yushi_toplist,UPDATE_TIME);
	return;
}

//私家小店销量（玉石）排行查询
array(mapping(string:mixed)) flush_home_yushi_toplist()
{
	array(mapping(string:mixed)) result = ({});

	//localtime()返回的时间格式参见pike文档，需要做一些调整才能用于sql查询	
	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	string day = now_mday+"";
	if(now_mday < 10)
		day = "0"+now_mday;
	
	int now_mon = now_time["mon"]+1;
	string mon = now_mon+"";
	if(now_mon < 10)
		mon = "0"+now_mon;
	
	int now_year = now_time["year"]+1900;
	
	db=Sql.Sql(dbSql,optionsMap);
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct id,name_cn,home_yu from xd_daily_user where area='"+ GAME_NAME_S +"' and day_login_time like '"+time_limit+"%' and name_cn != \"\" order by home_yu desc limit 50;";
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		result = db->query(querySql);
		//werror("----"+querySql+"----\n");
	};
	if(catchResult)
	{
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+"："+querySql+" in query_home_yushi_toplist wrong!\n");
		return ({});
	}
	//db操作结束
	return result;
}
//更新私家小店销量（黄金）排行榜
void update_home_money_toplist(int fg)
{
	home_money_toplist = flush_home_money_toplist();
	if(!fg)
		call_out(update_home_money_toplist,UPDATE_TIME);
	return;
}

//私家小店销量（玉石）排行查询
array(mapping(string:mixed)) flush_home_money_toplist()
{
	array(mapping(string:mixed)) result = ({});

	//localtime()返回的时间格式参见pike文档，需要做一些调整才能用于sql查询	
	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	string day = now_mday+"";
	if(now_mday < 10)
		day = "0"+now_mday;
	
	int now_mon = now_time["mon"]+1;
	string mon = now_mon+"";
	if(now_mon < 10)
		mon = "0"+now_mon;
	
	int now_year = now_time["year"]+1900;
	
	db=Sql.Sql(dbSql,optionsMap);
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct id,name_cn,home_yu from xd_daily_user where area='"+ GAME_NAME_S +"' and day_login_time like '"+time_limit+"%' and name_cn != \"\" order by home_bi desc limit 50;";
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		result = db->query(querySql);
		//werror("----"+querySql+"----\n");
	};
	if(catchResult)
	{
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+"："+querySql+" in query_home_yushi_toplist wrong!\n");
		return ({});
	}
	//db操作结束
	return result;
}
//家园私家小店销量排行（玉石交易）的外部接口 caijie 08/11/18
array(mapping(string:mixed)) query_home_yushi_toplist()
{
	if(home_yushi_toplist && sizeof(home_yushi_toplist))
		return home_yushi_toplist;
	else 
		return ({});
}
//家园私家小店销量排行（金钱交易）的外部接口 caijie 08/11/18
array(mapping(string:mixed)) query_home_money_toplist()
{
	if(home_money_toplist && sizeof(home_money_toplist))
		return home_money_toplist;
	else 
		return ({});
}
//捐赠排行外部接口 evan 2009.2.2
array(mapping(string:mixed)) query_fee_toplist()
{
	werror("============i am here =========\n");
	werror("========= sizeof(fee_toplist) = "+sizeof(fee_toplist)+" =========\n");
	if(fee_toplist && sizeof(fee_toplist))
		return fee_toplist;
	else 
		return ({});
}

更新捐赠排行榜
void update_fee_toplist(int fg)
{
	fee_toplist = flush_fee_toplist();
	if(!fg)
		call_out(update_fee_toplist,UPDATE_TIME);
	return;
}
捐赠排行查询
array(mapping(string:mixed)) flush_fee_toplist()
{
	werror("============i am in =========\n");
	array(mapping(string:mixed)) result = ({});

	mapping(string:int) now_time = localtime(time());
	int now_mday = now_time["mday"];
	string day = now_mday+"";
	if(now_mday < 10)
		day = "0"+now_mday;
	
	int now_mon = now_time["mon"]+1;
	string mon = now_mon+"";
	if(now_mon < 10)
		mon = "0"+now_mon;
	
	int now_year = now_time["year"]+1900;
	
	db = Sql.Sql(dbSql,optionsMap);
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct(user_id),SUM(amount) from wap_szx where game_id = '"+ GAME_NAME_S+"' group by user_id order by SUM(amount) desc limit 100;";
	werror("============ querySql = "+querySql+" =========\n");
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		result = db->query(querySql);
		//werror("----"+querySql+"----\n");
	};
	if(catchResult)
	{
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+"："+querySql+" in query_home_yushi_toplist wrong!\n");
		return ({});
	}
	werror("=========== sizeof(result) = "+ sizeof(result)+" =========\n");
	werror("=========== result[0][user_id] = "+ result[0]["user_id"]+" =========\n");
	//db操作结束
	//通过uid得到中文名,得到最后的返回值
	array(mapping(string:mixed)) result_to_return = ({});
	int j = 0;
	for(int i=0;i<sizeof(result);i++){
		werror("===== rururirurururu ======\n");
		string user_id = result[i]["user_id"];
		object user = find_player(user_id);
		if(!user){ //如果当前要操作的玩家不在线，则加载                                                                     
			array list=users(1);
			object helper; //随机找个在线的玩家，以调用load_player()来加载需要操作的玩家
			for(int j=0;j<sizeof(list);j++){
				helper = list[j];
				if(helper)
					break;
			}
			user = helper->load_player(user_id);
		}
		if(user){
			string name_cn = user->query_name_cn();
			werror("===== name_cn = "+ name_cn +"========\n");
			if(name_cn && sizeof(name_cn)){
				werror("===== i am in ini in ini nin========\n");
				mapping(string:mixed) tmp=([]);
				tmp["name_cn"] = name_cn;
				werror("=====tmp[name_cn] = "+ tmp["name_cn"] +" ======\n");
				result_to_return += ({tmp});
				j++;
			}
			if(j>=50)                                                                                           
				break;
		}
	}
	werror("=========== sizeof(result_to_return) = "+ sizeof(result_to_return)+" =========\n");
	werror("=========== result_to_return[0][name_cn] = "+ result_to_return[0]["name_cn"]+" =========\n");
	return result_to_return;
}
*/
/*
array(mapping(string:mixed)) query_toplist(string type)
{
	if(type&&sizeof(type))
	{
		switch(type){
			case "qi":
				return;
			break;
			case "chongzhi":
				return ;
			break;
			case "caifu":
				return ;
			break;
			case "lunhui":
				return ;
			break;
			case "zhonghe":
				return ;
			break;
			case "bangzhan":
				return ;
			break;
			default:
			return ([]);
		}
	}
	else
		return ([]);

}
*/
