/**                                                                                                                          
 * 提供修改通宝的功能
 * @author jess
 * @date 19/04/2007
 */

#include <command.h>
#include <gamelib/include/gamelib.h>

mapping(string:mixed) give_recharge_bonus_once(object player,
	string request_id,int worker_fenced_save)
{
	object|zero box = 0;
	object|zero token = 0;
	int save_ok;
	if(player->has_admin_recharge_bonus_receipt(request_id))
		return (["ok":1,"duplicate":1,"saved":1]);
	mixed err = catch{
		box = clone(ITEM_PATH+"baoxiang/jingjinbaoxiang");
		token = clone(ITEM_PATH+"bossdrop/huoyueqian");
	};
	if(err || !box || !token){
		if(box)
			destruct(box);
		if(token)
			destruct(token);
		return (["ok":0,"duplicate":0,"saved":0]);
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
		return (["ok":0,"duplicate":0,"saved":0]);
	}
	if(!player->record_admin_recharge_bonus_receipt(request_id)){
		destruct(box);
		destruct(token);
		return (["ok":0,"duplicate":0,"saved":0]);
	}
	save_ok = player->save_with_result(0,worker_fenced_save);
	if(!save_ok){
		player->rollback_admin_recharge_bonus_receipt(request_id);
		if(box)
			destruct(box);
		if(token)
			destruct(token);
		return (["ok":0,"duplicate":0,"saved":0]);
	}
	return (["ok":1,"duplicate":0,"saved":1]);
}

mapping(string:mixed) execute_admin_recharge_target(object player,int fee,
	string operator,string request_id,int worker_fenced_save)
{
	mapping wallet_result;
	mapping bonus_result;
	if(!player)
		return (["ok":0,"message":"没有这个游戏id"]);
	wallet_result = ACCOUNT_WALLETD->credit_recharge_once(
		player,fee,operator,request_id);
	if(!(int)wallet_result["ok"])
		return wallet_result;
	bonus_result = give_recharge_bonus_once(player,request_id,
		worker_fenced_save);
	wallet_result["bonus_ok"] = (int)bonus_result["ok"];
	wallet_result["bonus_duplicate"] = (int)bonus_result["duplicate"];
	wallet_result["player_saved"] = (int)bonus_result["saved"];
	wallet_result["character_name_cn"] = (string)player->query_name_cn();
	return wallet_result;
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
		name = String.trim_all_whites(name);
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
	name = String.trim_all_whites(name);
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
		if(MAP_WORKERD->query_node_role()=="worker"){
			mapping online_status = HTTP_APID->
				query_map_worker_cluster_online_users();
			string located_worker = "";
			if(online_status["ok"] && arrayp(online_status["users"]))
				foreach((array)online_status["users"],mapping row)
					if((string)row["userid"]==name){
						located_worker = (string)row["worker_id"];
						break;
					}
			s += located_worker!="" ?
				"当前在线进程："+located_worker+
				"（确认后由协调器自动路由）\n" :
				"当前状态：离线（确认后由主worker安全加载并存档）\n";
		}
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
		object|zero player = 0;
		mapping wallet_result;
		string target_name_cn = name;
		if(MAP_WORKERD->query_node_role()=="worker")
			wallet_result = HTTP_APID->execute_map_worker_admin_recharge(
				manager,name,fe,request_id);
		else{
			player = find_player(name);
			if(!player){
				player=this_player()->load_player(name);
				remove_flag=1;
			}
			if(player)
				wallet_result = execute_admin_recharge_target(player,fe,
					manager->query_name(),request_id,0);
			else
				wallet_result = (["ok":0,"message":"没有这个游戏id"]);
		}
		if(!mappingp(wallet_result) || !wallet_result["ok"]){
			s += "没有这个游戏id，请核对后再查。\n";
			if(mappingp(wallet_result) && wallet_result["message"])
				s = (string)wallet_result["message"]+"\n";
			s += "[返回上级:mgr_usr_data "+name+"]\n";
			s += "[返回管理主界面:game_deal]\n";
			s+="[返回游戏:look]\n";
			if(remove_flag && player)
				player->net_dead();
			write("%s",s);
			return 1;
		}
		{
			int duplicate = (int)wallet_result["duplicate"];
			int bonus_ok = (int)wallet_result["bonus_ok"];
			int save_ok = (int)wallet_result["player_saved"];
			int bonus_duplicate = (int)wallet_result["bonus_duplicate"];
			int cache_refresh_ok = !has_index(wallet_result,"cache_refresh_ok") ||
				(int)wallet_result["cache_refresh_ok"];
			string account_id = (string)wallet_result["account_id"];
			if((string)wallet_result["character_name_cn"]!="")
				target_name_cn = (string)wallet_result["character_name_cn"];
			string lgs = "操作人："+manager->name+"|"+
				manager->name_cn+"||||"+name+"|"+target_name_cn;
			lgs += "|充值："+(fe)+"|附赠："+bonus_ok+
				"|人物存档："+save_ok+
				"|worker："+(string)(wallet_result["worker_id"] || "standalone")+
				"|request："+request_id+"|\n";
			s = "注册账号："+account_id+"\n";
			s += "本次指定人物："+name+"（附赠物发到此人物）\n";
			s += "共享充值："+fe+"元，入账"+
				YUSHID->get_yushi_for_desc((int)wallet_result["amount"])+"\n";
			s += "账号共享余额："+
				YUSHID->get_yushi_for_desc((int)wallet_result["balance"])+"\n";
			s += duplicate && bonus_duplicate ?
				"该确认请求此前已经完整处理，本次未重复入账或发放附赠物。\n" :
				(bonus_ok && save_ok ?
				(duplicate ?
				"共享入账此前已完成，本次已补齐且仅补发一次附赠物。\n" :
				"充值附赠物已发到指定人物。\n") :
				"充值已入账，但附赠物发放或人物存档失败，请按日志核对补发。\n");
			if(!cache_refresh_ok)
				s += "充值已经安全入账，但部分Worker缓存刷新未确认。\n";
			if(!bonus_ok || !save_ok || !cache_refresh_ok)
				s += "[用同一凭据安全重试:txadd "+name+" "+fe+" "+
					request_id+"]\n";
			string now = ctime(time());
			if(!duplicate || !bonus_duplicate)
				Stdio.append_file(ROOT+"/log/manage_addfee.log",
					now[0..sizeof(now)-2]+"|"+lgs);
			if(bonus_ok && save_ok && cache_refresh_ok)
				s += "账号共享充值完整成功，请返回。\n";
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
