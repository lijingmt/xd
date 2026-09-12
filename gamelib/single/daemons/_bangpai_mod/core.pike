/* 帮派扩展核心：状态持久化、帮派建设与帮贡账本。 */

private string bangpai_ext_state_path()
{
	return bangpai_ext_state_file_override ?
		BANGPAI_EXT_STATE_FILE+".test" : BANGPAI_EXT_STATE_FILE;
}

private int bangpai_ext_file_mtime(string path)
{
	mixed fs = file_stat(path);
	return objectp(fs) ? (int)fs->mtime : 0;
}

private int valid_bangpai_ext_member_record(mixed record)
{
	return mappingp(record) && stringp(record["date"]) &&
		sizeof((string)record["date"])>=8 &&
		sizeof((string)record["date"])<=10 &&
		intp(record["contrib"]);
}

private int valid_bangpai_ext_gang(mixed gang)
{
	if(!mappingp(gang) || !intp(gang["exp"]) || (int)gang["exp"]<0 ||
	   !intp(gang["donation_total"]) || !mappingp(gang["contrib"]) ||
	   !mappingp(gang["donate_daily"]) || !arrayp(gang["audit"]))
		return 0;
	if(sizeof((mapping)gang["contrib"])>BANGPAI_EXT_MAX_MEMBERS ||
	   sizeof((array)gang["audit"])>64)
		return 0;
	foreach(indices((mapping)gang["donate_daily"]),string name)
		if(sizeof(name)<2 || sizeof(name)>64 ||
		   !valid_bangpai_ext_member_record(
			(mapping)gang["donate_daily"][name]))
			return 0;
	return 1;
}

private int valid_bangpai_ext_state(mixed state)
{
	if(!mappingp(state) || (int)state["version"]!=BANGPAI_EXT_STATE_VERSION ||
	   !mappingp(state["gangs"]) || !intp(state["revision"]) ||
	   (int)state["revision"]<0)
		return 0;
	if(sizeof((mapping)state["gangs"])>BANGPAI_EXT_MAX_GANGS)
		return 0;
	foreach(indices((mapping)state["gangs"]),string gang_key){
		int bangid;
		if(sscanf(gang_key,"%d",bangid)!=1 || bangid<=0 ||
		   !valid_bangpai_ext_gang((mapping)state["gangs"][gang_key]))
			return 0;
	}
	return 1;
}

private mapping(string:mixed) empty_bangpai_ext_gang()
{
	return (["exp":0,"donation_total":0,"contrib":([]),
		"donate_daily":([]),"audit":({})]);
}

private void bangpai_ext_reload_cache(void|int force)
{
	string path = bangpai_ext_state_path();
	int mtime = bangpai_ext_file_mtime(path);
	int size = Stdio.file_size(path);
	mixed decoded = 0;
	string source;
	if(!force && mtime==bangpai_ext_cache_mtime &&
	   size==bangpai_ext_cache_size)
		return;
	if(size<=0){
		bangpai_ext_state = (["version":BANGPAI_EXT_STATE_VERSION,
			"revision":0,"gangs":([])]);
		bangpai_ext_cache_mtime = mtime;
		bangpai_ext_cache_size = size;
		return;
	}
	if(size>4*1024*1024){
		werror("[BANGPAI_EXTD] 状态文件过大，拒绝载入。\n");
		return;
	}
	source = Stdio.read_file(path);
	mixed err = catch{ decoded = Standards.JSON.decode(source); };
	if(err || !valid_bangpai_ext_state(decoded)){
		werror("[BANGPAI_EXTD] 状态文件损坏，拒绝载入。\n");
		return;
	}
	bangpai_ext_state = copy_value(decoded);
	bangpai_ext_cache_mtime = mtime;
	bangpai_ext_cache_size = size;
}

private int bangpai_ext_with_lock(function mutation)
{
	string lock_dir = BANGPAI_EXT_LOCK_DIR+
		(bangpai_ext_state_file_override ? ".test" : "");
	int waited = 0;
	int saved;
	mixed err;
	while(mkdir(lock_dir)==0){
		int age = time()-bangpai_ext_file_mtime(lock_dir);
		// 持锁超过15秒视为残留锁（持有者崩溃），强制接管。
		if(age>BANGPAI_EXT_LOCK_STALE_SECONDS){
			rm(lock_dir);
			continue;
		}
		if(++waited>30){
			werror("[BANGPAI_EXTD] 状态锁等待超时。\n");
			return 0;
		}
		sleep(0.01);
	}
	err = catch{
		// 锁内强制重读最新状态，避免本地缓存覆盖他 Worker 的写入。
		bangpai_ext_reload_cache(1);
		saved = mutation();
	};
	rm(lock_dir);
	if(err){
		werror("[BANGPAI_EXTD] 状态修改异常: %s\n",describe_error(err));
		return 0;
	}
	return saved;
}

private int bangpai_ext_save()
{
	string path = bangpai_ext_state_path();
	string temp_file = path+"."+getpid()+".tmp";
	string encoded = Standards.JSON.encode(bangpai_ext_state);
	int ok = 0;
	mixed err = catch{
		mkdir(dirname(path));
		rm(temp_file);
		if(Stdio.write_file(temp_file,encoded)>0 &&
		   Stdio.file_size(temp_file)==sizeof(encoded) &&
		   mv(temp_file,path))
			ok = Stdio.file_size(path)==sizeof(encoded);
	};
	if(err || !ok){
		rm(temp_file);
		werror("[BANGPAI_EXTD] 状态保存失败。\n");
		return 0;
	}
	bangpai_ext_cache_mtime = bangpai_ext_file_mtime(path);
	bangpai_ext_cache_size = Stdio.file_size(path);
	return 1;
}

private mapping(string:mixed) bangpai_ext_gang_record(int bangid,
	void|int create)
{
	string key = (string)bangid;
	bangpai_ext_reload_cache();
	mapping gangs = bangpai_ext_state["gangs"];
	if(!mappingp(gangs))
		gangs = bangpai_ext_state["gangs"] = ([]);
	if(!mappingp(gangs[key])){
		if(!create || !bangid)
			return 0;
		if(sizeof(gangs)>=BANGPAI_EXT_MAX_GANGS)
			return 0;
		gangs[key] = empty_bangpai_ext_gang();
	}
	mapping gang = gangs[key];
	if(!valid_bangpai_ext_gang(gang))
		gangs[key] = gang = empty_bangpai_ext_gang();
	return gang;
}

int query_gang_level(int bangid)
{
	mapping gang = bangpai_ext_gang_record(bangid);
	if(!gang)
		return 1;
	int exp = (int)gang["exp"];
	int level = 1;
	for(int i=1;i<sizeof(bangpai_level_costs);i++)
		if(exp>=bangpai_level_costs[i])
			level = i+1;
	return level;
}

int query_gang_next_level_cost(int bangid)
{
	int level = query_gang_level(bangid);
	if(level>=BANGPAI_EXT_MAX_LEVEL)
		return 0;
	return (int)bangpai_level_costs[level];
}

/** 打怪经验加成：2级+2%、5级+5%、8级+8%（取最高档，不叠加）。 */
int query_gang_exp_bonus_percent(object player)
{
	int bangid;
	if(!player || !functionp(player->query_name))
		return 0;
	bangid = (int)player->bangid;
	if(!bangid)
		return 0;
	int level = query_gang_level(bangid);
	if(level>=8)
		return 8;
	if(level>=5)
		return 5;
	if(level>=2)
		return 2;
	return 0;
}

int query_gang_shop_unlocked(int bangid)
{
	return query_gang_level(bangid)>=3;
}

int query_gang_illusion_unlocked(int bangid)
{
	return query_gang_level(bangid)>=4;
}

int query_gang_boss_attempts_daily(int bangid)
{
	return query_gang_level(bangid)>=7 ? 2 : 1;
}

int query_contribution(object player)
{
	if(!player || !functionp(player->query_name) || !(int)player->bangid)
		return 0;
	mapping gang = bangpai_ext_gang_record((int)player->bangid);
	if(!gang)
		return 0;
	mapping contrib = gang["contrib"];
	string name = (string)player->query_name();
	return mappingp(contrib) && intp(contrib[name]) ?
		(int)contrib[name] : 0;
}

private void bangpai_ext_append_audit(mapping gang,string line)
{
	array audit = gang["audit"];
	audit += ({sprintf("%d %s",time(),line)});
	if(sizeof(audit)>64)
		audit = audit[sizeof(audit)-64..];
	gang["audit"] = audit;
}

/** 内部入账：调用方自行保证状态已在锁内。 */
private void add_contribution_locked(mapping gang,string name,int amount,
	string reason)
{
	if(amount==0 || sizeof(name)<2 || sizeof(name)>64)
		return;
	mapping contrib = gang["contrib"];
	if(!mappingp(contrib))
		contrib = gang["contrib"] = ([]);
	contrib[name] = (int)(contrib[name] || 0)+amount;
	if((int)contrib[name]<0)
		contrib[name] = 0;
	bangpai_ext_append_audit(gang,"contrib "+name+" "+
		(amount>0 ? "+" : "")+amount+" "+reason);
}

mapping add_contribution(int bangid,string name,int amount,string reason)
{
	int saved = 0;
	if(!bangid || !stringp(name) || sizeof(name)<2 || sizeof(name)>64)
		return (["ok":0,"message":"参数无效。"]);
	saved = bangpai_ext_with_lock(lambda(){
		mapping gang = bangpai_ext_gang_record(bangid,1);
		if(!gang)
			error("帮派状态不可用\n");
		add_contribution_locked(gang,name,amount,reason);
		return bangpai_ext_save();
	});
	return saved ? (["ok":1]) :
		(["ok":0,"message":"帮派状态繁忙，请稍后再试。"]);
}

private string bangpai_ext_today()
{
	// 与提炼日限相同的 localtime 口径，跨模块日期判定一致。
	mapping t = localtime(time());
	return (t["year"]+1900)+"-"+(t["mon"]+1)+"-"+t["mday"];
}

/** 捐献银两：扣钱→建设度→帮贡（每日捐献帮贡上限500）。 */
mapping donate(object player,int amount)
{
	object me = player;
	int bangid;
	int gained_contrib;
	int old_level;
	int new_level;
	int saved = 0;
	if(!me || !functionp(me->query_name))
		return (["ok":0,"message":"参数无效。"]);
	bangid = (int)me->bangid;
	if(!bangid)
		return (["ok":0,"message":"你还没有加入帮派。"]);
	if(amount<BANGPAI_EXT_DONATE_MIN)
		return (["ok":0,"message":"每次至少捐献"+
			format_game_number(BANGPAI_EXT_DONATE_MIN)+"银两。"]);
	if(amount>BANGPAI_EXT_DONATE_MAX)
		return (["ok":0,"message":"单次捐献上限"+
			format_game_number(BANGPAI_EXT_DONATE_MAX)+"银两。"]);
	if(me->query_account()<amount)
		return (["ok":0,"message":"身上银两不足。"]);
	string name = (string)me->query_name();
	string today = bangpai_ext_today();
	saved = bangpai_ext_with_lock(lambda(){
		mapping gang = bangpai_ext_gang_record(bangid,1);
		if(!gang)
			error("帮派状态不可用\n");
		mapping daily = gang["donate_daily"];
		if(!mappingp(daily))
			daily = gang["donate_daily"] = ([]);
		mapping record = daily[name];
		if(!valid_bangpai_ext_member_record(record) ||
		   (string)record["date"]!=today)
			record = daily[name] = (["date":today,"contrib":0]);
		int room = BANGPAI_EXT_DONATE_CONTRIB_DAILY-
			(int)record["contrib"];
		gained_contrib = amount/BANGPAI_EXT_DONATE_CONTRIB_PER;
		if(gained_contrib>room)
			gained_contrib = room<0 ? 0 : room;
		record["contrib"] = (int)record["contrib"]+gained_contrib;
		old_level = query_gang_level(bangid);
		gang["exp"] = (int)gang["exp"]+amount;
		gang["donation_total"] = (int)gang["donation_total"]+amount;
		add_contribution_locked(gang,name,gained_contrib,"donate");
		new_level = query_gang_level(bangid);
		bangpai_ext_append_audit(gang,"donate "+name+" "+amount);
		return bangpai_ext_save();
	});
	if(!saved)
		return (["ok":0,"message":"帮派状态繁忙，请稍后再试。"]);
	if(!me->pay_money(amount))
		return (["ok":0,"message":"身上银两不足。"]);
	me->save_with_result();
	if(new_level>old_level)
		BANGD->bang_notice(bangid,"帮派建设度提升！帮派等级升到"+
			new_level+"级。\n");
	return (["ok":1,"gained_contrib":gained_contrib,
		"level":new_level,"leveled":new_level>old_level]);
}

/** my_bang 页面用的概览。 */
mapping query_gang_summary(object player)
{
	if(!player || !(int)player->bangid)
		return 0;
	int bangid = (int)player->bangid;
	mapping gang = bangpai_ext_gang_record(bangid);
	int level = query_gang_level(bangid);
	int next_cost = query_gang_next_level_cost(bangid);
	return ([
		"level":level,
		"exp":gang ? (int)gang["exp"] : 0,
		"donation_total":gang ? (int)gang["donation_total"] : 0,
		"next_cost":next_cost,
		"my_contrib":query_contribution(player),
		"boss_attempts":query_gang_boss_attempts_daily(bangid),
		"shop_unlocked":query_gang_shop_unlocked(bangid),
		"illusion_unlocked":query_gang_illusion_unlocked(bangid),
	]);
}

/** TestUnit 专用：切换测试状态文件并清缓存。 */
void set_state_file_for_test(int enable)
{
	bangpai_ext_state_file_override = enable;
	bangpai_ext_reload_cache(1);
}
