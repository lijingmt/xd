#include <command.h>
#include <gamelib/include/gamelib.h>

#define CHOICE_TOKEN "ancient_skill_choice_token"
#define CHOICE_LOG ROOT "/log/no_level_equipment_recycle.log"

private object|zero query_choice_token(object player)
{
	foreach(all_inventory(player),object item)
		if(item && item->query_name()==CHOICE_TOKEN &&
		   item->is("combine_item") && (int)item->amount>0)
			return item;
	return 0;
}

private string safe_log_field(string|zero value)
{
	string result = value || "";
	result = replace(result,"\r"," ");
	result = replace(result,"\n"," ");
	result = replace(result,"|","/");
	if(sizeof(result)>80)
		result = result[..79];
	return result;
}

private void consume_one_token(object token)
{
	if((int)token->amount>1)
		token->amount = (int)token->amount-1;
	else
		destruct(token);
}

private void render_choices(object player,array(string) skill_ids)
{
	string profession = (string)player->query_profeId();
	string profession_cn = ANCIENT_SKILLD->query_profession_name(profession);
	write("【太古传承择卷】\n");
	write("当前职业："+profession_cn+"。请选择一本太古技能书；"+
		"选择后仍需达到90级，并按原有技能书规则学习。\n\n");
	foreach(skill_ids,string skill_id){
		string display = ANCIENT_SKILLD->query_colored_name(skill_id);
		if(player->skills[skill_id])
			write(display+"（已学会）\n");
		else if(present(skill_id,player))
			write(display+"（背包已有此书）\n");
		else
			write("[选择"+display+":ancient_skill_choice "+skill_id+"]\n");
	}
	write("\n[返回背包:inventory]|[返回游戏:look]\n");
}

int main(string|zero arg)
{
	object player = this_player();
	object|zero token;
	object|zero book;
	array(string) skill_ids;
	string profession;
	string skill_id = arg || "";
	mixed err;
	if(!player)
		return 0;
	token = query_choice_token(player);
	if(!token){
		write("你没有太古传承择卷。\n[返回背包:inventory]\n");
		return 1;
	}
	profession = (string)player->query_profeId();
	skill_ids = ANCIENT_SKILLD->query_profession_skill_ids(profession);
	if(!sizeof(skill_ids)){
		write("当前职业暂未配置太古传承，择卷不会消耗，请联系管理员。\n"+
			"[返回背包:inventory]\n");
		return 1;
	}
	if(skill_id==""){
		render_choices(player,skill_ids);
		return 1;
	}
	if(sizeof(skill_id)>64 || search(skill_id,"/")!=-1 ||
	   search(skill_id,"..")!=-1 || search(skill_ids,skill_id)==-1){
		write("只能选择当前职业列表中的太古技能，择卷没有消耗。\n"+
			"[重新选择:ancient_skill_choice]\n");
		return 1;
	}
	if(player->skills[skill_id]){
		write("你已经学会这项太古技能，请选择其他传承，择卷没有消耗。\n"+
			"[重新选择:ancient_skill_choice]\n");
		return 1;
	}
	if(present(skill_id,player)){
		write("你的背包里已有这本太古技能书，请选择其他传承，择卷没有消耗。\n"+
			"[重新选择:ancient_skill_choice]\n");
		return 1;
	}
	err = catch {
		book = clone(ROOT+"/gamelib/clone/item/book/"+skill_id);
	};
	if(err || !book){
		write("技能书生成失败，择卷没有消耗，请稍后重试。\n"+
			"[重新选择:ancient_skill_choice]\n");
		return 1;
	}
	if(!book->bind_to_account(player) || !book->move(player) ||
	   environment(book)!=player){
		destruct(book);
		write("背包暂时无法接收技能书，择卷没有消耗，请整理后重试。\n"+
			"[返回背包:inventory]\n");
		return 1;
	}
	consume_one_token(token);
	Stdio.append_file(CHOICE_LOG,(string)time()+"|ancient_skill_chosen|"+
		safe_log_field(player->query_name())+"|profession="+
		safe_log_field(profession)+"|skill="+safe_log_field(skill_id)+"\n");
	write("你选择了"+ANCIENT_SKILLD->query_colored_name(skill_id)+
		"，对应技能书已放入背包。\n"+
		"[立即学习:read "+skill_id+" 0]|[返回背包:inventory]\n");
	return 1;
}
