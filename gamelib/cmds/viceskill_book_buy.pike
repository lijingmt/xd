#include <command.h>
#include <gamelib/include/gamelib.h>

#ifndef ITEM_PATH
#define ITEM_PATH ROOT+"/gamelib/clone/item/book/"
#endif

private mapping(string:int) human_books=([
	"liejiajianfeng":1,"yufengjianqi":1,"ningqichengdun1":1,
	"ningqichengdun2":1,"ningqichengdun3":1,"ningqichengdun4":1,
	"ningxinjue":1,"hanbingzhou":1,"jingxinjue1":1,"jingxinjue2":1,
	"jingxinjue3":1,"jingxinjue4":1,"yanbaozhou":1,
	"fengtiandongdi":1,"piaohubuding":1,"zhanyaojue":1,
	"pomoxinfa1":1,"xuantianjianzhen":1,"sihunliepo":1
]);
private mapping(string:int) monst_books=([
	"shixiekuangbao1":1,"shixiekuangbao2":1,"shixiekuangbao3":1,
	"shixiekuangbao4":1,"shixiekuangbao5":1,"suiguzhongji":1,
	"bengliechongzhuang":1,"fangxie":1,"kuanghua1":1,
	"yaoshujiejie":1,"dafengren":1,"nizhaoshu":1,"fushishu":1,
	"shihunshu1":1,"guizong1":1,"guizong2":1,"guizong3":1,
	"guizong4":1,"guizong5":1,"shalu":1,"paoxintigu":1,
	"huanyingcanxiang1":1
]);

//此指令用于技能书的购买
int main(string|zero arg)
{
	object me = this_player();
	string s = "";
	//string s_log = "";
	string type = "";
	string book_name = "";
	int flag = 0;
	int need_yushi = 0;
	int need_money = 0;
	if(!arg || sscanf(arg,"%s %s %d",type,book_name,flag)!=3 ||
	   (flag!=0 && flag!=1) || search(book_name,"..")!=-1 ||
	   search(book_name,"/")!=-1 ||
	   (type=="human" ? !human_books[book_name] :
	    type=="monst" ? !monst_books[book_name] : 1)){
		write("商品不存在或已经下架。\n[返回游戏:look]\n");
		return 1;
	}
	string allowed_type=(string)me->query_raceId();
	object env=environment(me);
	if(allowed_type=="third")
		allowed_type=env ? (string)env->room_race : "";
	if(type!=allowed_type){
		write("这里没有适合你阵营的副技能书。\n[返回游戏:look]\n");
		return 1;
	}
	object book;
	mixed load_err=catch{ book=clone(ITEM_PATH+book_name); };
	if(load_err || !book || (int)book->need_yushi<=0 ||
	   (int)book->need_money<0){
		if(book)
			destruct(book);
		write("商品资料暂时不可用。\n[返回游戏:look]\n");
		return 1;
	}
	if(flag==0){
		s += book->query_name_cn()+"\n";
		s += book->query_picture_url()+"\n"+book->query_desc()+"\n";
		s += "要求职业: "+book->profe_read_limit+"\n"+"要求等级: "+book->level_limit+"\n";
		s += "\n";
		s += "价格:"+book->need_yushi+"碎玉, "+book->need_money+"黄金\n";
		s += "[购买:viceskill_book_buy "+type+" "+book_name+" 1]\n";
	}
	else if(flag==1){
		need_yushi = book->need_yushi;
		need_money = (book->need_money)*100;
		s += ITEMSD->buy_items(book,need_yushi,1,need_money);
		string consume_time = MUD_TIMESD->get_mysql_timedesc();
		string cost = ""+need_yushi+"|suiyu";
		//s_log += "insert xd_consume (consume_time,user_id,user_name,area,type,cost,get_item,get_item_num,get_item_cn,cost_reb) values ('"+consume_time+"','"+me->query_name()+"','"+me->query_name_cn()+"','"+GAME_NAME_S+"','book','"+cost+"','"+book_name+"',1,'碎玉',"+need_yushi+");\n";
	}
	if(book && environment(book)!=me)
		destruct(book);
	/*
	if(s_log != ""){
		string now=ctime(time());
		Stdio.append_file(ROOT+"/log/fee_log/yushi_use-"+MUD_TIMESD->get_year_month_day()+".log",s_log);
	}
	*/
	s += "[返回:viceskill_book_buy_list "+type+"]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
