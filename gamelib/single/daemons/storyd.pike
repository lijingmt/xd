/**
 * 玩家进入游戏的随机提示
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
//////////文件填充方式////////////////////////
// 类型           状态     标题          具体内容
//yunying       |disable  |钓鱼活动开启|本月10号至15号开始钓鱼活动。
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
	//屏蔽特殊词汇by calvin 2007-08-31                                                                     
	reserved_words=({});
	string strwords = "";
	strwords = Stdio.read_file(ROOT+"/gamelib/etc/reserved_names");
	if(strwords&&sizeof(strwords)){
		reserved_words = strwords/"\n";
		reserved_words -= ({""});
	}
	//by calvin 2007-08-31
}
//系统通知消息
string query_server_tips()
{
	if(server_msg&&sizeof(server_msg))
		return server_msg;
	return "";
}
//运营消息是否有
int query_yunying_status()
{
	if(new_msgs&&sizeof(new_msgs))
		return sizeof(new_msgs);
	return 0;
}
//运营消息
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
		//轮偱判断关键字
		if(words&&sizeof(words)){
			words=replace(words,limit,"xxx"); 
		}
	}
	return words;
}


//页脚显示
string get_tail_desc()
{
        string s_rtn = "";
	s_rtn += "仙界时间：";
	s_rtn += TIMESD->query_cur_time()+"\n";
	s_rtn += "--------\n";
	s_rtn += "[url 首页:http://www.wapmud.com/gamehome/]|";
	s_rtn += "[url 贴吧:https://tieba.baidu.com/f?kw=wapmud]\n";
	s_rtn += "捐赠获取仙玉 qq:1811117272\n Line:txai\n 邮箱：1811117272@qq.com\n官方qq群号:478189825\n";
	//s_rtn += "★数字狗狗☆娱乐无限★\n";
	//s_rtn += "-- [url 天:http://tx1.dogstart.com/txmud/tx/index.jsp]||";
	//s_rtn += "[url 天下 AI 网游:http://tx.wapmud.com/tx/pc.jsp]\n";
	//s_rtn += "[url 烽火超爽武侠:http://fh.wapmud.com/fh/pc.jsp]\n";
	//s_rtn += "[url 论:http://wap.dogstart.com/forum/game_page] --\n";
	//s_rtn += "- [url wap.dogstart.com:http://dogstart.com/wap/index.jsp] -\n";
	return s_rtn;
}
//by caijie 080813
