#include <command.h>
#include <gamelib/include/gamelib.h>
// 帮派幻境入口：enter 先把玩家路由到门房，再进本帮副本；
// attack 从副本内对妖影发起攻击。
int main(string|zero arg)
{
	object me = this_player();
	string action = "";
	mapping result;
	object npc;
	if(!me)
		return 0;
	if(!me->bangid){
		write("你还没有加入帮派。\n[返回游戏:look]\n");
		return 1;
	}
	if(arg && arg!="")
		sscanf(arg,"%s",action);
	if(action=="enter"){
		result = BANGPAI_EXTD->enter_bang_illusion(me);
		if(!(int)result["ok"]){
			// move_gate：玩家还不在门房，先路由过去（跨Worker
			// 由静态房亲和收敛），到达后再点一次进入副本。
			if((string)result["message"]=="move_gate"){
				me->move((object)(
					ROOT+"/gamelib/d/bangpai/illusion_gate"));
				me->command("look");
				return 1;
			}
			write((string)result["message"]+"\n"+
				"[返回帮派幻境:bang_illusion]\n");
			return 1;
		}
		me->command("look");
		return 1;
	}
	if(action=="attack"){
		if(me->query_in_combat()){
			write("你已经在战斗中。\n[返回战斗:flushview]\n");
			return 1;
		}
		npc = 0;
		foreach(all_inventory(environment(me)),object ob)
			if(ob && functionp(ob->is_bangpai_shade) &&
			   (int)ob->is_bangpai_shade() &&
			   ob->can_be_attacked(me)){
				npc = ob;
				break;
			}
		if(!npc){
			write("这里没有你可攻击的妖影。\n[返回:look]\n");
			return 1;
		}
		mixed err = catch{
			me->kill(npc,0);
			if(!npc->query_in_combat())
				npc->_fight(me);
		};
		if(err)
			write("攻击失败，请稍后再试。\n[返回:look]\n");
		else
			me->command("look");
		return 1;
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,
		BANGPAI_EXTD->query_bang_illusion_page(me));
	return 1;
}
