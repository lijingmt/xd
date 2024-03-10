#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	int count=0;
	sscanf(arg,"%s %d",name,count);
	object me = this_player();
	//object ob=present(name,me,count);
	object ob;
	object env=environment(me);
	string s = "";
	//查找玩家身上与name同名的非会员物品 added by caijie 080815
	array(object) all_ob = all_inventory(me);
	foreach(all_ob,object each_ob){
		if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
			ob = each_ob;
			break;
		}
	}
	//add end
	if(env){
		if(!ob)
			me->write_view(WAP_VIEWD["/emote"],0,0,"你身上没有那样东西。\n");
		else if(!ob->is("item"))
			me->write_view(WAP_VIEWD["/emote"],0,0,"该物品不属于可以拍卖的物品。\n");
		else if(ob->equiped)
			me->write_view(WAP_VIEWD["/emote"],0,0,"身上正在装备的东西无法拍卖。\n");
		else if(ob->query_item_save() == 0)
			me->write_view(WAP_VIEWD["/emote"],0,0,"此物品不能拍卖。\n");
		else if(!ob->query_item_canTrade())
			me->write_view(WAP_VIEWD["/emote"],0,0,"该类物品不能拍卖。\n");
		else if(ob->query_toVip())
			me->write_view(WAP_VIEWD["/emote"],0,0,"会员专属物品不能拍卖。\n");
		else if(ob->query_item_type()=="yushi"&&me->query_level()<=8){
			me->write_view(WAP_VIEWD["/emote"],0,0,"8级以下的玩家不能交易玉石\n");
			return 1;
		}
		else if((ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor")&&ob->item_cur_dura<ob->item_dura)
			me->write_view(WAP_VIEWD["/emote"],0,0,"我们不接受这样的破烂玩意，先拿去修修再来拍吧\n");
		else{
			//物品的描述
			s += ob->query_name_cn()+"\n";
			s += ob->query_picture_url()+"\n";
			s += ob->query_desc()+"\n";
			if(ob->profe_read_limit)
				s+="职业："+ob->profe_read_limit+"\n";
			if(ob->is("equip"))
				s += ob->query_content()+"\n";
			//s += "--------\n";
			s += "输入起始价格(必须)：\n";
			s += "[int sg:...]金[int ss:...]银\n";
			s += "输入一口价(可选)：\n";
			s += "[int eg:...]金[int es:...]银\n";
			s += "[submit 确定:vendue_confirm "+arg+" ...]\n";
			//指令调用的参数：vendue_confirm sgd=x ssv=x egd=x esv=x name count
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
	}
	return 1;
}
