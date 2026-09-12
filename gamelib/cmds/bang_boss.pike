#include <command.h>
#include <gamelib/include/gamelib.h>
// 帮派BOSS入口：summon 召唤 / enter 进演武场 / attack 攻击 / 页面查看。
int main(string|zero arg)
{
	object me = this_player();
	string action = "";
	mapping result;
	if(!me)
		return 0;
	if(!me->bangid){
		write("你还没有加入帮派。\n[返回游戏:look]\n");
		return 1;
	}
	if(arg && arg!="")
		sscanf(arg,"%s",action);
	if(action=="summon"){
		if(me->query_in_combat()){
			write("交战中不能召唤，请脱离战斗后再试。\n"+
				"[返回战斗:flushview]\n");
			return 1;
		}
		result = BANGPAI_EXTD->summon_bang_boss(me);
		if(!(int)result["ok"]){
			write((string)result["message"]+"\n"+
				"[返回帮派BOSS:bang_boss]\n");
			return 1;
		}
		result = BANGPAI_EXTD->enter_bang_boss_arena(me);
		if(!(int)result["ok"])
			write((string)result["message"]+"\n");
		me->command("look");
		return 1;
	}
	if(action=="enter"){
		result = BANGPAI_EXTD->enter_bang_boss_arena(me);
		if(!(int)result["ok"]){
			write((string)result["message"]+"\n"+
				"[返回帮派BOSS:bang_boss]\n");
			return 1;
		}
		me->command("look");
		return 1;
	}
	if(action=="attack"){
		result = BANGPAI_EXTD->attack_bang_boss(me);
		if(!(int)result["ok"]){
			write((string)result["message"]+"\n"+
				"[返回:look]\n");
			return 1;
		}
		me->command("look");
		return 1;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,
		BANGPAI_EXTD->query_bang_boss_page(me));
	return 1;
}
