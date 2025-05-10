/**
 *  log��ʽ��Datetime -- [fuction(arg1,arg2,...)] [retValue] [succ|fail] [proccTime] [cause] 
 *  2007-4-6 liaocheng
 **/
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;

object LOG;

#define log_file ROOT "/log/auctiond.log" 
#define TIME_INTERVAL 1200 //ÿ20���Ӽ��һ�������е����
#define FETCH_TIME 604800 //��ȡʱ������Ϊ7��  
#define VENDUE_TIME 54000 //����ʱ��Ϊ15Сʱ

Sql.Sql db;
//#define GAME_NAME		"xd"//��Ϸ����
//string dbSql = "mysql://root:password@game_database:22334/"+GAME_NAME; //Զ�����ݿ������
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

//����:ÿ��һ��ʱ�䴦��һ��
//     1,�Ѿ����������޵Ľ���
//     2,���յ�ʱ��δ��ȡ����Ʒ(��,��)
private void time_task()
{
	int st = time();
	//LOG->append_time("[time_task()] [void] [succ] [" + (time()-st) + "s] [start]");
	//����Ƿ��е��ڵ�����
	check_sale_info();
	//����Ƿ��е��ڵ���ȡδ����ȡ
	check_result_info();

	call_out(time_task,TIME_INTERVAL);
	//LOG->append_time("[time_task()] [void] [succ] [" + (time()-st) + "s] [end]");
}


//�����������ҵ�ǰ������������Ʒ
//������
//      saler_id��-- ����id
//liaocheng��07/4/1���
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

//�������Է�ҳ����ʽ�����Ʒ��Ϣ
//������
//	   goods_name -- ��Ʒ����
//     goods_type -- ��Ʒ����  1������  2������  3������ 4������ 5������
//     orderType  -- ��������. 0,������ʱ������
//                             1,����Ʒ��������
//                             2,����Ʒ�ȼ���������
//							   3,����Ʒϡ�жȽ�������
//����:
//    �쳣����·���һ������Ϊ�յ�����
//liaocheng��07/3/28�޸�
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

//����:���ָ��id�������������Ϣ
//����: id -- ��������Id
//liaocheng��07/3/28�޸�
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

//���Ľӿ�
//������winner - ���۵����,��flag=2��3��4��ʱ��
//	    sale_id - ������
//      value  - ����,�ڵ��ô˺���ǰ�ϲ���Ѿ������жϣ����Դ�ֵ�϶��ǺϷ���
//      flag   - ��ʾλ��0���Կɾ��ۣ�1����Ϊһ�ڼ۶�����ʤ����2����Ϊ���޵��˶�����ʤ��
//						 3������ʧ�ܣ�4��ȡ������
//����������ھ�����Ʒʱ��������ϴξ����˸�����ȥ����˽��������ݿ�sale_info��result_info�������
//      ����һ�ڼ۹�����߾���û�г���һ�ڼۣ������Ʒ�Ա��־���״̬��������ҿ��ţ��������Ʒ�ľ�
//	    �Ľ�����winnerʤ�������ټ�����������ҿ��Ŵ���Ʒ�ľ���
//liaocheng��07/3/30���
int reset_sale_info(void|object winner,int sale_id,int value,int flag)
{
	mapping(string:mixed) sale_info = query_sale_info(sale_id);
	if(!sizeof(sale_info))
		return 0;
	//��¼�ϴξ��ĵ�һЩ��Ϣ
	string querySql = "";
	string winner_id = "";
	string winner_name = "";
	string title = ""; //�ż�����
	string content = ""; //�ż�����
	mixed catchResult;
	if(winner){
		winner_id = winner->query_name();
		winner_name = winner->query_name_cn();
	}

	if((int)sale_info["buy_flag"] && flag!=2){ 
		//��ʧ���ߵľ��۷��ظ�ʧ����,����ʧ�ܿ����Ǿ��۱�������Ҳ����������ȡ��������
		string loser_id = sale_info["winner_id"];
		string loser_name = sale_info["winner_name"];
		int value_back = (int)sale_info["cur_value"];
		querySql = "insert into result_info (sale_id,rltflag,fetch_status,buyer_id,goods,count,money,dead_time,convert_count) values ("+sale_id+",1,0,'"+loser_id+"','"+sale_info["goods_filename"]+"',"+sale_info["goods_count"]+","+value_back+","+(time()+FETCH_TIME)+","+sale_info["convert_count"]+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);

			//����֪ͨ���
			title = "����ʧ��\n";
			content = "���"+sale_info["goods_name_cn"]+"�ľ��۱������ˣ���������ȡ�����������뼴ʱ�������������ľ��ۣ���7����δ��ȡ����ľ��۽����乫\n";
			mail_notice(loser_id,title,content);

			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult)
		{
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
	}
	if(flag == 0){
		//����
		//���Ŀǰ�����߸��µ�sale_info���ݿ���
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
	//����ʤ�������ǽ���Ǯ������������Ʒ����������������result_info,���ҽ�sale_info��Ӧ����������
	//sale_status��Ϊ1���Ա�ʾ�˾����Ѿ����
		//��Ǯ��������
		string saler_id = sale_info["saler_id"];
		string saler_name = sale_info["saler_name"];
		string goods_name = sale_info["goods_filename"];
		int goods_count = sale_info["goods_count"];
		int convert_count = sale_info["convert_count"];
		int value_now = value;
		if(flag == 2)
			value_now = (int)sale_info["cur_value"];
		//��˰
		int fees = value_now*5/100;
		if(fees<=0)
			fees = 1;
		value_now = value_now - fees;

		querySql = "insert into result_info (sale_id,rltflag,fetch_status,saler_id,goods,count,money,dead_time,convert_count) values("+sale_id+",2,0,'"+saler_id+"','"+goods_name+"',"+goods_count+","+value_now+","+(time()+FETCH_TIME)+","+convert_count+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			//����֪ͨ���
			title = "�����ɹ�\n";
			content = "���"+sale_info["goods_name_cn"]+"�Ѿ��۳����뼴ʱ�������������Ľ�Ǯ����7����δ��ȡ����Ľ�Ǯ�����乫\n";
			mail_notice(saler_id,title,content);

			LOG->append_time("for saler:reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}

		//����Ʒ��������ʤ����
		if(flag == 2){
			winner_id = sale_info["winner_id"];
		}
		querySql = "insert into result_info (sale_id,rltflag,fetch_status,buyer_id,goods,count,dead_time,convert_count) values("+sale_id+",2,0,'"+winner_id+"','"+goods_name+"',"+goods_count+","+(time()+FETCH_TIME)+","+convert_count+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			if(flag == 2){
				//����֪ͨ���
				title = "���ĳɹ�\n";
				content = "���ھ���"+sale_info["goods_name_cn"]+"��ʤ�����뼴ʱ����������������Ʒ����7����δ��ȡ����Ʒ�����乫\n";
				mail_notice(winner_id,title,content);

			}
			LOG->append_time("for winner:reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value_now+","+flag+") [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}

		//���sale_info�ĵ��ӽ�������
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
		//3-����ʧ�ܣ�������ʱ�䵽�ˣ��������˾���(������ڵ��ô˺���ǰ���������ж�)������Ʒ���ظ�����
		//4-ȡ�����ģ���Ʒ���ظ����ң������˾��ģ����Ǯ���ظ�������(��ǰ���Ѿ�ʵ��)
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
		//��Ʒ���ظ�����
		querySql = "insert into result_info (sale_id,rltflag,fetch_status,saler_id,goods,count,dead_time,convert_count) values("+sale_id+","+rltflag+",0,'"+saler_id+"','"+goods_name+"',"+goods_count+","+(time()+FETCH_TIME)+","+convert_count+")";
		catchResult = catch {  
			if(!db)
				db=Sql.Sql(dbSql,optionsMap);
			db->query(querySql);
			if(flag == 3){
				//����֪ͨ���
				title = "����ʧ��\n";
				content = "��������"+sale_info["goods_name_cn"]+"�Ѿ����ڣ��뼴ʱ����������������Ʒ����7����δ��ȡ����Ʒ�����乫\n";
				mail_notice(saler_id,title,content);

			}
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [succ] [querySql:"+querySql+"] ["+(time())+"]");
		};
		if(catchResult){
			LOG->append_time("reset_sale_info("+winner_id+","+sale_id+","+value+","+flag+")] [void] [fail] [querySql:"+querySql+"] ["+(time())+"]");
		}
		//����sale_info�е���Ӧ��
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

//��sale_info���ݿ�����µ�������Ϣ
//������saler-����
//      goods-��Ʒ
//      start_value-��ʼ��
//      end_value-һ�ڼ�
//�ɹ�����1�����򷵻�0
//liaocheng��07/4/2���
int add_new_sale_info(object saler,object goods,int start_value,int end_value)
{
	//return 0;

	werror("================== i am in !  ======================\n");
	string saler_id = saler->query_name();
	string saler_name = saler->query_name_cn();
	string goods_filename = file_name(goods);
	//��ֹ���ų���
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
	int goods_type = 5; //ȱʡ����µ���Ʒ�����Ϊ����
	if(goods_type_s=="weapon"||goods_type_s=="single_weapon"||goods_type_s=="double_weapon")
		goods_type = 1;
	else if(goods_type_s=="armor")
		goods_type = 2;
	else if(goods_type_s=="jewelry")
		goods_type = 3;
	else if(goods_type_s=="decorate")
		goods_type = 4;
	int goods_level = 1; //ȱʡ����Ʒ�ĵȼ�Ϊ1
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
		//����������Ƴ���Ʒ
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

//��Ϊ�����쿴�Ƿ���ȡ�صĶ���
//liaocheng��07/4/3�����
array(mapping(string:mixed)) query_getback_as_saler(string player_id)
{
	//����ȡ�ض����Ŀ�����1.����ʧ�� rltflag==0
	//                    2.�����ɹ� rltflag==2
	//                    3.ȡ������ rltflag==3
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

//��Ϊ�����쿴�Ƿ���ȡ�صĶ���
//liaocheng��07/4/3�����
array(mapping(string:mixed)) query_getback_as_buyer(string player_id)
{
	//����ȡ�ض����Ŀ�����:����ʧ�� rltflag==1
	//                     ���ĳɹ� rltflag==2
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

//�˽ӿڽ�result_info��id ��fetch_status��Ϊ1����Ȼ������Ҫ�ж����������ظ���ȡ��
//liaocheng��07/4/3���
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

//����Ƿ��й��ڵ�����
//liaocheng��07/4/3���
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
				//����ʧ�ܵ�
				if((int)sale_info["buy_flag"]==0)
					reset_sale_info(0,sale_id,0,3);
				//���˾��ģ��������޵�
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

//����Ƿ��й��ڶ���δ��ȡ�ģ������Զ�����
//liaocheng��07/4/3���
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

//����Ҽ�������ʾ���������
//liaocheng��07/4/4���
void mail_notice(string recver_name,string title,string content)
{
	//object sender = find_object("paimaishi");
	int remove_flag = 0;
	object to = find_player(recver_name);
	if(!to){
		array list=users(1);
		object helper; //����Ҹ����ߵ���ң��Ե���load_player()����δ���ߵ���������ڴ�
		for(int j=0;j<sizeof(list);j++){
			helper = list[j];
			if(helper)
				break;
		}
		to = helper->load_player(recver_name);
		remove_flag = 1;
	}
	if(to){
		to->recieve_mail("paimaishi","�ɵ�������ʹ",recver_name,to->query_name_cn(),title,content);
		tell_object(to,"�����µ��ż����뼴ʱ����\n");
	}
	if(remove_flag)
		to->remove();
}

//liaocheng��07/3/28�鿴���
string get_time_desc(int old_time)
{
	string ret_str = "��";
	int time_inv = 15*3600 - (time() - old_time);
	if(time_inv < 3*3600)
		ret_str = "��";
	else if(time_inv < 9*3600)
		ret_str = "��";

	return ret_str;
}

