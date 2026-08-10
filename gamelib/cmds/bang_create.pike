#include <command.h>
#include <gamelib/include/gamelib.h>

private int rollback_create_cost(object player,mapping token_removal,
	int before_wallet,int before_physical,int before_money)
{
	int ok=1;
	if((int)player->query_account()<before_money)
		player->add_account(before_money-(int)player->query_account());
	if(!YUSHID->rollback_yushi_payment(player,before_wallet,before_physical,
	   "bang_create_rollback"))
		ok=0;
	if(!player->rollback_combine_item_transaction(token_removal))
		ok=0;
	if(!player->save_with_result())
		ok=0;
	return ok;
}

int main(string|zero arg)
{
	object me = this_player();
	string s = "开帮立派:\n(请注意，一切与政治，粗口，非法字符相关的帮派名，一律删无赦)\n";
	int level = 0;
	object ob = present("kaibanglingpai",me,0);//检查玩家身上是否有开帮令牌
	if(!ob){
		s += "很抱歉,您没有\"开帮令牌\"，不能建帮立派，请准备好再来吧.\n";
	}
	else if(me->query_level()<35){
		s += "开帮立派需要35级以上，你再努把力吧\n";
	}
	else if(!YUSHID->have_enough_yushi(me,100)){
		s += "玉石数量不足, 不能建立帮派. 请准备好了再来吧!\n";
		s += "\n\n";
		s += "[直接捐赠:add_szx_fee]\n";
	}
	else if(me->query_account()<100000){
		s += "开帮需要1000金，你身上钱不够\n";
	}
	else if(me->bangid != 0){
		s += "你已经在另一个帮派里了，无法开帮立派\n";
	}
	else if(arg && sizeof(arg)>0 && sizeof(arg)<12){
		arg = filter_msg(arg);
		int before_wallet=ACCOUNT_WALLETD->query_balance(me);
		int before_physical=YUSHID->query_physical_all_num(me);
		int before_money=(int)me->query_account();
		mapping(string:mixed) token_removal=
			me->remove_combine_item_transaction("kaibanglingpai",1);
		if(!(int)token_removal["ok"]){
			write("开帮令牌扣除失败，请稍后重试。\n[返回游戏:look]\n");
			return 1;
		}
		if(!YUSHID->pay_yushi(me,100)){
			me->rollback_combine_item_transaction(token_removal);
			write("玉石扣除失败，开帮令牌未消耗。\n[返回游戏:look]\n");
			return 1;
		}
		me->del_account(100000);
		if(!me->save_with_result()){
			int restored=rollback_create_cost(me,token_removal,before_wallet,
				before_physical,before_money);
			write(restored ? "人物存档失败，建帮费用和令牌已退回。\n" :
				"建帮费用恢复异常，请立即联系客服。\n");
			return 1;
		}
		int be = BANGD->create_bang(me,arg);
		//create_bang()返回 1：建立成功
		//                  0：建立失败
		//                  2：你已经在另一个帮会里了
		if(be == 1){
			if(!me->save_with_result())
				werror("[BANG] 严重: 帮派创建成功但人物存档失败 player=%s bang=%s\n",
					(string)me->query_name(),arg);
			string now = ctime(time());
			s += "恭喜您! \n";
			s += "你建立了帮派<"+arg+">:\n";
			s += "你作为帮主，可以在 我的帮派->管理帮派 里修改你的帮公告，帮简介，帮派等级称谓\n";
			Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+"):建立了帮派<"+arg+">\n");
		}
		else if(be == 0){
			rollback_create_cost(me,token_removal,before_wallet,before_physical,
				before_money);
			s += "你的输入有问题或者此帮派名已被申请，请重新更换名称后再试试\n";
			s += "请输入帮派名称:\n";
			s += "[bang_create ...]\n";
		}
		else if(be == 2){
			rollback_create_cost(me,token_removal,before_wallet,before_physical,
				before_money);
			s += "你已经在另一个帮派里了，无法开帮立派\n";
		}
		else{
			rollback_create_cost(me,token_removal,before_wallet,before_physical,
				before_money);
			s += "建帮失败，费用和令牌已退回。\n";
		}
	}
	else{
		s += "请输入帮派名称(不能多于6个字):\n";
		s += "[bang_create ...]\n";
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
string filter_msg(string|zero arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","‘");
	arg=replace(arg,",","，");
	arg=replace(arg,".","。");
	arg=replace(arg,"@","。");
	arg=replace(arg,"#","。");
	arg=replace(arg,"%","。");
	arg=replace(arg,"~","。");
	arg=replace(arg,"^","。");
	arg=replace(arg,"$","。");
	arg=replace(arg,"+","。");
	arg=replace(arg,"|","。");
	arg=replace(arg,"&","。");
	arg=replace(arg,"=","＝");
	arg=replace(arg,"(","（");
	arg=replace(arg,")","）");
	arg=replace(arg,"-","－");
	arg=replace(arg,"_","－");
	arg=replace(arg,"*","－");
	arg=replace(arg,"?","？");
	arg=replace(arg,"!","！");
	arg=replace(arg,"<","－");
	arg=replace(arg,">","－");
	arg=replace(arg,"\/","“");
	arg=replace(arg,"\"","“");
	arg=replace(arg,"\\","“");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","：");
	arg=replace(arg,";","；");
	arg=replace(arg,"\{","「");
	arg=replace(arg,"\}","「");
	arg=replace(arg,"[","「");
	arg=replace(arg,"]","」");
	arg=replace(arg,"%20","－");	
	return arg;
}
