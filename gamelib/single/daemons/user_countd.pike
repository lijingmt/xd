#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

#define TIME_UNIT 600 //每10分钟统计一次在线数据
Sql.Sql db;
string dbSql = "mysql://root:password@gamelog_database:22334/xd_game_db";//这个db里记录是5,6区的日登录数据

Sql.Sql db2;
string dbSql2 = "mysql://root:password@gamelog_database:22334/gamelog";

//mapping optionsMap = (["mysql_charset_name":"gb2312"]);
mapping optionsMap = ([]);
object obt;

void create()
{
	//db=Sql.Sql(dbSql,optionsMap);
	obt= System.Time();
	//db2=Sql.Sql(dbSql2,optionsMap);
}

//用户每天登录的记录，只记录一次
void entry_record(object me)
{
	//每天只记录一次登录记录,用来存储日独立用户
	//本日登陆时间|游戏区|ID|中文名|密码|推广key值|性别|阵营|职业|头像|金钱|级别|当前经验|帮派id|当前力量|当前智力|当前敏捷|生命上限|法力上限|技能|是否会特殊技能|副业技能|荣誉等级|杀敌数|当前荣誉值|第一次登录时间|总在线时间|设置的复活点|上线位置|仓库等级|sid

	//day_login_time|area|id|name_cn|pswd|m_key|sex|raceId|profeId|user_pic|account|level|current_exp|bangid|str|think|dex|life_max|mofa_max|skills|can_spec|vice_skills|honerlv|killcount|honerpt|first_login|online_time|relife|last_pos|packageLevel|sid

	string day_login_time = MUD_TIMESD->get_mysql_timedesc();
	string area = GAME_NAME_S;//xdX
	string id = me->query_name();
	string name_cn = me->query_name_cn();
	string pswd = me->password;
	string m_key = me->user_mkey;
	string sex = me->sex;
	string raceId = me->query_raceId();
	string profeId = me->query_profeId();
	string user_pic = me->user_pic;
	int account = me->query_account();
	int level = me->query_level();
	int current_exp = me->current_exp;
	int bangid = me->bangid;
	int str = me->query_str();
	int think = me->query_think();
	int dex = me->query_dex();
	int life_max = me->query_life_max();
	int mofa_max = me->query_mofa_max();
	int attack_power = me->query_high_attack_desc();//用于综合实力计算
	int defend_power = me->query_defend_power();//用于综合实力计算
	int dodge = me->query_phy_dodge();//用于综合实力计算
	int baoji = me->query_phy_baoji();//用于综合实力计算
	int hitte = me->query_phy_hitte();//用于综合实力计算
	int home_yu = me->home_yushi;//私家小店销量（玉石交易）
	//werror("----home_yu="+home_yu+"---\n");
	int home_bi = me->home_money;//私家小店销量(金币交易)
	//算出综合实力值,用于个人排行榜
	//由liaocheng于07/09/03添加
	int mark = 100*level+attack_power*5+defend_power+life_max+mofa_max+dex*10+str*10+think*25+dodge*60+hitte+baoji*60;
	string skills = "";
	foreach(indices(me->skills),string skill_name){
		if(skill_name && sizeof(me->skills[skill_name])){
			skills += skill_name+":"+me->skills[skill_name][0]+",";
		}
	}
	int can_spec = me->can_spec;
	string vice_skills = "";
	foreach(indices(me->vice_skills),string skill_name){
		if(skill_name && sizeof(me->vice_skills[skill_name])){
			vice_skills += skill_name+":"+me->vice_skills[skill_name][0]+",";
		}
	}
	int honerlv = me->honerlv;
	int killcount = me->killcount;
	int honerpt = me->honerpt;
	int first_login = me->first_login;
	int online_time = me->online_time;
	string relife = me->relife;
	string last_pos = me->last_pos;
	int packageLevel = me->packageLevel;
	string sid = me->sid;
	//string mobile = me->regmail;
	string intodbs = "";
	int all_fee = me->all_fee;//玩家捐赠的总记录
	float lunhuipt = me->lunhuipt;//玩家轮回值
	intodbs += day_login_time+"|";
	intodbs += area+"|";
	intodbs += id+"|";
	intodbs += name_cn+"|";
	intodbs += pswd+"|";
	intodbs += m_key+"|";
	intodbs += sex+"|";
	intodbs += raceId+"|";
	intodbs += profeId+"|";
	intodbs += user_pic+"|";
	intodbs += account+"|";
	intodbs += level+"|";
	intodbs += current_exp+"|";
	intodbs += bangid+"|";
	intodbs += str+"|";
	intodbs += think+"|";
	intodbs += dex+"|";
	intodbs += life_max+"|";
	intodbs += mofa_max+"|";
	intodbs += skills+"|";
	intodbs += can_spec+"|";
	intodbs += vice_skills+"|";
	intodbs += honerlv+"|";
	intodbs += killcount+"|";
	intodbs += honerpt+"|";
	intodbs += first_login+"|";
	intodbs += online_time+"|";
	intodbs += relife+"|";
	intodbs += last_pos+"|";
	intodbs += packageLevel+"|";
	intodbs += sid+"|";
	intodbs += mark+"|";
	intodbs += home_yu+"|";
	intodbs += home_bi+"|";
	intodbs += all_fee+"|";
	intodbs += lunhuipt+"|";
	//db 操作
	int st =  obt->usec_full;
	mixed catchResult = catch {
		   string querySql = "";
		   //if(!db)
		   //db=Sql.Sql(dbSql,optionsMap);
		   querySql = "insert xd_daily_user (day_login_time,area,id,name_cn,pswd,m_key,sex,raceId,profeId,user_pic,account,level,current_exp,bangid,str,think,dex,life_max,mofa_max,skills,can_spec,vice_skills,honerlv,killcount,honerpt,first_login,online_time,relife,last_pos,packageLevel,sid,mark,home_yu,home_bi,all_fee,lunhuipt) values ('"+day_login_time+"','"+area+"','"+id+"','"+name_cn+"','"+pswd+"','"+m_key+"','"+sex+"','"+raceId+"','"+profeId+"','"+user_pic+"',"+account+","+level+","+current_exp+","+bangid+","+str+","+think+","+dex+","+life_max+","+mofa_max+",'"+skills+"',"+can_spec+",'"+vice_skills+"',"+honerlv+","+killcount+","+honerpt+","+first_login+","+online_time+",'"+relife+"','"+last_pos+"',"+packageLevel+",'"+sid+"',"+mark+","+home_yu+","+home_bi+","+all_fee+","+lunhuipt+")";
		   //db->query(querySql);
		/*
		string querySql = "";
		querySql = "insert xd_daily_user (day_login_time,area,id,name_cn,pswd,m_key,sex,raceId,profeId,user_pic,account,level,current_exp,bangid,str,think,dex,life_max,mofa_max,skills,can_spec,vice_skills,honerlv,killcount,honerpt,first_login,online_time,relife,last_pos,packageLevel,sid) values ('"+day_login_time+"','"+area+"','"+id+"','"+name_cn+"','"+pswd+"','"+m_key+"','"+sex+"','"+raceId+"','"+profeId+"','"+user_pic+"',"+account+","+level+","+current_exp+","+bangid+","+str+","+think+","+dex+","+life_max+","+mofa_max+",'"+skills+"',"+can_spec+",'"+vice_skills+"',"+honerlv+","+killcount+","+honerpt+","+first_login+","+online_time+",'"+relife+"','"+last_pos+"',"+packageLevel+",'"+sid+"')";
		Stdio.append_file(ROOT+"/db_log/daily_user/"+MUD_TIMESD->get_year_month_day(),querySql+"\n");
		*/
		   string c_log = "";//统计使用的日志 evan added 2008.07.16
		   c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+area+"]["+ id +"]["+sid+"]["+m_key+"]\n";
		   if(c_log != ""){
			   Stdio.append_file(ROOT+"/log/stat/daily/"+area+"_daily_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		   }
		   Stdio.append_file(ROOT+"/db_log/daily_user/"+MUD_TIMESD->get_year_month_day(),querySql+";\n");
	};
	if(catchResult)
	{
		Stdio.append_file(ROOT+"/db_log/daily_user/"+MUD_TIMESD->get_year_month_day(),intodbs+"|"+(obt->usec_full-st)/1000+"ms insert wrong!\n");
	}
	//db操作结束
}

//新用户注册记录
void reg_new(object me)
{
	string guest = "";
	string day_login_time = MUD_TIMESD->get_mysql_timedesc();
	string user_reg_time = me->user_reg_time;
	string id = me->query_name();
	string pswd = me->password;
	string area = GAME_NAME_S;
	string raceId = me->query_raceId();
	string profeId = me->query_profeId();
	string sid = me->sid;//购买者SID
	if(sid=="5dwap")
		guest="yk";
	string m_key = me->user_mkey;//购买者推广渠道的m_key
	string m_mid = "";//购买者推广渠道的m_key
	string mobile = "";//购买者手机号
	string intodbs = "";
	intodbs += day_login_time+"|";
	intodbs += user_reg_time+"|";
	intodbs += id+"|";
	intodbs += pswd+"|";
	intodbs += area+"|";
	intodbs += raceId+"|";
	intodbs += profeId+"|";
	intodbs += sid+"|";
	intodbs += m_key+"|";
	intodbs += mobile;
	//db 操作
	int st =  obt->usec_full;
	mixed catchResult = catch {
		/*
		   string querySql = "";
		   if(!db2)
		   db2=Sql.Sql(dbSql2,optionsMap);
		   querySql = "insert into spread_infos(m_key,mid,game_id,user_id,log_time,ap_info) values ('"+m_key+"','"+m_mid+"','"+area+"','"+id+"','"+day_login_time+"','"+guest+"')";
		   db2->query(querySql);
		 */
		string querySql = "";
		string c_log = "";//统计使用的日志 evan added 2008.07.10
		querySql = "insert into xd_reg_info (m_key,mid,game_id,user_id,log_time,ap_info) values ('"+m_key+"','"+m_mid+"','"+area+"','"+id+"','"+day_login_time+"','"+guest+"');";
		//c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+area+"]["+ id +"]["+m_key+"]\n";
		Stdio.append_file(ROOT+"/db_log/reg_new/"+MUD_TIMESD->get_year_month_day(),querySql+"\n");
		//if(c_log != ""){
		//	Stdio.append_file(ROOT+"/log/stat/reg/"+area+"_reg_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		//}
	};
	if(catchResult)
	{
		Stdio.append_file(ROOT+"/db_log/reg_new/"+MUD_TIMESD->get_year_month_day(),intodbs+"|"+(obt->usec_full-st)/1000+"ms insert wrong!\n");
	}
	//db操作结束
}
