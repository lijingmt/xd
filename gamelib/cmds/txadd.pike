/**                                                                                                                          
 * 提供修改通宝的功能
 * @author jess
 * @date 19/04/2007
 */

#include <command.h>
#include <gamelib/include/gamelib.h>

private int give_recharge_bonus(object player)
{
	object|zero box = 0;
	object|zero token = 0;
	mixed err = catch{
		box = clone(ITEM_PATH+"baoxiang/jingjinbaoxiang");
		token = clone(ITEM_PATH+"bossdrop/huoyueqian");
	};
	if(err || !box || !token){
		if(box)
			destruct(box);
		if(token)
			destruct(token);
		return 0;
	}
	token->amount = 5;
	err = catch{
		box->move(player);
		token->move(player);
	};
	if(err || environment(box)!=player || environment(token)!=player){
		if(box)
			destruct(box);
		if(token)
			destruct(token);
		return 0;
	}
	return 1;
}

int main(string|zero arg)
{
	string s="";
	string name="";
	string request_id="";
	int parsed = 0;
	object manager = this_player();
	if(!manager || MANAGERD->checkpower(manager->query_name())!="admin"){
		write("需要管理员权限才可以执行充值。\n[返回游戏:look]\n");
		return 1;
	}
	int fe = 1;
	int remove_flag=0;
	parsed = sscanf(arg || "","%s %d %s",name,fe,request_id);

	if(parsed<2){
		name = arg || "";
		//s+="请输入充值的通宝数[string:txadd "+name+" ...]\n";
		s += "充值将进入注册账号共享钱包，账号内所有职业可消费。\n";
		s += "历史背包玉石和免费奖励仍归具体人物，不会自动迁移。\n";
		s+="[共享充值50元:txadd "+name+" 50]\n";
		s+="[共享充值100元:txadd "+name+" 100]\n";
		s+="[共享充值200元:txadd "+name+" 200]\n";
		s+="[共享充值300元:txadd "+name+" 300]\n";
		s+="[共享充值400元:txadd "+name+" 400]\n";
		s+="[共享充值500元:txadd "+name+" 500]\n";
		s += "[返回上级:mgr_usr_data "+name+"]\n";
		s += "[返回管理主界面:game_deal]\n";
		s+="[返回游戏:look]\n";
		write("%s",s);
		return 1;
	}
	if(fe<=0 || fe>100000000){
		write("充值金额无效。\n[返回:txadd "+name+"]\n");
		return 1;
	}
	if(parsed==2){
		string token = ACCOUNT_WALLETD->new_recharge_request_id();
		string account_id = ACCOUNT_CHARACTERD->
			query_account_id_for_character(name);
		s += "请最后确认本次充值：\n";
		s += "注册账号："+account_id+"\n";
		s += "选择人物："+name+"（仅用于接收附赠物）\n";
		s += "共享入账："+fe+"元（"+
			YUSHID->get_yushi_for_desc(fe*10)+"）\n";
		s += "账号内所有职业共享消费，重复点击同一确认链接不会重复入账。\n";
		s += "[确认共享充值:txadd "+name+" "+fe+" "+token+"]\n";
		s += "[取消并返回:txadd "+name+"]\n";
		write("%s",s);
		return 1;
	}
	if(parsed!=3 || sizeof(request_id)!=64){
		write("充值确认编号无效，本次没有入账。\n[返回:txadd "+name+"]\n");
		return 1;
	}
	else{
		object player = find_player(name);
		if(!player)
		{
			player=this_player()->load_player(name);
			remove_flag=1;                                                                                      
		}
		if(!player && (remove_flag==1)){
			s += "没有这个游戏id，请核对后再查。\n";
			s += "[返回上级:mgr_usr_data "+name+"]\n";
			s += "[返回管理主界面:game_deal]\n";
			s+="[返回游戏:look]\n";
			write("%s",s);
			return 1;
		}
		if(player){
			mapping wallet_result = ACCOUNT_WALLETD->credit_recharge_once(
				player,fe,manager->query_name(),request_id);
			if(!wallet_result["ok"]){
				s += (string)(wallet_result["message"] ||
					"共享充值失败，本次没有入账")+"\n";
				if(remove_flag)
					player->net_dead();
				s += "[返回:mgr_usr_data "+name+"]\n";
				s += "[返回管理主界面:game_deal]\n";
				s += "[返回游戏:look]\n";
				write("%s",s);
				return 1;
			}
			int duplicate = (int)wallet_result["duplicate"];
			int bonus_ok = duplicate ? 1 : give_recharge_bonus(player);
			int save_ok = duplicate ? 1 : player->save_with_result();
			string account_id = (string)wallet_result["account_id"];
			string lgs = "操作人："+manager->name+"|"+
				manager->name_cn+"||||"+name+"|"+player->name_cn;
			lgs += "|充值："+(fe)+"|附赠："+bonus_ok+
				"|人物存档："+save_ok+"|\n";
			s = "注册账号："+account_id+"\n";
			s += "本次指定人物："+name+"（附赠物发到此人物）\n";
			s += "共享充值："+fe+"元，入账"+
				YUSHID->get_yushi_for_desc((int)wallet_result["amount"])+"\n";
			s += "账号共享余额："+
				YUSHID->get_yushi_for_desc((int)wallet_result["balance"])+"\n";
			s += duplicate ?
				"该确认请求此前已经成功处理，本次未重复入账或发放附赠物。\n" :
				(bonus_ok && save_ok ?
				"充值附赠物已发到指定人物。\n" :
				"充值已入账，但附赠物发放或人物存档失败，请按日志核对补发。\n");
			string now = ctime(time());
			if(!duplicate)
				Stdio.append_file(ROOT+"/log/manage_addfee.log",
					now[0..sizeof(now)-2]+"|"+lgs);
			//s += "通宝数 "+(fe*10)+" 充值成功，请返回。\n";
			s += "账号共享充值成功，请返回。\n";
		}
		if(remove_flag){
			//player->remove();	
			//删除是肯定的，但不要使用remove，否则直接删除对象
			player->net_dead();
		}
	}
	s += "[返回:mgr_usr_data "+name+"]\n";
	s += "[返回管理主界面:game_deal]\n";
	s += "[返回游戏:look]\n";
	write("%s",s);
	return 1;
}
