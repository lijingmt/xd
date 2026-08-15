#include <command.h>
#include <gamelib/include/gamelib.h>

// 统一的掉落归属判定，单件拾取与批量拾取必须共用，避免批量入口
// 绕过本人/队伍的120秒保护期。1=可拾取，2=其他团队保护，0=个人保护。
int query_pickup_protection_flag(object player,object ob)
{
	int flag=0;
	if(!player || !ob)
		return 0;
	if(ob->item_whoCanGet==player->query_term())
		flag=1;
	else if(ob->item_whoCanGet!=player->query_term()){
		if(time()-ob->item_TimewhoCanGet>=120)
			flag=1;
		else
			flag=2;
	}
	if(ob->item_whoCanGet==player->query_name())
		flag=1;
	else if(ob->item_whoCanGet!=player->query_name()){
		if(time()-ob->item_TimewhoCanGet>=120)
			flag=1;
	}
	if(ob->item_whoCanGet=="1")
		flag=1;
	return flag;
}

int main(string|zero arg)
{
	string name=arg;
	int count;
	// arg 可能为 0（command_hook 偶发误路由时），sscanf(0,...) 会抛
	// "Bad argument 1 to sscanf"。look/查看类命令不应触发 get，但
	// 历史线上日志显示 command_hook 在某些情况下把命令路由到了 get。
	if(!arg || !stringp(arg) || sizeof(arg)==0){
		write("你要捡起什么物品？\n[返回:look]\n");
		return 1;
	}
	sscanf(arg,"%s %d",name,count);
	object|zero ob=present(name,environment(this_player()),count);
	if(ob && !LOGICALZONED->can_action("drop",this_player(),ob))
		ob = 0;
	//判断身上物品是否超过60件
	if(ob&&this_player()->if_over_load(ob)){
		string tmp = "你的背包已满，无法执行此操作，请返回。\n";       
		tmp+="[返回:look]\n";
		write(tmp);
		return 1;
	}
	int flag=query_pickup_protection_flag(this_player(),ob);
	//可以直接拾取的状态
	if( ob && !ob->is("npc") && flag==1){
		if(ob->query_item_canGet()==1)
		{
			if(functionp(ob->bind_to_account) &&
			   !ob->bind_to_account(this_player())){
				write("这件账号绑定物品不属于当前注册账号，无法拾取。\n");
				return 1;
			}
			if(this_player()->query_term()!=""&&this_player()->query_term()!="noterm")
				if(TERMD->query_termId((string)this_player()->query_term()))
					//团队公告谁获得了什么物品
					TERMD->term_tell(this_player()->query_term(),"\n"+this_player()->query_name_cn()+" 获得了 "+ob->query_short()+"\n");
			this_player()->write_view_tmp(WAP_VIEWD["/get"],ob);
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/get.log",now[0..sizeof(now)-2]+":"+this_player()->query_name_cn()+"("+this_player()->query_name()+"):"+ob->name_cn+"("+ob->name+")\n");
			remove_call_out(ob->remove);
			//被拾取后，将判断字段置位1
			ob->item_whoCanGet="1";
			ob->item_TimewhoCanGet=1;
			if(ob->is("combine_item"))
				ob->move_player(this_player()->query_name());
			else
				ob->move(this_player());
		}
		else
			this_player()->write_view(WAP_VIEWD["/get_inmoveable"],ob);
	}
	else if( ob && !ob->is("npc") && flag==0){
		this_player()->write_view(WAP_VIEWD["/get_protect"],ob);
	}
	else if( ob && !ob->is("npc") && flag==2){
		this_player()->write_view(WAP_VIEWD["/get_term"],ob);
	}
	else
		this_player()->write_view(WAP_VIEWD["/get_notfound"],ob);
	return 1;
}
