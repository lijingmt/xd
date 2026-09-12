#include <command.h>
#include <gamelib/include/gamelib.h>
// 三战斗系统：save 保存当前穿戴+技能逻辑 / use 一键切换。
int main(string|zero arg)
{
	object me = this_player();
	string action = "";
	int slot = 0;
	mapping result;
	if(!me)
		return 0;
	if(arg && arg!="")
		sscanf(arg,"%s %d",action,slot);
	if(action=="save" || action=="use"){
		result = action=="save" ?
			BATTLE_SYSTEMD->save_battle_system(me,slot) :
			BATTLE_SYSTEMD->use_battle_system(me,slot);
		string s = "";
		if(!(int)result["ok"]){
			s += (string)result["message"]+"\n";
		}
		else if(action=="save"){
			s += "§y保存成功§r：槽"+(string)slot+"（"+
				BATTLE_SYSTEMD->query_battle_system_title(slot)+
				"）录入"+(string)(int)result["count"]+"件装备与当前技能逻辑。\n";
		}
		else{
			s += "§y切换成功§r：已换上「"+
				(string)result["title"]+"」装备"+
				((string)(int)result["equipped"])+"件，技能逻辑已同步。\n";
			if(sizeof((array)(result["missing"] || ({}))))
				s += "§R以下部件不在背包，未能穿回：§r"+
					((array(string))result["missing"])*"、"+"\n";
		}
		s += "[返回战斗系统:battle_system]|[返回游戏:look]\n";
		write(s);
		return 1;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,
		BATTLE_SYSTEMD->query_battle_system_page(me));
	return 1;
}
