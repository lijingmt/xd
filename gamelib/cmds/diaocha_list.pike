#include <command.h>
#include <gamelib/include/gamelib.h>
#define ASK "txonline/data/ask1.csv" 
#define USER_REPLY  ROOT "log/reply1.csv" 

int main(string arg)
{
	object me = this_player();
	string s = "";
	string type = "";//问卷标识
	int totalQue = 0;//该问卷总共有的问题数量
	sscanf(arg,"%s %d",type,totalQue);
	//type表示该问卷是那份问卷，如：以参加过第一份问卷调查则记录为me["/diaochaFlag][1]==1
	if(!me["/diaochaFlag"]){
		me["/diaochaFlag"] = ([]);
		if(!me["/diaochaFlag"][type]){
			me["/diaochaFlag"][type] = 0;
		}
	}
	if(me["/diaochaFlag"][type]==1){
		s = "你已经做过仙道问卷调查了，每位玩家限做问卷一次，请返回。\n \n";
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	else{
		me["/diaochaTmp"] = ""; 
		s = "仙道问卷调查：\n每位玩家限做问卷一次，凡完整的回答问卷中的问题，即可获得特殊药品及经验奖励。\n";
		s += DIAOCHAD->get_question(type,1,"diaocha_detail",totalQue);
		me->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
}


