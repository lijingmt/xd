#include <command.h>
#include <gamelib/include/gamelib.h>

private int safe_combat_id(string value)
{
	return value!="" && search(value," ")==-1 && search(value,"\t")==-1 &&
		search(value,"\n")==-1 && search(value,"]")==-1 &&
		search(value,":")==-1;
}

private string challenge_view(object me,mapping progress)
{
	if((string)progress["kind"]!="boss")
		return "当前一难不是首领战。\n[返回四十九难:illusion_hidden]\n";
	object room=environment(me);
	if(!room)
		return "你处于虚空中，无法确认首领。\n[返回游戏:look]\n";
	mapping(string:int) counts=([]);
	string actions="";
	foreach(all_inventory(room,me),object npc){
		if(!npc || !npc->is("npc") ||
		   (file_name(npc)/"#")[0]!=ROOT+(string)progress["target_path"])
			continue;
		string combat_id=(string)npc->query_name();
		if(!safe_combat_id(combat_id)) continue;
		int index=(int)counts[combat_id];
		counts[combat_id]=index+1;
		actions+="[⚔ 挑战"+(string)npc->query_name_cn()+":kill "+
			combat_id+" "+(string)index+"]\n";
	}
	if(actions=="")
		return "当前房间尚未刷新任务首领；请等待刷新后重新查找，本次不会攻击错误目标。\n"+
			"[重新查找:illusion_hidden challenge]|[返回游戏:look]\n";
	return "已经从当前房间真实对象确认目标：\n"+actions+
		"[返回四十九难:illusion_hidden]|[返回游戏:look]\n";
}

private string progress_view(object me,mapping progress,string notice)
{
	string s="【S1隐藏职业·照命】\n";
	if(notice!="") s+=notice+"\n";
	if(!(int)progress["ok"])
		return s+(string)progress["message"]+
			"\n[返回幻境任务:illusion_realm]|[返回游戏:look]\n";
	if((int)progress["completed"])
		return s+"七卷四十九难已经全部完成。五段人生不是借来的力量，而是你亲自走过的来路。\n"+
			"[查看技能:myskills]|[查看装备:myweapon]|[返回游戏:look]\n";
	int trial=(int)progress["trial"];
	int done=(int)progress["done"];
	int required=(int)progress["required"];
	s+="第"+(string)(int)progress["volume"]+"卷·"+
		(string)progress["volume_title"]+"\n";
	s+="【第"+(string)trial+"/49难】"+
		(string)progress["target_name"]+"\n";
	if((string)progress["kind"]=="hunt")
		s+="真实狩猎："+(string)progress["target_name"]+" "+
			(string)done+"/"+(string)required+"只\n";
	else if((string)progress["kind"]=="visit")
		s+="真实探索："+(string)progress["target_name"]+" "+
			(string)done+"/1处\n";
	else
		s+="真实首领："+(string)progress["target_name"]+" "+
			(string)done+"/1只\n";
	if((int)progress["ready"])
		s+="§g本难目标已完成。§r\n[领取并继续:illusion_hidden claim]\n";
	else{
		s+="[▶ 一键前往目标:illusion_hidden go]\n";
		if((string)progress["kind"]=="hunt")
			s+="[挂机至本难完成:illusion_hidden hunt]\n";
		else if((string)progress["kind"]=="boss")
			s+="[查找并挑战首领:illusion_hidden challenge]\n";
	}
	if((int)progress["reward_index"]>=0)
		s+="本难结算将获得一件账号绑定【寰极·照命】专属套装。\n";
	return s+"[返回幻境任务:illusion_realm]|[返回游戏:look]\n";
}

int main(string|zero arg)
{
	object me=this_player();
	array(string) parts=arg ? String.trim_all_whites(arg)/" " : ({});
	if(!me){ write("人物会话不存在。\n"); return 1; }
	if(sizeof(parts) && parts[0]=="claim"){
		mapping result=ILLUSION_HIDDEN_PROFESSIOND->claim(me);
		write(progress_view(me,ILLUSION_HIDDEN_PROFESSIOND->query_progress(me),
			(string)result["message"]));
		return 1;
	}
	if(sizeof(parts) && parts[0]=="go"){
		mapping result=ILLUSION_HIDDEN_PROFESSIOND->navigate(me);
		write(progress_view(me,ILLUSION_HIDDEN_PROFESSIOND->query_progress(me),
			(string)result["message"]));
		return 1;
	}
	if(sizeof(parts) && parts[0]=="hunt"){
		mapping result=ILLUSION_HIDDEN_PROFESSIOND->start_hunt(me);
		write(progress_view(me,ILLUSION_HIDDEN_PROFESSIOND->query_progress(me),
			(string)result["message"]));
		return 1;
	}
	if(sizeof(parts) && parts[0]=="challenge"){
		mapping progress=ILLUSION_HIDDEN_PROFESSIOND->query_progress(me);
		write((int)progress["ok"] ? challenge_view(me,progress) :
			(string)progress["message"]+"\n[返回游戏:look]\n");
		return 1;
	}
	write(progress_view(me,ILLUSION_HIDDEN_PROFESSIOND->query_progress(me),""));
	return 1;
}
