/**
 *  log格式：Datetime -- [fuction(arg1,arg2,...)] [retValue] [succ|fail] [proccTime] [cause] 
 *  2007-4-6 liaocheng
 **/
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

object LOG;

#define log_file ROOT "/log/auctiond.log" 
#define TIME_INTERVAL 1200 //每20分钟检查一下拍卖行的情况
#define FETCH_TIME 604800 //领取时间期限为7天  
#define VENDUE_TIME 54000 //拍卖时间为15小时

Sql.Sql db;
//#define GAME_NAME		"xd"//游戏区名
//string dbSql = "mysql://root:password@game_database:22334/"+GAME_NAME; //远程数据库服务器
string mysql_password ="Happy888888";
string dbSql = "mysql://root:"+mysql_password+"@127.0.0.1/"+GAME_AREA;

//mapping optionsMap = (["mysql_charset_name":"gb2312"]);
mapping optionsMap = ([]);

void create()
{
	//	LOG->setFilePre(log_file);
	LOG = LOG_P(log_file);
	db=Sql.Sql(dbSql,optionsMap);
	call_out(time_task,TIME_INTERVAL);
}

//描述:每隔一定时间处理一下
//     1,已经到交易期限的交易
//     2,回收到时尚未领取的物品(买,卖)
private void time_task()
{
	int st = time();
	//LOG->append_time("[time_task()] [void] [succ] [" + (time()-st) + "s] [start]");
	//检查是否有到期的拍卖
	check_sale_info();
	//检查是否有到期的领取未被领取
	check_result_info();

	call_out(time_task,TIME_INTERVAL);
	//LOG->append_time("[time_task()] [void] [succ] [" + (time()-st) + "s] [end]");
}


//描述：获得玩家当前正在拍卖的商品
//参数：
//      saler_id　-- 卖家id
//liaocheng于07/4/1添加
array(mapping(string:mixed)) query_my_sale_infos(string saler_id)
{
	int st = time();
	string querySql = "select sale_id,goods_filename,goods_name_cn,goods_count,goods_level,cur_value,end_value,iopen_time,convert_count from sale_info where sale_status = 0 and saler_id='"+saler_id+"' order by iopen_time desc";
	mixed catchResult = catch {  
	if(!db)
		db=Sql.Sql(dbSql,optionsMap);
	array(mapping(string:mixed)) result = db->query(querySql);
	LOG->append_time("[query_my_sale_infos(" + saler_id + ")] [retSize:" + sizeof(result) + "] [succ] [" + (time()-st) + "s]");
	return result;
	};
	if(catchResult)
	{
		LOG->append_time("[query_my_sale_infos(" + saler_id + ")] [zero_size_array] [fail] [querySql:"+querySql+"] ["+ (time()-st) + "s]");
		return ({});
	}
}

//描述：以分页的形式获得商品信息
//参数：
//	   goods_name -- 物品名字
//     goods_type -- 商品类型  1：武器  2：防具  3：首饰 4：饰物 5：其他
//     orderType  -- 排序依据. 0,按起拍时间排序
//                             1,按物品名称排序
//                             2,按物品等级升序排列
//							   3,按物品稀有度降序排列
//返回:
//    异常情况下返回一个长度为空的数组
//liaocheng于07/3/28修改
array(mapping(string:mixed)) query_sale_infos(string goods_name_cn,int goods_type,int|void orderType)
{
	int st = time();
	if(goods_type != 0 &&goods_type != 1 && goods_type != 2 && goods_type != 3 && goods_type != 4 && goods_type != 5)
	{
		LOG->append_time("[query_sale_infos("+goods_name_cn+","+goods_type+",)] [zero_size_array] [fail:goods_type]");
		return ({});
	}

	string orderSql = " order by iopen_time desc";
	if(orderType == 1)
		orderSql = " order by goods_name_cn asc";
	else if(orderType == 2)
		orderSql = " order by goods_level asc";
	//else if(orderType == 3)
	//	orderSql = " order by goods_rare desc";

	string querySql = "select sale_id,goods_name_cn,goods_count,goods_level,cur_value,end_value,convert_count from sale_info where sale_status=0";
	if(goods_name_cn == "")
		goods_name_cn = "all";
	if(goods_name_cn != "all")
		querySql += " and goods_name_cn like '%"+goods_name_cn+"%'";
		//querySql += " and instr(Hex(goods_name_cn), Hex('"+goods_name_cn+"'))>0";
	if(goods_type)
		querySql += " and goods_type="+goods_type;
	querySql += orderSql;
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		array(mapping(string:mixed)) result = db->query(querySql);
		LOG->append_time("[query_sale_infos("+goods_name_cn+","+goods_type+","+orderType+")] [retSize:"+sizeof(result) + "] [succ] [querySql:"+querySql+"] [" + (time()-st) + "s]");
		return result;
	};
	if(catchResult)
	{
		LOG->append_time("[query_sale_infos("+goods_name_cn+","+goods_type+","+orderType+")] [zero_size_array] [fail] [querySql:"+querySql+"] ["+ (time()-st) + "s]");
		return ({});
	}
}

//描述:获得指定id的拍卖任务的信息
//参数: id -- 拍卖任务Id
//liaocheng于07/3/28修改
mapping(string:mixed) query_sale_info(int id)
{
	mapping(string:mixed) retMap = ([]); 

	string querySql = "select goods_filename,goods_name_cn,goods_count,saler_id,saler_name,cur_value,end_value,iopen_time,buy_flag,sale_status,winner_name,winner_id,convert_count from sale_info where sale_status=0 and sale_id=" +id;
	mixed catchResult = catch {  
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		array(mapping(string:mixed)) result = db->query(querySql);

		if(sizeof(result) > 0)
			retMap = result[0];
	};
	if(catchResult)
	{
		LOG->append_time("[query_sale_info(" + id + ")] [zero_size_map] [fail] [--] [querySql:"+querySql + "]");
		return ([]);
	}
	return retMap;
}

//核心接口
//参数：winner - 竞价的玩家,当flag=2或3或4的时候，
//	    sale_id - 拍卖号
//      value  - 竞价,在调用此函数前上层就已经做了判断，所以此值肯定是合法的
//      flag   - 标示位，0：仍可竞价，1：因为一口价而竞价胜出，2：因为期限到了而竞价胜出
//						 3：拍卖失败，4：取消竞拍
//描述：玩家在竞价物品时，将会把上次竞价人给挤下去，因此将更新数据库sale_info和result_info，若玩家
//      并非一口价购买或者竞价没有超过一口价，则此物品仍保持竞价状态向其他玩家开放，否则该物品的竞
//	    拍结束，winner胜出，不再继续向其他玩家开放此物品的竞拍
//liaocheng于07/3/30添加
int reset_sale_info(void|object winner,int sale_id,int value,int flag)
{
	mapping(string:mixed) sale_info = query_sale_info(sale_id);
	if(!sizeof(sale_info))
		return 0;
	//记录上次竞拍的一些信息
	string querySql = "";
	string winner_id = "";
	string winner_name = "";
	string title = ""; //信件标题
	string content = ""; //信件内容
	mixed catchResult;
	if(winner){
		winner_id = winner->query_name();
		winner_name = winner->query_name_cn();
	}

	if((int)sale_info["buy_flag"] && flag!=2){ 
		//将失败者的竞价返回给失败者,导致失败可能是竞价被超过，也可能是卖主取消了拍卖
		string loser_id = sale_info["winner_id"];
		string loser_name = sale_info["winner_name"];
		int value_back = (int)sale_info["cur_value"];
		querySql = "insert into result_info (sale_id,rltflag,fetch_status,buyer_id,goods,count,money,dead_time,convert_count) values ("+sale_id+",1,0,'"+loser_id+"','"+sale_info["goods_filename"]+"',"+sale_info["goods_count"]+","+value_back+","+(time()+FETCH_TIME)+","+sale_info["convert_count"]+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);

			//发信通知玩家
			title = "竞价失败\n";
			content = "你对"+sale_info["goods_name_cn"]+"的竞价被超过了，或者卖主取消了拍卖，请即时来拍卖行领回你的竞价，若7日内未领取，你的竞价将被充公\n";
			mail_notice(loser_id,title,content);

			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult)
		{
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
	}
	if(flag == 0){
		//竞价
		//则把目前竞价者更新到sale_info数据库里
		querySql = "update sale_info set cur_value="+value+",winner_id='"+winner_id+"',winner_name='"+winner_name+"'";
		if(!(int)sale_info["buy_flag"])
			querySql +=",buy_flag=1";
		querySql +=" where sale_id="+sale_id;
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
		return 1;
	}

	else if(flag == 1||flag == 2){
	//竞拍胜出，我们将把钱返给卖主，物品返给买主，即更新result_info,并且将sale_info相应的拍卖单的
	//sale_status置为1，以表示此竞拍已经完成
		//将钱返给卖主
		string saler_id = sale_info["saler_id"];
		string saler_name = sale_info["saler_name"];
		string goods_name = sale_info["goods_filename"];
		int goods_count = sale_info["goods_count"];
		int convert_count = sale_info["convert_count"];
		int value_now = value;
		if(flag == 2)
			value_now = (int)sale_info["cur_value"];
		//扣税
		int fees = value_now*5/100;
		if(fees<=0)
			fees = 1;
		value_now = value_now - fees;

		querySql = "insert into result_info (sale_id,rltflag,fetch_status,saler_id,goods,count,money,dead_time,convert_count) values("+sale_id+",2,0,'"+saler_id+"','"+goods_name+"',"+goods_count+","+value_now+","+(time()+FETCH_TIME)+","+convert_count+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			//发信通知玩家
			title = "拍卖成功\n";
			content = "你的"+sale_info["goods_name_cn"]+"已经售出，请即时来拍卖行领回你的金钱，若7日内未领取，你的金钱将被充公\n";
			mail_notice(saler_id,title,content);

			LOG->append_time("for saler:reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}

		//将物品返给竞价胜利者
		if(flag == 2){
			winner_id = sale_info["winner_id"];
		}
		querySql = "insert into result_info (sale_id,rltflag,fetch_status,buyer_id,goods,count,dead_time,convert_count) values("+sale_id+",2,0,'"+winner_id+"','"+goods_name+"',"+goods_count+","+(time()+FETCH_TIME)+","+convert_count+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			if(flag == 2){
				//发信通知玩家
				title = "竞拍成功\n";
				content = "你在竞拍"+sale_info["goods_name_cn"]+"中胜出，请即时来拍卖行领回你的物品，若7日内未领取，物品将被充公\n";
				mail_notice(winner_id,title,content);

			}
			LOG->append_time("for winner:reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}

		//最后将sale_info的单子结束竞拍
		querySql = "update sale_info set cur_value="+value_now+",winner_id='"+winner_id+"',winner_name='"+winner_name+"',sale_status=1 where sale_id="+sale_id;
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
		return 2;
	}

	else if(flag == 3 || flag == 4){
		//3-拍卖失败，当拍卖时间到了，而又无人竞价(这个是在调用此函数前就已作了判断)，则将物品返回给卖家
		//4-取消竞拍，物品返回给卖家，如有人竞拍，则把钱返回给竞拍人(在前面已经实现)
		string saler_id = sale_info["saler_id"];
		string saler_name = sale_info["saler_name"];
		string goods_name = sale_info["goods_filename"];
		int goods_count = sale_info["goods_count"];
		int convert_count = sale_info["convert_count"];
		int rltflag;
			if(flag == 3)
				rltflag = 0;
			else 
				rltflag = 3;
		//物品返回给卖主
		querySql = "insert into result_info (sale_id,rltflag,fetch_status,saler_id,goods,count,dead_time,convert_count) values("+sale_id+","+rltflag+",0,'"+saler_id+"','"+goods_name+"',"+goods_count+","+(time()+FETCH_TIME)+","+convert_count+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			if(flag == 3){
				//发信通知玩家
				title = "拍卖失败\n";
				content = "你拍卖的"+sale_info["goods_name_cn"]+"已经过期，请即时来拍卖行领回你的物品，若7日内未领取，物品将被充公\n";
				mail_notice(saler_id,title,content);

			}
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
		//更新sale_info中的相应项
		querySql = "update sale_info set sale_status=1 where sale_id="+sale_id;
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
		return 3;
	}

}

//向sale_info数据库加入新的拍卖信息
//参数：saler-卖主
//      goods-物品
//      start_value-起始价
//      end_value-一口价
//成功返回1，否则返回0
//liaocheng于07/4/2添加
int add_new_sale_info(object saler,object goods,int start_value,int end_value)
{
	//return 0;

	werror("================== i am in !  ======================\n");
	string saler_id = saler->query_name();
	string saler_name = saler->query_name_cn();
	string goods_filename = file_name(goods);
	//防止警号出现
	array(string) tmp = goods_filename/"#";
	if(tmp&&sizeof(tmp)){
		if(tmp[0]&&sizeof(tmp[0]))
			goods_filename = tmp[0];
	}
	//string goods_filename =  Program.defined(object_program(goods));
	string goods_name_cn = goods->query_name_cn();
	int goods_count = 1;
	int convert_count = 0;
	if(goods->is_combine_item())
		goods_count = goods->amount;
	if(goods->is("equip"))                                                                                    
		convert_count = goods->query_convert_count();
	string goods_type_s = goods->query_item_type();
	int goods_type = 5; //缺省情况下的物品类别置为其他
	if(goods_type_s=="weapon"||goods_type_s=="single_weapon"||goods_type_s=="double_weapon")
		goods_type = 1;
	else if(goods_type_s=="armor")
		goods_type = 2;
	else if(goods_type_s=="jewelry")
		goods_type = 3;
	else if(goods_type_s=="decorate")
		goods_type = 4;
	int goods_level = 1; //缺省下物品的等级为1
	if(goods->query_item_type()=="weapon"||goods->query_item_type()=="single_weapon"||goods->query_item_type()=="double_weapon"||goods->query_item_type()=="armor"||goods->query_item_type()=="decorate"||goods->query_item_type()=="jewelry") 
		goods_level = (int)goods->query_item_canLevel();
	else
		goods_level = (int)goods->level_limit;

	string querySql = "insert into sale_info (saler_id,saler_name,goods_filename,goods_name_cn,goods_count,goods_type,goods_level,cur_value,end_value,open_time,iopen_time,close_time,sale_status,buy_flag,convert_count) values ('"+saler_id+"','"+saler_name+"','"+goods_filename+"','"+goods_name_cn+"',"+goods_count+","+goods_type+","+goods_level+","+start_value+","+end_value+",now(),"+time()+","+(time()+VENDUE_TIME)+",0,0,"+convert_count+")";
	mixed catchResult = catch{
		if(!db){
			db=Sql.Sql(dbSql,optionsMap);
		}
		db->query(querySql);
		//从玩家身上移出物品
		goods->remove();	
		LOG->append_time("[add_new_sale_info("+saler_id+","+goods_name_cn+","+start_value+","+end_value+")] [succ] [--] [querySql:"+querySql + "]");
		werror("----"+querySql+"----\n");
		return 1;
	};
	if(catchResult){
		LOG->append_time("[add_new_sale_info("+saler_id+","+goods_name_cn+","+start_value+","+end_value+")] [fail] [--] [querySql:"+querySql + "]");
		return 0;
	}
}

//作为卖主察看是否有取回的东西
//liaocheng于07/4/3日添加
array(mapping(string:mixed)) query_getback_as_saler(string player_id)
{
	//卖主取回东西的可能有1.拍卖失败 rltflag==0
	//                    2.拍卖成功 rltflag==2
	//                    3.取消拍卖 rltflag==3
	array(mapping(string:mixed)) rtn = ({});
	string querySql = "select * from result_info where saler_id='"+player_id+"' and fetch_status=0";
	mixed catchResult = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		rtn = db->query(querySql);
		LOG->append_time("[query_getback_as_saler("+player_id+")] [succ] [querySql:"+querySql+"] [size:"+sizeof(rtn)+"]");
		return rtn;
	};
	if(catchResult){
		LOG->append_time("[query_getback_as_saler("+player_id+")] [fail] [querySql:"+querySql+"] [size:"+sizeof(rtn)+"]");
		return ({});
	}
}

//作为买主察看是否有取回的东西
//liaocheng于07/4/3日添加
array(mapping(string:mixed)) query_getback_as_buyer(string player_id)
{
	//卖主取回东西的可能有:竞拍失败 rltflag==1
	//                     竞拍成功 rltflag==2
	array(mapping(string:mixed)) rtn = ({});
	string querySql = "select * from result_info where buyer_id='"+player_id+"' and fetch_status=0";
	mixed catchResult = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		rtn = db->query(querySql);
		LOG->append_time("[query_getback_as_buyer("+player_id+")] [succ] [querySql:"+querySql+"] [size:"+sizeof(rtn)+"]");
		return rtn;
	};
	if(catchResult){
		LOG->append_time("[query_getback_as_buyer("+player_id+")] [fail] [querySql:"+querySql+"] [size:"+sizeof(rtn)+"]");
		return ({});
	}
}

//此接口将result_info中id 的fetch_status置为1，当然首先是要判断它，以免重复被取回
//liaocheng于07/4/3添加
int finish_getback(int id)
{
	//return 0;

	string querySql = "select fetch_status from result_info where id="+id;

	mapping(string:mixed) result = ([]);
	mixed catchResult = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		array(mapping(string:mixed)) tmp = db->query(querySql);
		if(sizeof(tmp)>0)
			result = tmp[0];
		if((int)result["fetch_status"]==1)
			return 0;
		else{
			string querySql2 = "update result_info set fetch_status=1 where id="+id;
			db->query(querySql2);
			return 1;
		}

		LOG->append_time("[finish_getback("+id+")] [succ] [querySql:"+querySql+"]");
	};
	if(catchResult){
		LOG->append_time("[finish_getback("+id+")] [fail] [querySql:"+querySql+"]");
		return 2;
	}
}

//检查是否有过期的拍卖
//liaocheng于07/4/3添加
private void check_sale_info()
{
	int st = time();
	string querySql = "select sale_id,buy_flag from sale_info where sale_status=0 and close_time<"+st;
	mixed catchResult = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		array(mapping(string:mixed)) list = db->query(querySql);
		
		if(list&&sizeof(list)){
			foreach(list,mapping(string:mixed)sale_info){
				int sale_id=sale_info["sale_id"];
				//拍卖失败的
				if((int)sale_info["buy_flag"]==0)
					reset_sale_info(0,sale_id,0,3);
				//有人竞拍，拍卖期限到
				else
					reset_sale_info(0,sale_id,0,2);
			}
		}
		
		LOG->append_time("[check_sale_info()] [succ] [querySql:"+querySql+"]");
	};
	if(catchResult){
		LOG->append_time("[check_sale_info()] [fail] [querySql:"+querySql+"]");
	}
}

//检查是否有过期而又未领取的，有则自动回收
//liaocheng于07/4/3添加
private void check_result_info()
{
	int st = time();
	string querySql = "update result_info set fetch_status=2 where dead_time<"+st;	
	mixed catchResult = catch{
		if(!db)
			db=Sql.Sql(dbSql,optionsMap);
		db->query(querySql);
		LOG->append_time("[check_result_info()] [succ] [querySql:"+querySql+"]");
	};
	if(catchResult){
		LOG->append_time("[check_result_info()] [fail] [querySql:"+querySql+"]");
	}
}

//给玩家寄信以提示拍卖行情况
//liaocheng于07/4/4添加
void mail_notice(string recver_name,string title,string content)
{
	//object sender = find_object("paimaishi");
	int remove_flag = 0;
	object to = find_player(recver_name);
	if(!to){
		array list=users(1);
		object helper; //随机找个在线的玩家，以调用load_player()来将未在线的玩家载入内存
		for(int j=0;j<sizeof(list);j++){
			helper = list[j];
			if(helper)
				break;
		}
		to = helper->load_player(recver_name);
		remove_flag = 1;
	}
	if(to){
		to->recieve_mail("paimaishi","仙道拍卖信使",recver_name,to->query_name_cn(),title,content);
		tell_object(to,"你有新的信件，请即时查收\n");
	}
	if(remove_flag)
		to->remove();
}

//liaocheng于07/3/28查看完毕
string get_time_desc(int old_time)
{
	string ret_str = "长";
	int time_inv = 15*3600 - (time() - old_time);
	if(time_inv < 3*3600)
		ret_str = "短";
	else if(time_inv < 9*3600)
		ret_str = "中";

	return ret_str;
}

