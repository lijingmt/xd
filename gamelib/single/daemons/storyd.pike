/**
 * ��ҽ�����Ϸ�������ʾ
 * 
 * @author calvin 
 * 2007/04/11 13:06:51
 */
#include <globals.h>
#include <gamelib/include/gamelib.h>
#define FILE_PATH "/gamelib/etc/tips"
#define POST_PATH "/gamelib/etc/postmsg"
#define SERVER_PATH "/gamelib/etc/servermsg"

inherit LOW_DAEMON;
private array(string) tips=({});
//////////�ļ���䷽ʽ////////////////////////
// ����           ״̬     ����          ��������
//yunying       |disable  |��������|����10����15�ſ�ʼ������
//......
//////////////////////////////////////////////
private mapping(string:array) new_msgs=([]);
private string server_msg = "";

//by calvin 2007-08-31
array(string) reserved_words=({});
//by calvin 2007-08-31

void create(){
	tips=({});
	string strtips = "";
	strtips = Stdio.read_file(ROOT+FILE_PATH); 
	if(strtips&&sizeof(strtips)){
		tips = strtips/"\n";
		tips -= ({""});	
	}
	////////////////////////////////////////
	new_msgs=([]);
	array arr_tmps = ({});
	string strmsgs = "";
	strmsgs = Stdio.read_file(ROOT+POST_PATH);
	if(strmsgs&&sizeof(strmsgs)){
		arr_tmps = strmsgs/"\n";
		arr_tmps -= ({""});	
	}
	if(arr_tmps&&sizeof(arr_tmps)){
		foreach(arr_tmps,string ind){
			if(ind&&sizeof(ind)){
				array arr1 = ind/"|";
				arr1 -= ({""});	
				new_msgs[arr1[0]]=arr1;	
			}
		}
	}
	//////////////////////////////////////
	string strservers = "";
	strservers = Stdio.read_file(ROOT+SERVER_PATH);
	if(strservers&&sizeof(strservers))
		server_msg = strservers;
	//��������ʻ�by calvin 2007-08-31                                                                     
	reserved_words=({});
	string strwords = "";
	strwords = Stdio.read_file(ROOT+"/gamelib/etc/reserved_names");
	if(strwords&&sizeof(strwords)){
		reserved_words = strwords/"\n";
		reserved_words -= ({""});
	}
	//by calvin 2007-08-31
}
//ϵͳ֪ͨ��Ϣ
string query_server_tips()
{
	if(server_msg&&sizeof(server_msg))
		return server_msg;
	return "";
}
//��Ӫ��Ϣ�Ƿ���
int query_yunying_status()
{
	if(new_msgs&&sizeof(new_msgs))
		return sizeof(new_msgs);
	return 0;
}
//��Ӫ��Ϣ
string query_yunying_tips()
{
	string rst = "";
	if(new_msgs&&sizeof(new_msgs)){
		foreach(indices(new_msgs),string ind){
			if(ind&&sizeof(ind)){
				if(new_msgs[ind]&&sizeof(new_msgs[ind])){
					if(new_msgs[ind][1]=="enable")
						rst += new_msgs[ind][2]+"\n"+new_msgs[ind][3]+"\n--------\n";
				}
			}
		}
	}
	return rst;
}
string query_tips(){
	return tips[random(sizeof(tips))]+"\n";
}
//by calvin 2007-08-31
string check_words(string words){
	if(!reserved_words) 
		return words;
	foreach(reserved_words,string limit)
	{
		if(limit=="")
			continue;
		//�ւ��жϹؼ���
		if(words&&sizeof(words)){
			words=replace(words,limit,"xxx"); 
		}
	}
	return words;
}


//ҳ����ʾ
string get_tail_desc()
{
        string s_rtn = "";
	s_rtn += "�ɽ�ʱ�䣺";
	s_rtn += TIMESD->query_cur_time()+"\n";
	s_rtn += "--------\n";
	s_rtn += "[url ��ҳ:http://www.wapmud.com/gamehome/]|";
	s_rtn += "[url ����:https://tieba.baidu.com/f?kw=wapmud]\n";
	s_rtn += "������ȡ���� qq:1811117272\n Line:txai\n ���䣺1811117272@qq.com\n�ٷ�qqȺ��:478189825\n";
	//s_rtn += "�����ֹ������������ޡ�\n";
	//s_rtn += "-- [url ��:http://tx1.dogstart.com/txmud/tx/index.jsp]||";
	//s_rtn += "[url ���� AI ����:http://tx.wapmud.com/tx/pc.jsp]\n";
	//s_rtn += "[url ���ˬ����:http://fh.wapmud.com/fh/pc.jsp]\n";
	//s_rtn += "[url ��:http://wap.dogstart.com/forum/game_page] --\n";
	//s_rtn += "- [url wap.dogstart.com:http://dogstart.com/wap/index.jsp] -\n";
	return s_rtn;
}
//by caijie 080813
