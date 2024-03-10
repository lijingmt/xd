#include <command.h>
#include <gamelib/include/gamelib.h>

int main(string arg)
{
	object me = this_player();
	string s = "";
	string item_name = "";
	int count,flag;
	string tmp = ITEMSD->daoju_list(me,"equip_xiangqian_confirm "+arg,"baoshi");//列出玩家背包里所有的宝石
	if(tmp!=""){
	//有宝石
		sscanf(arg,"%s %d %d",item_name,count,flag);
		object item = present(item_name,me,count);
		s += item->query_name_cn()+"\n";;
		s += item->query_picture_url()+"\n"+item->query_desc()+"\n";
		s += item->query_content()+"\n";
		s += "--------\n\n";
		s += "请选择您要镶嵌的宝石：\n";
		s += "\n";
		s += tmp;
	}
	else{
	//没宝石
		s += "您没有宝石，不能帮你镶嵌\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
