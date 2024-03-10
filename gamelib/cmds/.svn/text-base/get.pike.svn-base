#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count);
	//判断身上物品是否超过60件
	if(ob&&this_player()->if_over_load(ob)){
		string tmp = "你的背包已满，无法执行此操作，请返回。\n";       
		tmp+="[返回:look]\n";
		write(tmp);
		return 1;
	}
	int flag = 0;//拾取状态标志
	//团队掉落标示物品状态 add by calvin 0320
	if(ob&&ob->item_whoCanGet==this_player()->query_term())
		flag = 1;	
	else if(ob&&ob->item_whoCanGet!=this_player()->query_term()){
		if( (time()-ob->item_TimewhoCanGet)>=120 )
			//非打落装备者拾取，但超过了保护时间，可以拾取
			flag = 1;
		else
			flag = 2;//团队保护标示
	}
	//团队掉落标示物品状态 add by calvin 0320
	
	//个人掉落物品标示判定
	if(ob&&ob->item_whoCanGet==this_player()->query_name())
		flag = 1;//是打落装备者自己拾取，状态为1
	else if(ob&&ob->item_whoCanGet!=this_player()->query_name()){
		if( (time()-ob->item_TimewhoCanGet)>=120 )
			//非打落装备者拾取，但超过了保护时间，可以拾取
			flag = 1;
	}
	//如果是被扔弃的物品，直接可以拾取
	if(ob&&ob->item_whoCanGet=="1")
		flag = 1;
	//可以直接拾取的状态
	if( ob && !ob->is("npc") && flag==1){
		if(ob->query_item_canGet()==1)
		{
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
