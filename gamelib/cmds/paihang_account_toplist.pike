#include <command.h>
#include <gamelib/include/gamelib.h>  
//此指令显示财富的排行
int main(string arg)
{
	string s = "";
	object me=this_player();
	s += "财富排行榜：\n";
	/*
	array(mapping(string:mixed)) top_list = PAIHANGD->query_account_toplist();
	if(top_list && sizeof(top_list)){
		for(int i=0;i<sizeof(top_list);i++){
			string name_cn = top_list[i]["name_cn"];
			string raceId = top_list[i]["raceId"];
			string profeId = top_list[i]["profeId"];
			string profe_cn = me->query_profe_cn(profeId);
			int level = (int)top_list[i]["level"];
			int bangid = (int)top_list[i]["bangid"];
			int account = (int)top_list[i]["account"];
			//string account_cn = MUD_MONEYD->query_money_for_paihang(account);
			if(name_cn && sizeof(name_cn)){
				s += (i+1)+"．["+name_cn+":paihang_view_player "+name_cn+" "+raceId+" "+profeId+" "+level+" "+bangid+" 1]\n";//（"+account+"）\n";
			}
		}
	}
	else
		s += "暂未发榜\n";
	*/
	//s += "[刷新排行榜:paihang_update_account_toplist]\n";
	s += "暂未发榜\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[返回游戏:look]\n";
	//write(s);
	return 1;
}
