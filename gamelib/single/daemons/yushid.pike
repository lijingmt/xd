//收费道具玉石的功能模块，提供玉石兑换，消费，整理的接口
//
//由liaocheng于07/11/07开始设计开发

#include <globals.h>
#include <gamelib/include/gamelib.h>

private mapping(int:int) rarelevel_value = ([1:1,2:10,3:100,4:1000,5:10000]); //玉石稀有度与等量价值的对照表
private mapping(int:string) rarelevel_namecn = ([1:"【玉】碎玉",2:"【玉】仙缘玉",3:"【玉】玲珑玉",4:"【玉】碧銮玉",5:"【玉】玄天宝玉"]);//玉石稀有度与玉石名字的对应表
private mapping(int:string) rarelevel_namecn_clear = ([1:"碎玉",2:"仙缘玉",3:"玲珑玉",4:"碧銮玉",5:"玄天宝玉"]);//玉石稀有度与玉石名字的对应表,去掉前缀
private mapping(int:string) rarelevel_name = ([1:"suiyu",2:"xianyuanyu",3:"linglongyu",4:"biluanyu",5:"xuantianbaoyu"]);//玉石稀有度与玉石的对应表

protected void create()
{

}

/*
 * 合玉/拆玉审计日志。日志是交易旁路：任何日志系统异常只能写入
 * stderr，不能影响已经完成或被拒绝的玩家交易。
 *
 * source/target 的 requested 与 actual 分开记录，用于识别部分完成；
 * invariant 会同时核对玉石价值守恒和实际手续费扣减。
 */
void append_conversion_audit(object player,string action,string status,
	string reason,int source_level,int source_requested,int source_actual,
	int target_level,int target_requested,int target_actual,int fee,
	int account_before)
{
	mixed err=catch{
		string player_id=player ? (string)player->query_name() : "unknown";
		player_id=replace(player_id,(["\t":"_","\r":"_","\n":"_"]));
		string source_name=source_level>=1 && source_level<=5 ?
			get_yushi_name(source_level) : "unknown";
		string target_name=target_level>=1 && target_level<=5 ?
			get_yushi_name(target_level) : "unknown";
		int source_value=source_level>=1 && source_level<=5 ?
			source_actual*get_yushi_value(source_level) : 0;
		int target_value=target_level>=1 && target_level<=5 ?
			target_actual*get_yushi_value(target_level) : 0;
		int account_after=player ? (int)player->query_account() : 0;
		string invariant=(source_value==target_value &&
			account_before-account_after==fee) ? "ok" : "violation";
		string line=sprintf(
			"%d\tevent=yushi_conversion\tplayer=%s\taction=%s\tstatus=%s"
			"\treason=%s\tsource_level=%d\tsource=%s"
			"\tsource_requested=%d\tsource_actual=%d"
			"\ttarget_level=%d\ttarget=%s"
			"\ttarget_requested=%d\ttarget_actual=%d"
			"\tsource_value=%d\ttarget_value=%d\tfee=%d"
			"\taccount_before=%d\taccount_after=%d\tinvariant=%s\n",
			time(),player_id,action,status,reason,source_level,source_name,
			source_requested,source_actual,target_level,target_name,
			target_requested,target_actual,source_value,target_value,fee,
			account_before,account_after,invariant);
		Stdio.append_file(ROOT+"/log/fee_log/yushi_change-"+
			MUD_TIMESD->get_year_month()+".log",line);
	};
	if(err)
		werror("[YUSHI_AUDIT] append failed: %s\n",describe_error(err));
}


string query_can_update(object player)
{
	string s_rtn = "";
	mapping(int:int) tmp_m=([]);//记录玩家现在身上各种稀有度玉石的个数
	//首先获得玩家玉石的个数信息
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			int rare = ob->query_yushi_rarelevel();
			//只有合成二级以上的玉石，也就是说只有一级到四级的才能作为合成材料
			if(rare>0 && rare<5){
				if(!tmp_m[rare])
					tmp_m[rare] = ob->amount;
				else
					tmp_m[rare] += ob->amount;
			}
		}
	}
	//然后分别列出可以合成的玉石列表
	if(sizeof(tmp_m)){
		foreach(sort(indices(tmp_m)),int rarelevel){
			if(rarelevel>0 && rarelevel<5){
				int num = tmp_m[rarelevel]/10;
				if(num > 0){
					s_rtn += "[合成"+rarelevel_namecn[rarelevel+1]+":yushi_update_detail "+rarelevel_name[rarelevel+1]+" "+(rarelevel+1)+"](x"+num+")\n";
				}
			}
		}
	}
	return s_rtn;
}

//根据稀有度获得玉石的名字
string get_yushi_namecn(int rarelevel)
{
	return rarelevel_namecn[rarelevel];
}
//根据稀有度获得玉石的文件名
string get_yushi_name(int rarelevel)
{
	return rarelevel_name[rarelevel];
}
//根据稀有度获得玉石折合碎玉的价值
int get_yushi_value(int rarelevel)
{
	return rarelevel_value[rarelevel];
}

//查询能够合成的某稀有度玉石的个数
//这个也用于判断是否可以合成，防止玩家非法刷
int query_update_num(object player,int rarelevel)
{
	int num_rtn = 0;
	array(object) all_obj = all_inventory(player);
	rarelevel--;
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			if(ob->query_yushi_rarelevel()==rarelevel)
				num_rtn += ob->amount;
		}
	}
	num_rtn = num_rtn/10;
	return num_rtn;
}


//查询玩家能够打碎的玉石列表
string query_can_degrade(object player)
{
	string s_rtn = "";
	mapping(int:int) tmp_m=([]);//记录玩家现在身上各种稀有度玉石的个数
	//首先获得玩家玉石的个数信息
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			int rare = ob->query_yushi_rarelevel();
			//只有合成二级以上的玉石，也就是说只有一级到四级的才能作为合成材料
			if(rare>1 && rare<=5){
				if(!tmp_m[rare])
					tmp_m[rare] = ob->amount;
				else
					tmp_m[rare] += ob->amount;
			}
		}
	}
	//然后分别列出可以合成的玉石列表
	if(sizeof(tmp_m)){
		foreach(sort(indices(tmp_m)),int rarelevel){
			if(rarelevel>1 && rarelevel<=5){
				int num = tmp_m[rarelevel];
				if(num > 0){
					s_rtn += "[打碎"+rarelevel_namecn[rarelevel]+":yushi_degrade_detail "+rarelevel_name[rarelevel-1]+" "+(rarelevel-1)+"](x"+num+")\n";
				}
			}
		}
	}
	return s_rtn;
}


//判断玩家能否打碎某稀有度玉石，防止玩家刷
//玩家player有多少个材料可以打碎为rarelevel等级的玉石
int query_degrade_num(object player,int rarelevel)
{
	int num_rtn = 0;
	array(object) all_obj = all_inventory(player);
	rarelevel++;
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			if(ob->query_yushi_rarelevel()==rarelevel)
				num_rtn += ob->amount;
		}
	}
	return num_rtn;
}

//得到当前人物背包玉石折算成碎玉后的数目，不包含账号充值钱包。
int query_physical_all_num(object player)
{
	int re = 0;
	int tmp = 0;//每种玉的个数；
	int tmp_num = 1;//每种玉与碎玉的比率
	for(int i=1;i<6;i++)
	{
		tmp = query_yushi_num(player,i);
		if (tmp)
		{
			for(int m=0;m<i-1;m++)
			{
				tmp_num = tmp_num *10;	
			}
			re += tmp * tmp_num;
			tmp_num = 1;//将比率重置为1
		}
	}
	return re;
}

// 可消费总额 = 当前人物旧有/奖励玉石 + 注册账号未来充值共享余额。
int query_all_num(object player)
{
	return query_physical_all_num(player)+
		ACCOUNT_WALLETD->query_balance(player);
}
/* 判断玩家全部玉石折合碎玉后的总价值是否足够支付。
 * 支付时无需预先手动打碎或合成玉石。
 */
int have_enough_yushi(object player,int num)
{
	if(num < 0)
		return 0;
	return query_all_num(player) >= num;
}

private mapping query_pending_wallet_payment(object player)
{
	mapping payment;
	if(!player)
		return ([]);
	payment=player["/plus/yushi_wallet_payment"];
	return mappingp(payment) ? payment : ([]);
}

private void set_pending_wallet_payment(object player,mapping payment)
{
	player["/plus/yushi_wallet_payment"]=payment;
}

private int valid_wallet_payment_request(string request_id)
{
	if(!request_id || sizeof(request_id)!=64)
		return 0;
	for(int i=0;i<sizeof(request_id);i++){
		int one=request_id[i];
		if((one>='0' && one<='9') || (one>='a' && one<='f'))
			continue;
		return 0;
	}
	return 1;
}

// user.save_with_result 在真正序列化前调用。charged 只有内存态，
// 这里把它与调用方刚发放的商品/权益一起写成 committed。
void prepare_wallet_payment_player_save(object player)
{
	mapping payment=query_pending_wallet_payment(player);
	if(sizeof(payment) && payment["phase"]=="charged"){
		payment["phase"]="committed";
		set_pending_wallet_payment(player,payment);
	}
}

// 玩家与奖励已经原子写入后，共享钱包幂等凭据才可删除。
// 这个步骤只能由延迟提交回调或登录恢复调用，不能嵌在任意人物存档
// 里面，否则账号索引正在保存时会形成 account -> wallet -> account 锁环。
// 返回 1 表示人物还需要补写一次，以清除 committed 标记。
int complete_wallet_payment_player_save(object player)
{
	mapping payment=query_pending_wallet_payment(player);
	string request_id=(string)(payment["request_id"] || "");
	if(!sizeof(payment) || payment["phase"]!="committed")
		return 0;
	if(!valid_wallet_payment_request(request_id) ||
	   !ACCOUNT_WALLETD->forget_debit_recharge_once(player,request_id))
		return 0;
	set_pending_wallet_payment(player,([]));
	return 1;
}

private int commit_wallet_payment_after_command(object player,
	string request_id)
{
	mapping payment;
	if(!player)
		return 0;
	payment=query_pending_wallet_payment(player);
	if((string)payment["request_id"]!=request_id ||
	   (payment["phase"]!="charged" && payment["phase"]!="committed"))
		return 1;
	if(payment["phase"]=="charged" &&
	   (!functionp(player->save_with_result) ||
	    !player->save_with_result())){
		werror("[YUSHID] 共享钱包购买延迟提交失败: %s %s\n",
			player->query_name(),request_id);
		return 0;
	}
	// 第一份人物存档已经同时包含奖励和 committed 凭据。先清理钱包
	// 收据，再补写人物标记；任一步退出都能由 committed 登录恢复重试。
	if(!complete_wallet_payment_player_save(player)){
		werror("[YUSHID] 共享钱包购买凭据清理失败: %s %s\n",
			player->query_name(),request_id);
		return 0;
	}
	if(!player->save_with_result()){
		werror("[YUSHID] 共享钱包购买标记清理存档失败: %s %s\n",
			player->query_name(),request_id);
		return 0;
	}
	return 1;
}

// 多 worker 下不能让 call_out 在网关释放账号锁之后继续写共享钱包。
// HTTP 请求尾部会在完整命令（包括商品/权益发放）返回后同步调用本入口，
// 并且网关要等 request done 凭证后才允许同账号进入另一个 worker。
int finalize_wallet_payment_after_worker_request(object player)
{
	mapping payment;
	string request_id;
	if(MAP_WORKERD->query_node_role()!="worker" || !player)
		return 1;
	payment=query_pending_wallet_payment(player);
	if(!sizeof(payment) ||
	   (payment["phase"]!="charged" && payment["phase"]!="committed"))
		return 1;
	request_id=(string)(payment["request_id"] || "");
	if(!valid_wallet_payment_request(request_id))
		return 0;
	return commit_wallet_payment_after_command(player,request_id);
}

int reconcile_wallet_payment(object player)
{
	mapping payment=query_pending_wallet_payment(player);
	string phase;
	string request_id;
	if(!sizeof(payment))
		return 1;
	phase=(string)payment["phase"];
	request_id=(string)(payment["request_id"] || "");
	if(!valid_wallet_payment_request(request_id)){
		werror("[YUSHID] 玩家共享钱包购买凭据损坏: %s\n",
			player ? player->query_name() : "unknown");
		return 0;
	}
	if(phase=="prepared"){
		if(!ACCOUNT_WALLETD->rollback_debit_recharge_once(player,
		   request_id,"yushi_purchase_crash_rollback"))
			return 0;
	}
	else if(phase=="committed"){
		if(!ACCOUNT_WALLETD->forget_debit_recharge_once(player,
		   request_id))
			return 0;
	}
	else{
		werror("[YUSHID] 玩家共享钱包购买阶段无效: %s %s\n",
			player->query_name(),phase);
		return 0;
	}
	set_pending_wallet_payment(player,([]));
	return functionp(player->save_with_result) &&
		player->save_with_result();
}
/*
   方法描述：扣出玩家身上的玉石
       变量：player    玩家
             num       需要扣除的玉石数量(以碎玉为单位)
     返回值：0: 扣除失败
             1：扣除成功
    author: Evan 2008.07.25 
 */
int pay_yushi(object player,int num)
{
	array(mapping(string:mixed)) removals=({});
	if(num < 0 || !have_enough_yushi(player,num))//如果玉石不够支付，直接返回失败
		return 0;

	if(num == 0)
		return 1;

	int physical_total = query_physical_all_num(player);
	// 当前人物自己的旧玉石/奖励玉石优先使用；不足部分才从账号共享
	// 充值钱包扣除。旧玉石不迁移，多个职业也不会各复制一份余额。
	if(physical_total < num)
	{
		int wallet_need = num-physical_total;
		string request_id;
		if(sizeof(query_pending_wallet_payment(player)))
			return 0;
		request_id=ACCOUNT_WALLETD->new_recharge_request_id();
		set_pending_wallet_payment(player,(["phase":"prepared",
			"request_id":request_id,"wallet_amount":wallet_need,
			"total_amount":num,"created_at":time()]));
		if(!functionp(player->save_with_result) ||
		   !player->save_with_result()){
			set_pending_wallet_payment(player,([]));
			return 0;
		}
		mapping debit=ACCOUNT_WALLETD->debit_recharge_once(player,
			wallet_need,"yushi_purchase",request_id);
		if(!(int)debit["ok"]){
			set_pending_wallet_payment(player,([]));
			player->save_with_result();
			return 0;
		}
		for(int m=1;m<6;m++)
		{
			int have = query_yushi_num(player,m);
			if(have<=0)
				continue;
			mapping(string:mixed) removal=
				player->remove_combine_item_transaction(
					get_yushi_name(m),have);
			int removed=(int)removal["removed"];
			if(removal["ok"])
				removals+=({removal});
			if(removed!=have)
			{
				for(int r=sizeof(removals)-1;r>=0;r--)
					player->rollback_combine_item_transaction(
						removals[r]);
				if(!ACCOUNT_WALLETD->rollback_debit_recharge_once(
				   player,request_id,"yushi_purchase_rollback"))
					werror("[YUSHID] 共享充值余额回滚失败: %s %d\n",
						player->query_name(),wallet_need);
				else{
					set_pending_wallet_payment(player,([]));
					player->save_with_result();
				}
				return 0;
			}
		}
		mapping payment=query_pending_wallet_payment(player);
		payment["phase"]="charged";
		set_pending_wallet_payment(player,payment);
		// 单进程保留历史的命令后提交时序；worker 由 HTTP 请求尾部在
		// 网关账号锁内同步提交，禁止脱锁延迟回写共享余额。
		if(MAP_WORKERD->query_node_role()!="worker")
			call_out(commit_wallet_payment_after_command,0,player,request_id);
		tell_object(player,"已优先使用当前人物玉石，不足部分从账号共享充值余额扣除。\n");
		return 1;
	}

	mapping(int:int) my_num = ([]);//玩家各种玉石的数目列表
	mapping(int:int) remove_num = ([]);//实际需要扣除的各种玉石
	int remain = num;//还需要支付的碎玉价值
	int change = 0;//打碎较大面额后需要找回的碎玉价值

	for(int i=1;i<6;i++)
	{
		my_num[i] = query_yushi_num(player,i);
		remove_num[i] = 0;
	}

	//优先使用不超过待支付金额的面额，尽量避免打碎大玉
	for(int m=5;m>0;m--)
	{
		int can_use = remain/rarelevel_value[m];
		if(can_use > my_num[m])
			can_use = my_num[m];
		if(can_use > 0)
		{
			remove_num[m] = can_use;
			remain -= can_use*rarelevel_value[m];
		}
	}

	//小面额仍不足时，自动打碎一块最接近的大面额并找零
	if(remain > 0)
	{
		for(int m=1;m<6;m++)
		{
			int left_num = my_num[m]-remove_num[m];
			if(left_num > 0 && rarelevel_value[m] > remain)
			{
				remove_num[m]++;
				change = rarelevel_value[m]-remain;
				remain = 0;
				break;
			}
		}
	}

	if(remain > 0)
		return 0;

	for(int m=1;m<6;m++)//按支付计划扣除玉石
	{
		if(remove_num[m] > 0)
		{
			string yushi = get_yushi_name(m);
			mapping(string:mixed) removal=
				player->remove_combine_item_transaction(
					yushi,remove_num[m]);
			if(!(int)removal["ok"] ||
			   (int)removal["removed"]!=remove_num[m]){
				for(int r=sizeof(removals)-1;r>=0;r--)
					player->rollback_combine_item_transaction(
						removals[r]);
				return 0;
			}
			removals+=({removal});
		}
	}

	if(change > 0)
	{
		if(!give_yushi(player,change)){
			for(int r=sizeof(removals)-1;r>=0;r--)
				player->rollback_combine_item_transaction(removals[r]);
			return 0;
		}
		tell_object(player,"系统已自动兑换玉石，并找回"+get_yushi_for_desc(change)+"。\n");
	}
	return 1;
}

// 需要跨多个存档提交的购买使用此入口。只有涉及共享充值钱包时才
// 使用 request_id 幂等扣款；纯人物玉石仍走上面的历史兑换算法。
int pay_yushi_once(object player,int num,string request_id)
{
	array(mapping(string:mixed)) removals=({});
	if(num<0)
		return 0;
	if(num==0)
		return 1;
	int physical_total=query_physical_all_num(player);
	if(physical_total>=num)
		return pay_yushi(player,num);
	int wallet_need=num-physical_total;
	mapping debit=ACCOUNT_WALLETD->debit_recharge_once(player,
		wallet_need,"home_function_room_purchase",request_id);
	if(!(int)debit["ok"])
		return 0;
	for(int level=1;level<6;level++){
		int have=query_yushi_num(player,level);
		if(have<=0)
			continue;
		mapping(string:mixed) removal=
			player->remove_combine_item_transaction(
				get_yushi_name(level),have);
		if((int)removal["ok"])
			removals+=({removal});
		if(!(int)removal["ok"] || (int)removal["removed"]!=have){
			int rollback_ok=1;
			for(int index=sizeof(removals)-1;index>=0;index--)
				if(!player->rollback_combine_item_transaction(
				   removals[index]))
					rollback_ok=0;
			if(!ACCOUNT_WALLETD->rollback_debit_recharge_once(
			   player,request_id,"home_function_room_payment_failed"))
				rollback_ok=0;
			if(!rollback_ok)
				werror("[YUSHID] 功能房幂等支付回滚失败: %s %d\n",
					player->query_name(),num);
			return 0;
		}
	}
	tell_object(player,
		"已优先使用当前人物玉石，不足部分从账号共享充值余额扣除。\n");
	return 1;
}

/*
   方法描述：给玩家添加玉石
       变量：player    玩家
             num       需要添加的玉石数量(以碎玉为单位)
     返回值：0: 添加失败
             1：添加成功
    author: Evan 2008.09.19 
 */
int give_yushi(object player,int num)
{
	mapping(int:int) all_yushi=([]);
	mapping(int:int) before=([]);
	array(object) created=({});
	int remaining=num;
	if(!player || !player->query_name || num<0 || num>20000000)
		return 0;
	if(num==0)
		return 1;
	for(int level=1;level<5;level++){
		all_yushi[level]=remaining%10;
		remaining=remaining/10;
	}
	all_yushi[5]=remaining;
	for(int level=1;level<6;level++)
		before[level]=query_yushi_num(player,level);
	for(int level=1;level<6;level++){
		int level_amount=all_yushi[level];
		while(level_amount>0){
			object yushi_new;
			mixed err=catch{
				yushi_new=clone(ITEM_PATH+"yushi/"+get_yushi_name(level));
			};
			if(err || !yushi_new)
				break;
			int chunk=level_amount;
			if(chunk>(int)yushi_new->max_count)
				chunk=(int)yushi_new->max_count;
			if(chunk<=0){
				destruct(yushi_new);
				break;
			}
			yushi_new->amount=chunk;
			created+=({yushi_new});
			// 多 Worker 切换或同名对象重载期间，find_player(name) 可能
			// 暂时指向另一份对象。退款/补发必须落到调用方持有的精确
			// 玩家对象；只有全局在线对象身份一致时才沿用自动合堆。
			if(find_player((string)player->query_name())==player)
				yushi_new->move_player((string)player->query_name());
			else if(yushi_new->move(player)!=1 ||
			        environment(yushi_new)!=player)
				break;
			level_amount-=chunk;
		}
		if(level_amount>0)
			break;
	}
	int exact=1;
	for(int level=1;level<6;level++)
		if(query_yushi_num(player,level)-before[level]!=all_yushi[level])
			exact=0;
	if(exact)
		return 1;
	// 任一面额发放失败时撤销本次已经增加的数量，避免部分到账后重试。
	for(int level=1;level<6;level++){
		int added=query_yushi_num(player,level)-before[level];
		if(added>0)
			player->remove_combine_item_transaction(get_yushi_name(level),added);
	}
	foreach(created,object created_item)
		if(created_item && environment(created_item)!=player)
			destruct(created_item);
	werror("[YUSHID] give_yushi rolled back player=%s num=%d\n",
		(string)player->query_name(),num);
	return 0;
}

// 撤销本次 pay_yushi()：人物实体玉按实际差额退回，共享充值钱包按
// 幂等 request_id 原路撤销，禁止把共享充值余额错误转换成可交易实体玉。
int rollback_yushi_payment(object player,int before_wallet,
	int before_physical,string reason)
{
	mapping payment;
	string request_id="";
	int ok=1;
	int physical_spent;
	int wallet_spent;
	if(!player || before_wallet<0 || before_physical<0)
		return 0;
	payment=query_pending_wallet_payment(player);
	if(sizeof(payment))
		request_id=(string)(payment["request_id"] || "");
	physical_spent=before_physical-query_physical_all_num(player);
	if(physical_spent>0 && !give_yushi(player,physical_spent))
		ok=0;
	if(request_id!=""){
		if(!ACCOUNT_WALLETD->rollback_debit_recharge_once(player,request_id,
		   reason || "yushi_payment_rollback"))
			ok=0;
		else
			set_pending_wallet_payment(player,([]));
	}
	else{
		wallet_spent=before_wallet-ACCOUNT_WALLETD->query_balance(player);
		if(wallet_spent>0 && !ACCOUNT_WALLETD->refund_recharge(player,
		   wallet_spent,reason || "yushi_payment_rollback"))
			ok=0;
	}
	return ok;
}
//获得玩家拥有某种玉石的个数，购买物品时调用
int query_yushi_num(object player,int rarelevel)
{
	int num_rtn = 0;
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			if(ob->query_yushi_rarelevel()==rarelevel)
				num_rtn += ob->amount;
		}
	}
	return num_rtn;
}
//返回玩家身上所有玉石的中文描述
string query_yushi_cn(object player)
{
	string s_rtn = "";
	mapping(int:int) tmp_m=([]);//记录玩家现在身上各种稀有度玉石的个数
	array(object) all_obj = all_inventory(player);
	foreach(all_obj,object ob){
		if(ob->query_item_type()=="yushi"){
			int rare = ob->query_yushi_rarelevel();
			if(rare>0 && rare<=5){
				if(!tmp_m[rare])
					tmp_m[rare] = ob->amount;
				else
					tmp_m[rare] += ob->amount;
			}
		}
	}
	if(sizeof(tmp_m)){
		array artmp = sort(indices(tmp_m));
		for(int i=sizeof(artmp);i>0;i--)
		{
			int rarelevel = artmp[i-1];
			if(rarelevel>0 && rarelevel<6){
				int num = tmp_m[rarelevel];
				if(num > 0){
					s_rtn += rarelevel_namecn_clear[rarelevel]+"："+num+"\n";
				}
			}
		}
	}
	int shared_balance = ACCOUNT_WALLETD->query_balance(player);
	if(shared_balance>0)
		s_rtn += "账号共享充值余额："+
			get_yushi_for_desc(shared_balance)+"\n";
return s_rtn;
}
//获得一定数量玉石的描述性语言
//参数是以碎玉为单位的价值
//如value =11 则此接口返回1【玉】仙缘玉1【玉】碎玉
string get_yushi_for_desc(int value)
{
	string s_rtn = "";
	if(value){
		int biluanyu = 0;
		int linglongyu = 0;
		int xianyuanyu = 0;
		int suiyu = 0;
		int xuantianbaoyu = value/10000;
		if(xuantianbaoyu){
			s_rtn += xuantianbaoyu+"【玉】玄天宝玉";
			value = value%10000;
		}
		biluanyu = value/1000;
		if(biluanyu){
			s_rtn += biluanyu+"【玉】碧銮玉";
			value = value%1000;
		}
		linglongyu = value/100;
		if(linglongyu){
			s_rtn += linglongyu+"【玉】玲珑玉";
			value = value%100;
		}
		xianyuanyu = value/10;
		if(xianyuanyu){
			s_rtn += xianyuanyu+"【玉】仙缘玉";
			value = value%10;
		}
		suiyu = value;                                                                                    
		if(suiyu)
			s_rtn += suiyu+"【玉】碎玉";
	}
	return s_rtn;
}

//与yushi_add_fee.pike相对应的玉石的描述,与它联合使用来告诉玩家获得玉的情况
//arg = fee yushi_level
string query_yushi_add_fee_desc(int fee,int yushi_level)
{
	string s_rtn = "";
	if(fee > 20 && yushi_level < 5){
		int up_fee = fee/10;
		fee = fee%10;
		int up_yushi_level = yushi_level+1;
		s_rtn += query_yushi_add_fee_desc(up_fee,up_yushi_level);
		if(fee > 0)
			s_rtn += query_yushi_add_fee_desc(fee,yushi_level);
	}
	else{
		string yushi_name_cn = get_yushi_namecn(yushi_level);
		s_rtn += fee+yushi_name_cn;
	}
	return s_rtn;
}
