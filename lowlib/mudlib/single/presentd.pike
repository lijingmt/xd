//人推人系统的守护模块，用于维护人推人数据库信息，以及提供所有人推人功能的接口
//人推人系统的数据表结构如下：
// 新玩家id  |  新玩家姓名  |  推荐人id  |  推荐人姓名  |  上次总积分|  当前总积分
// user_id   |  user_name   |presenter_id|presenter_name| last_mark  |   all_mark
#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;

#define log_err_file ROOT "/log/presenter_err.log" 
#define log_file ROOT "/log/presenter.log" 
Sql.Sql db;
string dbSql = "mysql://root:password@game_database:22334/"+DATABASE_NAME;
//mapping optionsMap = (["mysql_charset_name":"gb2312"]);
mapping optionsMap = ([]);
object obt;

void create()
{
	//库表没有，这里先不开放
	//db=Sql.Sql(dbSql,optionsMap);
	obt= System.Time();
}

//新用户填写推荐人的接口
int set_my_presenter(string myname,string mynamecn,int mymark,string p_name,string p_namecn)
{
	string now=ctime(time());
	array(mapping(string:mixed)) rtn = ({});
	string querySql = "select * from presenter_info where user_id='"+myname+"'";
	mixed err = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		rtn = db->query(querySql);
	};
	if(err){
		Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in set_my_presenter  wrong\n");
		return 0;
	}
	if(sizeof(rtn)>0)
		return 0;
	else{
		querySql = "insert into presenter_info (user_id,user_name,presenter_id,presenter_name,last_mark,all_mark) values ('"+myname+"','"+mynamecn+"','"+p_name+"','"+p_namecn+"',0,"+mymark+")";
		err = catch{
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
		};
		if(err){
			Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in set_my_presenter  wrong\n");
			return 0;
		}
		Stdio.append_file(log_file,now[0..sizeof(now)-2]+":"+p_namecn+"("+p_name+")，"+mynamecn+"("+myname+")将其设为推荐人\n--------\n");
		return 1;
	}
}

//刷新玩家在数据库中的总积分的接口
void flush_all_mark(string name,int all_mark)
{
	string now=ctime(time());
	array(mapping(string:mixed)) rtn = ({});
	/*
	string querySql = "select * from presenter_info where user_id='"+name+"'";
	mixed err = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		rtn = db->query(querySql);
	};
	if(err){
		Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in set_my_presenter  wrong\n");
		return;
	}
	if(rtn == 0 || rtn == ({}))
		return;
	else{}*/
	string querySql = "update presenter_info set all_mark="+all_mark+" where user_id='"+name+"'";
	mixed err = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		db->query(querySql);
	};
	if(err){
		Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in flush_all_mark wrong\n");
		return;
	}
	return;
}

//获得我所推荐人的列表
string query_my_men(object me)
{
	string now=ctime(time());
	string rtn_s = "";
	string name = me->query_name();
	string querySql = "select user_id,user_name from presenter_info where presenter_id='"+name+"'";
	array(mapping(string:mixed)) rlt = ({});
	mixed err = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		rlt = db->query(querySql);
	};
	if(err){
		Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in query_my_men wrong\n");
		return "";
	}
	if(sizeof(rlt) > 0){
		for(int i=0;i<sizeof(rlt);i++){
			if(rlt[i]["user_id"] != "" && rlt[i]["user_name"] != ""){
				rtn_s += "["+rlt[i]["user_name"]+":present_view "+rlt[i]["user_id"]+"]";
				if((i+1)%2 == 0)
					rtn_s += "\n";
				else
					rtn_s += " ";
			}
		}
	}
	return rtn_s;
}

//玩家每升5级，对推荐者进行一次积分加成,这是主要接口之一
//加成有两部分，一是等级的积分加成，二是该玩家积分的分成
void flush_mark(object user)
{
	int mark_add = 0;
	int all_mark = 0;
	int last_mark = 0;
	string log_s = "";
	string now=ctime(time());
	int level = user->query_level();
	string user_id = user->query_name();
	string querySql = "select presenter_id,last_mark from presenter_info where user_id='"+user_id+"'";
	array(mapping(string:mixed)) rlt = ({});
	mixed err = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		rlt = db->query(querySql);
	};
	if(err){
		Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in flush_mark() wrong\n");
		return;
	}
	//没有推荐人，则直接返回
	if(rlt == 0 || sizeof(rlt) == 0){
		Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in flush_mark() return wrong\n");
		return;
	}
	//等级的积分加成
	mark_add += (15+25*((int)level/5-1)); 
	//玩家积分的加成
	all_mark = user->all_mark;
	if(all_mark){
		last_mark += (int)rlt[0]["last_mark"];
		int tmp = all_mark - last_mark;
		if(tmp<0)
			tmp = 0;
		mark_add += (int)tmp/10;
	}
	//然后把分加给推荐者
	string p_id = rlt[0]["presenter_id"];
	if(p_id && sizeof(p_id)){
		int load_flg = 0;
		object presenter = find_player(p_id);
		if(!presenter){
			presenter = user->load_player(p_id);
			load_flg = 1;
		}
		if(presenter){
			presenter->all_mark += mark_add;
			presenter->cur_mark += mark_add;
			log_s += presenter->query_name_cn()+"("+presenter->query_name()+")获得"+mark_add+"点积分，因为"+user->query_name_cn()+"("+user->query_name()+")升级至"+level+"级\n";
			Stdio.append_file(log_file,now[0..sizeof(now)-2]+":"+log_s);
			//更新推荐者数据库里的信息，如果有的话
			if(presenter->set_presenter != "" && presenter->set_presenter != "can_set"){
				querySql = "update presenter_info set all_mark="+presenter->all_mark+" where user_id='"+p_id+"'";
				err = catch{
					if(!db)
						db=Sql.Sql(dbSql,optionsMap);
					db->query(querySql);
				};
				if(err){
					Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in flush_mark() wrong\n");
					return;
				}
			}
			if(load_flg)
				presenter->remove();
		}
		//更新玩家的数据库信息
		querySql = "update presenter_info set last_mark="+user->all_mark+" where user_id='"+user_id+"'";
		err = catch{
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
		};
		if(err){
			Stdio.append_file(log_err_file,now[0..sizeof(now)-2]+":["+querySql+"] in flush_mark() wrong\n");
			return;
		}
	}
	return;
}

