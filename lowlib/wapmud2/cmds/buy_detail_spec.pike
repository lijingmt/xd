#include <command.h>
#include <wapmud2/include/wapmud2.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name;
	int fee;
	if(!arg){
		string s = "";
		s+= "û�������Ʒ\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		return 1;
	}
	sscanf(arg, "%s %d", name,fee);
	if(!name)
	{
		string s = "";
		s+= "û�������Ʒ\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	object ob=clone(ROOT+"/gamelib/clone/item/"+name);
	if(ob){
		string s=ob->query_name_cn()+"\n";
		s+=ob->query_picture_url()+"\n";
		if(ob->query_item_type()!="book")
			s+=ob->query_content? ob->query_content():"";
		s+=ob->query_desc();
		s+="ȷ�����ѣ�"+MUD_MONEYD->query_store_money_cn(fee)+"?\n";
		s+="[ȷ������:buy_goods_spec "+name+" "+fee+"]\n";
		//s+="��������һ�ι���"+ob->query_name_cn()+"����Ŀ����Χһ����ʮ��[int:buy_lots_goods "+name+" ...]\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	else{
		string s = "";
		s+= "û�������Ʒ\n";
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
	}
	return 1;
}
