#include <command.h>
#include <gamelib/include/gamelib.h>
#include <gamelib.h>

#define RANGE 100
#define NAME 0
#define NAMECN 1
#define VALUE 2
#define PAGELEN 10

string query_race_tag(string race_id,void|string profession_id)
{
	if(race_id == "monst")
		return "【妖】";
	if(race_id == "third")
	{
		if(profession_id=="zhenyue")
			return "【越】";
		if(profession_id=="tianxiang")
			return "【象】";
		if(profession_id=="lingyi")
			return "【医】";
		if(profession_id=="wuxiang")
			return "【无】";
		if(profession_id=="taiji")
			return "【极】";
		return "【方】";
	}
	return "【仙】";
}

string query_honer_top_name(string race_id)
{
	if(race_id == "monst")
		return "妖气";
	if(race_id == "third")
		return "灵气";
	return "仙气";
}

int main(string|zero arg)
{
	object me = this_player();
	string act,value,re="";
	NEWBIED->record_action(me,"top");
	//re += "[记录:record list 1]|[好友:friend list 1]|[公会:guild]|[在线:onlineuser]|排行榜\n";
	if(!arg)
		arg = "start";
	//look_top list 等级 1
	if(sscanf(arg,"%s %s",act,value)!=2){
		act = "start";
		value = "";
	}
	//----------------------
	string zhenying=query_race_tag(me->query_raceId(),me->query_profeId());
	string topname = me->query_name_cn()+"("+me->query_level()+"级)"+zhenying;

	TOPTEN->try_top(me->query_name(),topname,"等级",me->query_level());
	TOPTEN->try_top(me->query_name(),topname,"富翁",me->query_account());
	TOPTEN->try_top(me->query_name(),topname,
		query_honer_top_name(me->query_raceId()),me->honerpt);
	/*
	TOPTEN->try_top(me->query_name(),topname,"攻击",me->query_fight_attack());
	TOPTEN->try_top(me->query_name(),topname,"防御",me->query_defend_power());
	TOPTEN->try_top(me->query_name(),topname,"躲闪",(int)me->query_phy_dodge());
	TOPTEN->try_top(me->query_name(),topname,"招架",(int)me->query_phy_parry());
	TOPTEN->try_top(me->query_name(),topname,"命中",(int)me->query_phy_hitte());
	TOPTEN->try_top(me->query_name(),topname,"暴击",(int)me->query_phy_baoji());
	*/
	TOPTEN->try_top(me->query_name(),topname+"("+me->all_fee+")("+me->name+")","捐赠",(int)me->all_fee);
	//string powers = MANAGERD->checkpower(me->name);
	//if(powers=="admin"||powers=="assist")
	//	TOPTEN->try_top(me->query_name(),topname,"捐赠",(int)me->history_tongbao);
	//----------------------
	switch(act)
	{
		case "list":
		string type;
		int page = 1;
		type = value;
		if(!value || sscanf(value,"%s %d",type,page)!=2 || page<1){
			re += "排行榜参数无效。\n[返回上级:look_top]\n";
			break;
		}
		re += "【"+type+"排行榜】\n";
		array record = TOPTEN->get_top(type,RANGE,me->query_name());
		string lr = "";
		for(int i=(page-1)*PAGELEN;i<sizeof(record)&&i<(page-1)*PAGELEN+PAGELEN;i++)
                {
			string record_value;
			if(type=="等级" || type=="捐赠")
				record_value=(string)record[i][VALUE];
			else if(type=="富翁")
				record_value=MUD_MONEYD->query_money_for_paihang(
					(int)record[i][VALUE]);
			else
				record_value=format_game_number((int)record[i][VALUE]);
			lr += sprintf("第%d名|%s|%s：%s\n",i+1,
				record[i][NAMECN],type,record_value);
                }
 		if(lr&&sizeof(lr)){
			re += lr;
			re += "第";
			for(int i=1;i<=sizeof(record)/PAGELEN+1;i++)
			{
				if(i==page)
					re += i;
				else
                                	re += sprintf("[%d:look_top list %s %d]",i,type,i);
					//re += sprintf("[%d:record list %d]",i,i);
			}
			re += "页\n";
		}
		else
			re += "暂无相关记录。\n";
                re += "[返回上级:look_top]\n";
              	break;
		case "start":
		default:
		re += "【排行榜】\n";
		re += "----------------\n";
		re += "[等级排行榜:look_top list 等级 1]\n";
		re += "[富翁排行榜:look_top list 富翁 1]\n";
		re += "[仙气排行榜:look_top list 仙气 1]\n";
		re += "[妖气排行榜:look_top list 妖气 1]\n";
		re += "[灵气排行榜:look_top list 灵气 1]\n";
		/*
		re += "[攻击排行榜:look_top list 攻击 1]\n";
		re += "[防御排行榜:look_top list 防御 1]\n";
		re += "[躲闪排行榜:look_top list 躲闪 1]\n";
		re += "[招架排行榜:look_top list 招架 1]\n";
		re += "[命中排行榜:look_top list 命中 1]\n";
		re += "[暴击排行榜:look_top list 暴击 1]\n";
		*/
		string powers = MANAGERD->checkpower(me->name);
		if(powers=="admin"||powers=="assist")
			re += "[捐赠排行榜:look_top list 捐赠 1]\n";
		re += "----------------\n";
		break;
	}
	re += "[返回游戏:look]\n";
	write(re);
	return 1;
}
