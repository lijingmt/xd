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
// 数据库口令只允许从运行环境注入，禁止源码默认值。
string mysql_password = getenv("MYSQL_PASSWORD") || "";
string dbSql = mysql_password!="" ?
	"mysql://root:"+mysql_password+"@127.0.0.1/xd" : "";
//mapping optionsMap = (["mysql_charset_name":"gb2312"]);
mapping optionsMap = ([]);
mapping optionsMapOfFee = ([]);
object obt;
array(mapping(string:mixed)) mark_toplist = ({});
mapping allTypeDesc = ([
		"mark":"综合实力",
		"account":"财富",
		"all_fee":"捐赠",
		"home_bi":"私家小店(金钱)",
		"home_yu":"私家小店(玉石)",
		]);

array(string) all_type = ({"mark","account","all_fee","home_bi","home_yu","honerpt","lunhuipt"});
mapping(string:array(mapping(string:mixed))) all_info=([]);
private int last_database_warning;
private Thread.Mutex database_lock = Thread.Mutex();

private int ensure_database_unlocked()
{
	if(db)
		return 1;
	if(dbSql==""){
		if(time()-last_database_warning>=600){
			werror("[paihangd] MYSQL_PASSWORD is not configured\n");
			last_database_warning = time();
		}
		return 0;
	}
	mixed err = catch {
		db=Sql.Sql(dbSql,optionsMap);
	};
	if(err || !db){
		db = 0;
		if(time()-last_database_warning>=600){
			werror("[paihangd] MySQL unavailable\n");
			last_database_warning = time();
		}
		return 0;
	}
	return 1;
}

private int ensure_database()
{
	object key = database_lock->lock();
	int ready = ensure_database_unlocked();
	destruct(key);
	return ready;
}

/** Serialize one SELECT and reconnect once when MySQL dropped an idle link. */
private mapping(string:mixed) execute_database_query(string query_sql)
{
	object key = database_lock->lock();
	for(int attempt=0;attempt<2;attempt++){
		mixed rows;
		mixed query_err;
		if(!ensure_database_unlocked())
			continue;
		query_err = catch { rows = db->query(query_sql); };
		if(!query_err && arrayp(rows)){
			destruct(key);
			return (["ok":1,"rows":rows,"retried":attempt]);
		}
		// Sql.Sql objects can remain truthy after their connection has died.
		// Drop the stale handle before the single bounded reconnect attempt.
		db = 0;
	}
	destruct(key);
	return (["ok":0,"rows":({})]);
}

array(mapping(string:mixed)) test_preserve_ranking_snapshot(int query_ok,
	array(mapping(string:mixed)) current,array(mapping(string:mixed)) fresh)
{
	return query_ok ? fresh : current;
}

private array(mapping(string:mixed)) filter_toplist_for_zone(
	array(mapping(string:mixed)) source,string|void viewer_id)
{
	array(mapping(string:mixed)) result = ({});
	if(!source)
		return result;
	for(int i=0;i<sizeof(source);i++){
		string target_id = (string)(source[i]["id"] || source[i]["user_id"] || "");
		if(!viewer_id || viewer_id=="" ||
		   (target_id!="" &&
		    LOGICALZONED->can_user_interact(viewer_id,target_id)))
			result += ({source[i]});
	}
	return result;
}
protected void create()
{
	ensure_database();
	obt= System.Time();

	// 只有在 MySQL 可用时才更新排行榜
	if(db) {
		for(int i=0;i<sizeof(all_type);i++)
		{
			string type = all_type[i];
			if(type&&sizeof(type))
			{
				update_toplist(type,1);
			}
		}
	} else {
		werror("[paihangd] MySQL不可用，跳过排行榜初始化\n");
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
	

	//金钱排行
	int update_time_account = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_account = update_time_account - time();

	int update_time_home_yushi = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_home_yushi = update_time_home_yushi - time();

	int update_time_home_money = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_home_money = update_time_home_money - time();
	
	//捐赠排行
	int update_time_fee = mktime(0,59,23,now_mday,now_mon,now_year);
	int need_time_fee = update_time_fee - time();

	// 即使启动瞬间 MySQL 不可用也保留定时器；执行时会进行一次有界重连。
	call_out(update_mark_toplist,need_time_mark);
	call_out(update_account_toplist,need_time_account);
	call_out(update_home_yushi_toplist,need_time_home_yushi);
	call_out(update_home_money_toplist,need_time_home_money);

}
//外部调用接口
array(mapping(string:mixed)) query_toplist(string type,void|string viewer_id)
{
	if(type && sizeof(type))
	{
		if(all_info[type] && sizeof(all_info[type]))
			return filter_toplist_for_zone(all_info[type],viewer_id);
		else 
			return ({});
	}
	else
		return ({});
}
//更新排行信息的接口
void update_toplist(string type,int fg)
{
	if(search(all_type,type)==-1)
		return;
	mapping refreshed = load_toplist(type);
	if((int)refreshed["ok"])
		all_info[type] = (array(mapping(string:mixed)))refreshed["rows"];
	if(!fg)
		call_out(update_toplist,UPDATE_TIME,type,0);
	return;
}
//更新排行的操作
private mapping(string:mixed) load_toplist(string type)
{
	if(search(all_type,type)==-1)
		return (["ok":0,"rows":({})]);
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
	string querySql = "select distinct(id),name_cn,level,bangid,raceId,"+
		"profeId,mark,all_fee,account,home_bi,home_yu,honerpt,lunhuipt "+
		"from xd_daily_user A,(select id as bid,max(day_login_time) max_time "+
		"from xd_daily_user where day_login_time >'"+time_limit+"' group by id) B "+
		"where A.area='"+GAME_NAME_S+"' and A.day_login_time >'"+time_limit+
		"' and A.name_cn !=\"\" and A.id=B.bid and "+
		"A.day_login_time=B.max_time order by abs("+type+") desc limit "+
		TOP_NUM+";";
	mapping refreshed = execute_database_query(querySql);
	if(!(int)refreshed["ok"]){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+": query_toplist failed\n");
	}
	return refreshed;
}

array(mapping(string:mixed)) flush_toplist(string type)
{
	mapping refreshed = load_toplist(type);
	return (int)refreshed["ok"] ?
		(array(mapping(string:mixed)))refreshed["rows"] : ({});
}

//更新综合实力排行榜
void update_mark_toplist(int fg)
{
	mapping refreshed = load_mark_toplist();
	if((int)refreshed["ok"])
		mark_toplist = (array(mapping(string:mixed)))refreshed["rows"];
	if(!fg)
		call_out(update_mark_toplist,UPDATE_TIME);
	return;
}
private mapping(string:mixed) load_mark_toplist()
{
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
	
	string time_limit = now_year+"-"+mon;
	
	string querySql = "select distinct id,name_cn,level,bangid,raceId,profeId,mark from xd_daily_user where area='"+GAME_NAME_S+"' and day_login_time like '"+time_limit+"%'and name_cn != \"\" order by mark desc limit 50;";
	mapping refreshed = execute_database_query(querySql);
	if(!(int)refreshed["ok"]){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+": query_mark_toplist failed\n");
	}
	return refreshed;
}

array(mapping(string:mixed)) flush_mark_toplist()
{
	mapping refreshed = load_mark_toplist();
	return (int)refreshed["ok"] ?
		(array(mapping(string:mixed)))refreshed["rows"] : ({});
}

//更新金钱排行榜
array(mapping(string:mixed)) account_toplist = ({});
void update_account_toplist(int fg)
{
	mapping refreshed = load_account_toplist();
	if((int)refreshed["ok"])
		account_toplist = (array(mapping(string:mixed)))refreshed["rows"];
	if(!fg)
		call_out(update_account_toplist,UPDATE_TIME);
	return;
}

//金钱排行查询
private mapping(string:mixed) load_account_toplist()
{
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
	
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct id,name_cn,level,bangid,raceId,profeId,account from xd_daily_user where area='"+ GAME_NAME_S +"' and day_login_time like '"+time_limit+"%' and name_cn != \"\" order by account desc limit 50;";
	mapping refreshed = execute_database_query(querySql);
	if(!(int)refreshed["ok"]){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+": query_account_toplist failed\n");
	}
	return refreshed;
}

array(mapping(string:mixed)) flush_account_toplist()
{
	mapping refreshed = load_account_toplist();
	return (int)refreshed["ok"] ?
		(array(mapping(string:mixed)))refreshed["rows"] : ({});
}

//外部获得排行的接口
array(mapping(string:mixed)) query_mark_toplist(void|string viewer_id)
{
	if(mark_toplist && sizeof(mark_toplist))
		return filter_toplist_for_zone(mark_toplist,viewer_id);
	else 
		return ({});
}
array(mapping(string:mixed)) query_account_toplist(void|string viewer_id)
{
	if(account_toplist && sizeof(account_toplist))
		return filter_toplist_for_zone(account_toplist,viewer_id);
	else 
		return ({});
}
//更新私家小店销量（玉石）排行榜
array(mapping(string:mixed)) home_yushi_toplist = ({});
void update_home_yushi_toplist(int fg)
{
	mapping refreshed = load_home_yushi_toplist();
	if((int)refreshed["ok"])
		home_yushi_toplist = (array(mapping(string:mixed)))refreshed["rows"];
	if(!fg)
		call_out(update_home_yushi_toplist,UPDATE_TIME);
	return;
}

//私家小店销量（金币）排行查询
private mapping(string:mixed) load_home_yushi_toplist()
{
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
	
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct id,name_cn,home_yu from xd_daily_user where area='"+ GAME_NAME_S +"' and day_login_time like '"+time_limit+"%' and name_cn != \"\" order by home_yu desc limit 50;";
	mapping refreshed = execute_database_query(querySql);
	if(!(int)refreshed["ok"]){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+": query_home_yushi_toplist failed\n");
	}
	return refreshed;
}

array(mapping(string:mixed)) flush_home_yushi_toplist()
{
	mapping refreshed = load_home_yushi_toplist();
	return (int)refreshed["ok"] ?
		(array(mapping(string:mixed)))refreshed["rows"] : ({});
}
//更新私家小店销量（黄金）排行榜
array(mapping(string:mixed)) home_money_toplist = ({});
void update_home_money_toplist(int fg)
{
	mapping refreshed = load_home_money_toplist();
	if((int)refreshed["ok"])
		home_money_toplist = (array(mapping(string:mixed)))refreshed["rows"];
	if(!fg)
		call_out(update_home_money_toplist,UPDATE_TIME);
	return;
}

//私家小店销量（玉石）排行查询
private mapping(string:mixed) load_home_money_toplist()
{
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
	
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct id,name_cn,home_bi from xd_daily_user where area='"+ GAME_NAME_S +"' and day_login_time like '"+time_limit+"%' and name_cn != \"\" order by home_bi desc limit 50;";
	mapping refreshed = execute_database_query(querySql);
	if(!(int)refreshed["ok"]){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+": query_home_money_toplist failed\n");
	}
	return refreshed;
}

array(mapping(string:mixed)) flush_home_money_toplist()
{
	mapping refreshed = load_home_money_toplist();
	return (int)refreshed["ok"] ?
		(array(mapping(string:mixed)))refreshed["rows"] : ({});
}
//家园私家小店销量排行（玉石交易）的外部接口 caijie 08/11/18
array(mapping(string:mixed)) query_home_yushi_toplist(void|string viewer_id)
{
	if(home_yushi_toplist && sizeof(home_yushi_toplist))
		return filter_toplist_for_zone(home_yushi_toplist,viewer_id);
	else 
		return ({});
}
//家园私家小店销量排行（金钱交易）的外部接口 caijie 08/11/18
array(mapping(string:mixed)) query_home_money_toplist(void|string viewer_id)
{
	if(home_money_toplist && sizeof(home_money_toplist))
		return filter_toplist_for_zone(home_money_toplist,viewer_id);
	else 
		return ({});
}
//捐赠排行外部接口 evan 2009.2.2
array(mapping(string:mixed)) fee_toplist=({});
array(mapping(string:mixed)) query_fee_toplist()
{
	if(fee_toplist && sizeof(fee_toplist))
		return fee_toplist;
	else 
		return ({});
}

//更新捐赠排行榜
void update_fee_toplist(int fg)
{
	mapping refreshed = load_fee_toplist();
	if((int)refreshed["ok"])
		fee_toplist = (array(mapping(string:mixed)))refreshed["rows"];
	if(!fg)
		call_out(update_fee_toplist,UPDATE_TIME);
	return;
}
//捐赠排行查询
private mapping(string:mixed) load_fee_toplist()
{
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
	
	string time_limit = now_year+"-"+mon+"-"+day;
	string querySql = "select distinct(user_id),SUM(amount) from wap_szx where game_id = '"+ GAME_NAME_S+"' group by user_id order by SUM(amount) desc limit 100;";
	mapping refreshed = execute_database_query(querySql);
	if(!(int)refreshed["ok"]){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/paihang_err.log",now[0..sizeof(now)-2]+": query_fee_toplist failed\n");
	}
	if(!(int)refreshed["ok"] || !sizeof((array)refreshed["rows"]))
		return refreshed;
	//db操作结束
	//通过uid得到中文名,得到最后的返回值
	array(mapping(string:mixed)) result_to_return = ({});
	int j = 0;
	array result = (array)refreshed["rows"];
	for(int i=0;i<sizeof(result);i++){
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
			if(helper)
				user = helper->load_player(user_id);
		}
		if(user){
			string name_cn = user->query_name_cn();
			if(name_cn && sizeof(name_cn)){
				mapping(string:mixed) tmp=([]);
				tmp["name_cn"] = name_cn;
				result_to_return += ({tmp});
				j++;
			}
			if(j>=50)                                                                                           
				break;
		}
	}
	return (["ok":1,"rows":result_to_return]);
}

array(mapping(string:mixed)) flush_fee_toplist()
{
	mapping refreshed = load_fee_toplist();
	return (int)refreshed["ok"] ?
		(array(mapping(string:mixed)))refreshed["rows"] : ({});
}
