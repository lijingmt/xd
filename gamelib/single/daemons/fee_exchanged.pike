/********************************************* ��Ϸ����Ҷһ��ػ����� ********************************************
1.��������Ҫ���֣��һ��Ĳ������һ������Ŀ���
  �һ��Ĳ�������������ȡ�����棬�����ݿ���Ϊ��ת�������������ݿ�д����Ϣ����ȡ�������ݿ������Ϣ����á�
  �һ������Ŀ��ƣ��ɵ�������Ϊ����������,�������<=����������������Ϊ��������������������<=�������

2.���ݱ����ƣ�
  ���ݱ�fee_exchange_info��¼�˶һ���������Ϣ����ʽΪ��
  id|from_game|from_user|from_usercn|from_time|exchange_fee|to_game|to_user|fetch_status|fetch_time
    ��1��id������id����Ϊ��������������
    ��2��from_game����������Ϸ�����ţ����ɵ���xd1,xdx,xdy�����µ�tx1��tx2�����Ƶ�qp0�ȡ�
    ��3��from_user��ִ�л���������ʺš�
    ��4��from_usercn��ִ�л���������ǳơ�
    ��5��from_time��ִ�л�����ʱ�䣬��ʽΪmysql�ı�׼ʱ���ʽ���磺2008-07-30 11:09:20��
    ��6��exchange_fee���һ������������������е���Ϸ��������1�ǵ�ֵ�Ļ���Ϊ��λд�뵽���
    ��7��to_game���һ�������Ϸ����
    ��8��to_user���һ���������ʺš�
    ��9��fetch_status����ȡ��ʶ��=0��ʾδ��ȡ��=1��ʾ����ȡ��
    ��10��fetch_time��������ȡ�������¼��ȡ��ʱ�䡣

3.�һ��������Ƶĳ���������ƣ�
  class exchange_amount{
  	int in_amount; //�����
	int out_amount; //������
  }
  mapping(string:exchange_amount) amount_m = ([��Ϸ��:������])
  ��������Ϣ���洢���ļ�gamelib/etc/fee_exchange.infos��ÿ�μ���ʱҲ��Ӹ��ļ�����
  �ļ���ʽ��game_id,out_amount,in_amount
****************************************************************************************************************/
#include <gamelib/include/gamelib.h>
#define EXCHANGE_INFOS ROOT "/gamelib/etc/fee_exchange.infos"
#define SAVE_TIME 3600 //��дfee_exchange.infos��ʱ��
//#define SAVE_TIME 120 //��дfee_exchange.infos��ʱ��
inherit LOW_DAEMON;
Sql.Sql db;
string dbSql = "mysql://root:34ccpalm@game_database:22334/pokegame_tongji";
mapping optionsMap = ([]);
object obt;

//�����������ݽṹ����
class exchange_amount{
	int out_amount; //������
  	int in_amount; //�����
}
private mapping(string:exchange_amount) amount_m = ([]);
//��Ϸ����������������ӳ���
private mapping(string:string) game_id_cn = (["xd1":"�ɵ�������",
					       "xdx":"�ɵ�������",
					       "xdy":"�ɵ��Ѫ��",
					       "qp0":"��������",
					       "tx1":"���°�ҵ",
					       "tx2":"���ݷ���",
					       "tx5":"��Ѫ����",
					       "tx7":"���轭��",
					       "tx11":"����ݺ�",
					       "tx14":"�����ĺ�"
					      ]);
void create()
{
	//db=Sql.Sql(dbSql,optionsMap);
	obt= System.Time();
	//���س�������Ϣ
	load_exchange_amount_infos();
	call_out(write_back_infos,SAVE_TIME);
}

//���س�������Ϣ��
//1.���ļ�gamelib/etc/fee_exchange.infos�ļ��ж���
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

//��дfee_exchange.infos�ļ�
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

//�����ȡ�б�Ľӿ�
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
			s_rtn += "["+YUSHID->query_yushi_add_fee_desc(ante_fee,1)+":fee_exchange_fetch_confirm "+id+" "+from_game+"](���ԣ�"+from_usercn+"-"+game_id_cn[from_game]+")\n";
		}
	}
	if(s_rtn == "")
		s_rtn = "��������\n";
	return s_rtn;
}

//��ȡ�Ի����ĳ���
//���� -1��ʾû��������ȡ��¼��0��ʾ�Ѿ���ȡ����>0��ʾ��ȡ�ɹ�,��ֵ����ȡ�ĳ�����
int fetch_fee(object player,int id,string from_game)
{
	string player_name = player->query_name();
	//�����ж��Ƿ�id�Ϸ�
	int fg = is_exchange_id_ok(player_name,id);
	if(fg == 0)
		return 0;
	else if(fg == -1)
		return -1;
	else if(fg > 0){
		int ante_fee = fg;
		//�޸����ݱ����������ʯ����
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
		//������ˢ��
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

//�ж϶һ�id�Ƿ�Ϸ�
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

//����Ϸ���һ����õĽӿڣ���ɽ��һ���Ϣд�����ݿ�Ĳ���
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
	//ˢ�³�����
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
