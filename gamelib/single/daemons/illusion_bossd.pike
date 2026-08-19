/**
 * S1 九卷战斗机制。
 *
 * 机制只在真实同房 S1 PVE 心跳中运行。永久进度仍由 seasonal_chard /
 * illusion_journeyd 保存；这里仅保存 NPC 本场战斗的临时预警与应对，
 * 不修改永恒服公式、PVP、快速战斗或人物技能。
 */

#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define BOSS_PENDING "/tmp/illusion_s1_boss_pending"

private mapping(string:mapping(string:mixed)) profiles = ([
	// 六类常规猎物只在较长战斗里低频触发。数值显著低于卷末首领，
	// 无人值守时也不会完成最后一击，既增加辨识度又不破坏挂机流程。
	"/gamelib/clone/npc/illusion_s1/moon_wisp.pike":([
		"id":"chasing_moon","name":"逐月回身","rank":"regular","action":"shade",
		"action_name":"踏入月影","cadence":12,"kind":"mana",
		"power_bp":120,"telegraph":"逐光月灵骤然折返，月芒正沿着你的影子追来。",
		"success":"你侧身踏入旧影，追来的月芒从肩畔掠过。",
		"failure":"月芒追上脚步，震散了少许仙力。",
	]),
	"/gamelib/clone/npc/illusion_s1/fog_wolf.pike":([
		"id":"fog_pounce","name":"雾狼扑月","rank":"regular","action":"brace",
		"action_name":"稳住下盘","cadence":13,"kind":"life",
		"power_bp":140,"telegraph":"雾纹月狼伏低身形，雾气中只剩一双逼近的眼睛。",
		"success":"你稳住下盘，在狼影扑至的一瞬错开锋芒。",
		"failure":"狼影从雾中扑出，在你身上留下一道浅伤。",
	]),
	"/gamelib/clone/npc/illusion_s1/mirror_spider.pike":([
		"id":"mirror_web","name":"镜丝缚影","rank":"regular","action":"break",
		"action_name":"震碎镜丝","cadence":14,"kind":"life_mana",
		"power_bp":120,"telegraph":"镜丝月蛛把细丝钉入倒影，蛛网正从镜面两侧合拢。",
		"success":"你以真气震碎倒影，尚未闭合的镜丝随之断裂。",
		"failure":"镜丝同时勒住气血与神识，留下短暂刺痛。",
	]),
	"/gamelib/clone/npc/illusion_s1/ruin_guard.pike":([
		"id":"broken_star_guard","name":"折星归垒","rank":"regular","action":"flank",
		"action_name":"绕击星核","cadence":14,"kind":"heal",
		"power_bp":160,"telegraph":"折星石卫收拢碎甲，正要把散落星屑重新压回核心。",
		"success":"你绕至石卫侧后击中星核，未让碎甲重新闭合。",
		"failure":"星屑归垒，石卫借机修补了少许裂痕。",
	]),
	"/gamelib/clone/npc/illusion_s1/star_wraith.pike":([
		"id":"old_city_loop","name":"旧城回梦","rank":"regular","action":"wake",
		"action_name":"唤醒本心","cadence":15,"kind":"mana",
		"power_bp":180,"telegraph":"古城星魇摊开一段温暖旧梦，试图让你忘记此行目的。",
		"success":"你念出此行所求，旧梦像尘封窗纸般破开。",
		"failure":"你在旧梦中迟疑片刻，仙力随回忆悄然流散。",
	]),
	"/gamelib/clone/npc/illusion_s1/abyss_beast.pike":([
		"id":"abyss_bloom","name":"渊花噬月","rank":"regular","action":"pierce",
		"action_name":"刺穿花心","cadence":15,"kind":"life",
		"power_bp":180,"telegraph":"渊花异兽背上的月花骤然盛开，花心正凝聚一道幽光。",
		"success":"你抢先刺穿花心，幽光在成形前散入深渊。",
		"failure":"幽光擦过护体真气，灼去了一缕生机。",
	]),
	"/gamelib/clone/npc/illusion_s1/life_collector.pike":([
		"id":"life_threads","name":"众生寿线","action":"cut",
		"action_name":"斩断寿线","cadence":8,"kind":"life",
		"power_bp":220,"telegraph":"司寿使牵起黑金寿线，要把你的余寿织入官袍。",
		"success":"你抢在寿线收紧前一剑斩断，夺回了自己的名字。",
		"failure":"寿线收紧，强行抽走了你的一缕生机。",
	]),
	"/gamelib/clone/npc/illusion_s1/fog_trial_warden.pike":([
		"id":"fog_oath","name":"雾誓回声","action":"speak",
		"action_name":"说出真誓","cadence":9,"kind":"mana",
		"power_bp":520,"telegraph":"雾中响起与你一模一样的声音，正诱你重复一句假誓。",
		"success":"你说出真正想守住的誓言，雾中的假声当场碎裂。",
		"failure":"假誓钻入识海，扰乱了你的仙力。",
	]),
	"/gamelib/clone/npc/illusion_s1/empty_sutra_abbot.pike":([
		"id":"blank_sutra","name":"空经反字","action":"refuse",
		"action_name":"拒写假经","cadence":10,"kind":"heal",
		"power_bp":180,"telegraph":"空经方丈展开无字经，逼你替他写下众生皆有价。",
		"success":"你把笔折成两段，空经上的伪字随风消散。",
		"failure":"你的一瞬迟疑被写进经页，方丈借此恢复伤势。",
	]),
	"/gamelib/clone/npc/illusion_s1/mirror_weaver.pike":([
		"id":"mirror_truth","name":"镜湖辨真","action":"truth",
		"action_name":"直面真影","cadence":9,"kind":"life",
		"power_bp":280,"telegraph":"织镜者展开三重倒影，最完美的一面正向你招手。",
		"success":"你击碎完美假象，选择了带着伤痕却真实的自己。",
		"failure":"假象在镜中反噬，割开了你不愿面对的旧伤。",
	]),
	"/gamelib/clone/npc/illusion_s1/frozen_age_king.pike":([
		"id":"borrowed_yesterday","name":"借日归还","action":"return",
		"action_name":"归还昨日","cadence":8,"kind":"mana",
		"power_bp":650,"telegraph":"冻龄王捧来一个完美昨日，只要你永远留在其中。",
		"success":"你亲手归还昨日，记忆没有消失，却不再成为牢笼。",
		"failure":"昨日覆上今朝，带走了维系当下的仙力。",
	]),
	"/gamelib/clone/npc/illusion_s1/frost_inquisitor.pike":([
		"id":"ice_testimony","name":"冰墙共证","action":"witness",
		"action_name":"举证冰墙","cadence":10,"kind":"life_mana",
		"power_bp":240,"telegraph":"霜审官要抹去冰墙证词，并把沉默判作所有人的罪。",
		"success":"你逐字念出冰墙证词，旁观者的沉默终于被打破。",
		"failure":"审槌落下，寒意同时侵入血脉与识海。",
	]),
	"/gamelib/clone/npc/illusion_s1/sunrise_guardian.pike":([
		"id":"one_day_promise","name":"朝暮一诺","action":"keep",
		"action_name":"守住一日","cadence":8,"kind":"heal",
		"power_bp":220,"telegraph":"朝生守关者问：只存在一天的约定，还值得守吗？",
		"success":"你以今日作答：短暂从来不是背弃承诺的理由。",
		"failure":"你的迟疑让朝暮倒转，守关者借日光重整气息。",
	]),
	"/gamelib/clone/npc/illusion_s1/eclipse_priest.pike":([
		"id":"fourth_shadow","name":"灯下辨伪","action":"expose",
		"action_name":"照出伪影","cadence":9,"kind":"life_mana",
		"power_bp":300,"telegraph":"蚀月祭司藏进第四种影子，伪造的残方正覆盖真实来路。",
		"success":"你把灯移到证词背后，第四种影子无处遁形。",
		"failure":"伪影穿身而过，同时撕扯你的生机与仙力。",
	]),
	"/gamelib/clone/npc/illusion_s1/newmoon_lord.pike":([
		"id":"human_register","name":"人间归名","action":"name",
		"action_name":"归还姓名","cadence":7,"kind":"life_mana",
		"power_bp":380,"telegraph":"归真月主翻开无名册，要以长生抹去你一路记住的所有人。",
		"success":"你念出众生之名。月光没有替他们长生，却证明他们来过。",
		"failure":"无名月潮压下，逼你同时付出生机与仙力。",
	]),
]);

private string normalized_path(object value)
{
	string path;
	if(!value)
		return "";
	path=file_name(value);
	if(has_prefix(path,ROOT))
		path=path[sizeof(ROOT)..];
	if(search(path,"#")!=-1)
		path=(path/"#")[0];
	return path;
}

private mapping profile_for(object boss)
{
	string path=normalized_path(boss);
	return mappingp(profiles[path]) ? (mapping)profiles[path] : ([]);
}

private object|zero pending_player_in_room(object boss,string userid)
{
	object room=boss ? environment(boss) : 0;
	if(!room || userid=="")
		return 0;
	foreach(all_inventory(room,boss),object candidate)
		if(candidate && functionp(candidate->is) && candidate->is("player") &&
		   functionp(candidate->query_name) &&
		   (string)candidate->query_name()==userid)
			return candidate;
	return 0;
}

private int valid_s1_target(object boss,object player)
{
	mapping progress=([]);
	mixed progress_err;
	if(!boss || !player || !player->is("player") ||
	   environment(boss)!=environment(player) ||
	   !LOGICALZONED->can_action("combat",boss,player))
		return 0;
	if((functionp(boss->get_cur_life) && boss->get_cur_life()<=0) ||
	   (functionp(player->get_cur_life) && player->get_cur_life()<=0))
		return 0;
	if(getenv("XIAND_RUN_TESTUNIT")=="1" &&
	   has_prefix((string)player->query_name(),"__testunit_illusion_boss_") &&
	   (int)player["/tmp/illusion_boss_test_s1"])
		return 1;
	// 赛季进度是首领机制的附加资格。瞬时索引/配置异常只关闭本次
	// 机制，不能让玩家主动应对命令产生空响应，也不能越界到永恒服。
	progress_err=catch{ progress=SEASONALD->query_player_progress(player); };
	if(progress_err || !mappingp(progress))
		return 0;
	return (int)progress["ok"] &&
		(string)progress["illusion_id"]=="S1" &&
		(string)progress["mode"]=="season";
}

private string nonce_for(object boss,object player,int tick)
{
	object hash=Crypto.SHA256();
	// 保留 clone 实例编号。同一玩家可能同时被两只同模板首领预警；若只
	// 使用归一化模板路径，两只怪在同一秒同一节拍会生成相同 nonce。
	hash->update((string)file_name(boss)+"|"+(string)player->query_name()+
		"|"+(string)tick+"|"+(string)time());
	return lower_case(String.string2hex(hash->digest()))[..15];
}

private int bounded_loss(object player,int basis_points,int mana)
{
	int maximum=mana ? (int)player->query_mofa_max() :
		(int)player->query_life_max();
	int current=mana ? (int)player->get_cur_mofa() :
		(int)player->get_cur_life();
	int amount=maximum*basis_points/10000;
	if(amount<1)
		amount=1;
	if(mana){
		if(amount>current)
			amount=current;
		player->set_mofa(current-amount);
	}
	else{
		// 机制失误本身不会完成最后一击，死亡仍只走既有战斗结算。
		if(amount>=current)
			amount=current>1 ? current-1 : 0;
		player->set_life(current-amount);
	}
	return amount;
}

private void resolve_pending(object boss,object player,mapping profile,
	mapping pending)
{
	string expected=(string)profile["action"];
	string answer=(string)(pending["answer"] || "");
	string kind=(string)profile["kind"];
	int power=(int)profile["power_bp"];
	int life_loss;
	int mana_loss;
	int healed;
	if(answer==expected){
		tell_object(player,"§g【机制应对成功·"+(string)profile["name"]+
			"】§r "+(string)profile["success"]+"\n");
		return;
	}
	if(kind=="life" || kind=="life_mana")
		life_loss=bounded_loss(player,power,0);
	if(kind=="mana")
		mana_loss=bounded_loss(player,power,1);
	else if(kind=="life_mana")
		mana_loss=bounded_loss(player,power,1);
	else if(kind=="heal"){
		int maximum=(int)boss->query_life_max();
		int before=(int)boss->get_cur_life();
		int after=min(maximum,before+maximum*power/10000);
		boss->set_life(after);
		healed=after-before;
	}
	tell_object(player,"§r【机制失误·"+(string)profile["name"]+"】§r "+
		(string)profile["failure"]+
		(life_loss ? "（生命 -"+(string)life_loss+"）" : "")+
		(mana_loss ? "（仙力 -"+(string)mana_loss+"）" : "")+
		(healed ? "（"+((string)profile["rank"]=="regular" ?
			"敌人" : "首领")+"恢复 "+(string)healed+"）" : "")+"\n");
}

void tick(object boss,object player)
{
	mapping profile=profile_for(boss);
	mapping pending;
	object pending_player;
	int tick;
	int cadence;
	int minimum_tick;
	if(!sizeof(profile))
		return;
	tick=(int)boss->timeCount;
	pending=mappingp(boss[BOSS_PENDING]) ?
		(mapping)boss[BOSS_PENDING] : ([]);
	if(sizeof(pending)){
		// reset_targets() 会把 timeCount 归零。若首领未析构而同一玩家
		// 立刻重开战斗，上一场预警绝不能跨场延续；状态签名异常也直接
		// 丢弃，绝不按当前首领配置猜测结算。
		if((string)pending["profile"]!=(string)profile["id"] ||
		   tick<(int)pending["created_tick"]){
			boss->m_delete_foruser(BOSS_PENDING);
			return;
		}
		pending_player=player && functionp(player->query_name) &&
			(string)pending["target"]==(string)player->query_name() ? player :
			pending_player_in_room(boss,(string)pending["target"]);
		// 组队首领可能在两个心跳间切换最高仇恨目标。预警必须继续跟随
		// 最初被点名且仍在同房参战的玩家，不能因 action_enemy 改变就
		// 静默删除；真正离场、死亡或脱离仇恨后才安全清理。
		if(!pending_player || !valid_s1_target(boss,pending_player) ||
		   (!(getenv("XIAND_RUN_TESTUNIT")=="1" &&
		      (int)pending_player["/tmp/illusion_boss_test_s1"]) &&
		    (!functionp(boss->if_in_targets) ||
		     !boss->if_in_targets(pending_player)))){
			boss->m_delete_foruser(BOSS_PENDING);
			return;
		}
		if(tick>=(int)pending["resolve_tick"]){
			resolve_pending(boss,pending_player,profile,pending);
			boss->m_delete_foruser(BOSS_PENDING);
		}
		return;
	}
	// 已有预警必须优先按原点名玩家结算；当前仇恨目标可能在下一拍
	// 临时切到宠物、召唤物或无效对象。只有创建新预警时，才要求
	// 本拍 action_enemy 是合法的同房 S1 玩家。
	cadence=(int)profile["cadence"];
	minimum_tick=(string)profile["rank"]=="regular" ? cadence+2 : 2;
	if(tick<minimum_tick || cadence<6 || tick%cadence!=2)
		return;
	// 账号世界索引不进入每个Boss攻击心跳的热路径；只有真正到达
	// 预警节拍时才验证S1身份。机制频率和安全边界不变，索引读取量
	// 从每拍一次降为每8至10拍一次。
	if(!valid_s1_target(boss,player))
		return;
	string nonce=nonce_for(boss,player,tick);
	boss[BOSS_PENDING]=([
		"profile":(string)profile["id"],
		"target":(string)player->query_name(),
		"nonce":nonce,"created_tick":tick,
		"resolve_tick":tick+2,"answer":"",
	]);
	string warning=(string)profile["rank"]=="regular" ?
		"战斗预警" : "首领预警";
	tell_object(player,"§y【"+warning+"·"+(string)profile["name"]+"】§r "+
		(string)profile["telegraph"]+"\n"+
		"[立即"+(string)profile["action_name"]+":illusion_boss answer "+
		(string)profile["id"]+" "+(string)profile["action"]+" "+nonce+"]\n");
}

mapping(string:mixed) answer(object player,string profile_id,string action,
	string nonce)
{
	object room;
	int target_pending_found;
	if(!player || profile_id=="" || action=="" || nonce=="")
		return (["ok":0,"message":"战斗应对参数不完整，本次未产生任何效果。"]);
	room=environment(player);
	if(!room)
		return (["ok":0,"message":"当前场景无效，不能进行战斗应对。"]);
	foreach(all_inventory(room,player),object boss){
		mapping profile=profile_for(boss);
		mapping pending=mappingp(boss[BOSS_PENDING]) ?
			(mapping)boss[BOSS_PENDING] : ([]);
		if(!sizeof(profile) || (string)profile["id"]!=profile_id ||
		   !sizeof(pending) ||
		   (string)pending["profile"]!=(string)profile["id"])
			continue;
		// 同房可能同时刷新两只同类首领，并各自与不同玩家交战。
		// 先跳过属于别人的预警，再校验本人的 nonce；否则房间枚举碰到
		// 第一只同名首领时就提前返回，会让第二名玩家永远无法应对。
		if((string)pending["target"]!=(string)player->query_name())
			continue;
		target_pending_found = 1;
		// 同一玩家可能同时面对两只同模板首领。不同 nonce 表示另一只
		// 合法预警，必须继续枚举，不能让房间顺序截断真正目标。
		if((string)pending["nonce"]!=nonce)
			continue;
		if(!valid_s1_target(boss,player) ||
		   (int)pending["resolve_tick"]<(int)boss->timeCount)
			return (["ok":0,"message":"这次战斗预警已经失效，请等待下一次真实预警。"]);
		if(action!=(string)profile["action"])
			return (["ok":0,"message":"这不是当前机制的正确应对，本次没有提前结算。"]);
		pending["answer"]=action;
		boss[BOSS_PENDING]=pending;
		return (["ok":1,"message":"你已选择【"+
			(string)profile["action_name"]+"】，下一战斗节拍将按真实应对结算。"]);
	}
	if(target_pending_found)
		return (["ok":0,"message":"这次战斗预警已经失效，请等待下一次真实预警。"]);
	return (["ok":0,"message":"当前房间没有与你交战且正在预警的S1敌人。"]);
}

array(mapping(string:mixed)) query_catalog_for_test()
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1")
		return ({});
	array rows=({});
	foreach(sort(indices(profiles)),string path)
		rows+=({copy_value(profiles[path])+(["path":path])});
	return rows;
}

mapping(string:mixed) query_pending_for_test(object boss)
{
	if(getenv("XIAND_RUN_TESTUNIT")!="1" || !boss)
		return ([]);
	return copy_value(mappingp(boss[BOSS_PENDING]) ?
		(mapping)boss[BOSS_PENDING] : ([]));
}
