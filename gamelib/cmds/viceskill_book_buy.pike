#include <command.h>
#include <gamelib/include/gamelib.h>

#define ITEM_PATH ROOT+"/gamelib/clone/item/book/"

//��ָ�����ڼ�����Ĺ���
int main(string arg)
{
	object me = this_player();
	string s = "";
	//string s_log = "";
	string type = "";
	string book_name = "";
	int flag = 0;
	int need_yushi = 0;
	int need_money = 0;
	sscanf(arg,"%s %s %d",type,book_name,flag);
	object book=clone(ITEM_PATH+book_name);
	if(flag==0){
		s += book->query_name_cn()+"\n";
		s += book->query_picture_url()+"\n"+book->query_desc()+"\n";
		s += "Ҫ��ְҵ: "+book->profe_read_limit+"\n"+"Ҫ��ȼ�: "+book->level_limit+"\n";
		s += "\n";
		s += "�۸�:"+book->need_yushi+"����, "+book->need_money+"�ƽ�\n";
		s += "[����:viceskill_book_buy "+type+" "+book_name+" 1]\n";
	}
	else if(flag==1){
		need_yushi = book->need_yushi;
		need_money = (book->need_money)*100;
		s += ITEMSD->buy_items(book,need_yushi,1,need_money);
		string consume_time = MUD_TIMESD->get_mysql_timedesc();
		string cost = ""+need_yushi+"|suiyu";
		//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','book','"+cost+"','"+book_name+"',1,'����',"+need_yushi+");\n";
	}
	/*
	if(s_log != ""){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
	}
	*/
	s += "[����:viceskill_book_buy_list "+type+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
