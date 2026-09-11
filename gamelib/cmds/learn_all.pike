#include <command.h>
#include <gamelib/include/gamelib.h>
// 一键学习：背包中所有"本职业可学且尚未学过"的技能书/配方/卷轴/
// 图样/图纸一次性读完。逐本走物品自身 read() 的全部校验（等级、
// 职业、前置技能、熟练度），不满足条件的跳过并归类计数，绝不通融。
int main(string|zero arg)
{
	object me=this_player();
	int learned=0;
	int already=0;
	int blocked=0;
	int books=0;
	array(string) learned_names=({});
	if(!me)
		return 0;
	if(me->query_in_combat()){
		write("交战中不能整理书卷，请脱离战斗后再试。\n"+
			"[返回战斗:flushview]\n");
		return 1;
	}
	foreach(all_inventory(me),object ob){
		mixed result;
		string name_cn;
		if(!ob || !functionp(ob->query_item_type) ||
		   (string)ob->query_item_type()!="book")
			continue;
		if(ob->read_flag!=1)
			continue;
		books++;
		result=catch{ ob->read(); };
		if(result){
			blocked++;
			continue;
		}
		// read()的返回码与read命令一致：1=学成新技能；2/11=已会；
		// 3-10=等级/职业/前置/熟练度不满足；0=失败。
		name_cn="";
		if(functionp(ob->query_name_cn))
			name_cn=(string)ob->query_name_cn();
		// read()置read_flag=0表示消耗成功；据此区分学成与否。
		if(ob->read_flag==0){
			learned++;
			if(sizeof(learned_names)<15 && name_cn!="")
				learned_names+=({name_cn});
		}
		else
			already++;
	}
	if(!books){
		write("背包里没有可学习的书卷。\n[返回游戏:look]\n");
		return 1;
	}
	string s="【一键学习】共检查"+books+"本书卷：新学"+learned+"本"+
		(already+blocked>0 ? "，跳过"+(already+blocked)+"本"+
			"（已学会或等级/职业/前置不满足）" : "")+"。\n";
	foreach(learned_names,string one)
		s+="· "+one+"\n";
	if(learned>0){
		if(!me->save_with_result()){
			s+="⚠ 存档失败，请重新登录确认学习结果。\n"+
				"[返回游戏:look]\n";
			write(s);
			return 1;
		}
		NEWBIED->record_book_read(me);
	}
	s+="[继续清理书卷:book_cleanup]|[返回游戏:look]\n";
	write(s);
	return 1;
}
