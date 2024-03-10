#include <command.h>
#include <gamelib/include/gamelib.h>
#define USER_REPLY  ROOT "/log/reply1.csv" 

int main(string arg)
{
	string s = "";
	int questionNum;
	string choice = "";
	object me = this_player();
	string s_log = "";
	string type = "";//问卷标识
	int totalQue = 0;//该问卷总共有的问题数量
	string ans = "";//玩家所选的答案
	int serialNum = 0;//第几个问题
	sscanf(arg,"%s %d %s %d",type,serialNum,ans,totalQue);
	//type表示该问卷是那份问卷，如：以参加过第一份问卷调查则记录为me["/diaochaFlag][1]==1
	if(me["/diaochaFlag"][type]&&me["/diaochaFlag"][type]==1){
		s += "你已经做过仙道问卷调查了，每位玩家限做问卷一次，请返回。\n\n";
		s += "[返回:game_detail]";
		s += "\n[返回游戏:look]\n";
		write(s);
		return 1;
	}
	me["/diaochaTmp"] += ans+",";//调查结果
	array(string) tmp = me["/diaochaTmp"]/",";
	if(serialNum>=totalQue && totalQue==(sizeof(tmp)-1)){
	//答完所有问题 
		me["/diaochaFlag"][type] = 1;
		s_log += GAME_NAME_CN+","+me->query_name()+","+me->query_name_cn()+","+me->query_level()+","+MUD_TIMESD->get_mysql_timedesc()+","+me["/diaochaTmp"]+"\n";
		Stdio.append_file(USER_REPLY,s_log);
		me["/diaochaTmp"] = "";
		s += "您已经成功完成本次调查问卷，并奖励您\n";
		s += DIAOCHAD->gain_reward(type,me);//获得奖励
		s += "谢谢您对仙道游戏的支持！\n";
		s += "\n[返回:game_detail]";
		s += "\n[返回游戏:look]\n";
		me->command("save");
		write(s);
		return 1;
	}
	else{
	//继续答题
	//werror("----size = "+sizeof(tmp)+"--serialNum="+serialNum+"--"+me["/diaochaTmp"]+"--\n");
		if((sizeof(tmp)-1)==serialNum){
			serialNum++;
			s += DIAOCHAD->get_question(type,serialNum,"diaocha_detail",totalQue);
		}
		else 
			s += "问题出错，请重新做问卷\n";
	}
	s += "\n[返回:game_detail]";
	s += "\n[返回游戏:look]\n";
	write(s);
	return 1;
}


