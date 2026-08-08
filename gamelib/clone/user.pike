#include <globals.h>
#include <gamelib/include/gamelib.h>
#include <gamelib.h>
inherit WAP_USER;
//用户仓库继承类
inherit GAMELIB_PACKAGED;
#define SAVE_TIME 30 //30秒存一次
//增加新用户注册时间记录                                                                            
string user_reg_time;

//多人物账号归属。旧人物没有此字段时，其人物ID本身就是注册账号ID。
//等级、技能、装备、任务、VIP和家园仍保存在每个独立人物档案中。
string account_owner;
void set_account_owner(string userid)
{
	account_owner = userid;
}
string query_account_owner()
{
	if(account_owner && sizeof(account_owner))
		return account_owner;
	return query_name();
}

// 复活点必须是地图内、源码明确暴露 set_relife 链接的卧室。
// 既用于设置命令，也用于清理历史上可能被伪造的存档路径。
int is_valid_relife_path(string path)
{
	string source;
	object room;
	mixed err;
	if(!path || path=="" || search(path,"/gamelib/d/")!=0 ||
	   search(path,"..")!=-1 || search(path,"#")!=-1)
		return 0;
	source = Stdio.read_file(ROOT+path);
	if(!source || search(source,"[设置复活点:set_relife ")==-1)
		return 0;
	err=catch {
		room=(object)(ROOT+path);
	};
	if(err || !room || !functionp(room->is_bedroom) || !room->is_bedroom())
		return 0;
	return 1;
}

//无论玩家通过幻境按钮、传送、复活还是管理命令离开，
//只要真正从副本房间移到普通房间，就统一清理副本成员状态。
int move(mixed dest)
{
	object old_env = environment(this_object());
	object new_env;
	if(TIMED_EVENTD->guard_player_move(this_object(),dest))
		return 0;
	int old_was_fb = old_env &&
		FBD->is_fb_room_path(file_name(old_env));
	int moved = ::move(dest);
	new_env = environment(this_object());
	if(moved && old_was_fb && old_env!=new_env &&
	   (!new_env || !FBD->is_fb_room_path(file_name(new_env))))
		FBD->detach_fb_member(this_object());
	return moved;
}

//推荐人标示，由liaocheng于07/08/23添加，用于人推人系统
int all_mark;//总的积分
int cur_mark;//当前积分
int all_fee;//玩家捐赠的总数(以 碎玉 为单位)
string set_presenter;
mapping home_rights;//家园权限标识 add by caijie 080923
mapping pic_flag;

//杀戮标示，用于判断同阵营间是杀戮还是决斗
//由liaocheng 于 08/08/30 添加
int kill_flag;

int get_gift;//获得活动赠送物品的标识，1=已领取，0=未领取，每天一次刷新
mapping(string:int) get_once_day=([]);//记录每天领一次的物品领取情况
string last_pos;//最后登陆房间记录
string term;//队伍标志
string chatid;//聊天频道标志
int honerpt;//荣誉值
int honerlv;//荣誉等级
int killcount;//杀人记录
int lunhuipt;//轮回值
string relife;//复活点记录
string mobile;//帐号绑定的手机号码
int yushi_flag;//用于推广升级换玉石活动的相关标志位
mapping(string:mapping(int:int)) package_expand;//背包扩充标识，added by caijie 08/10/08

int ljs_time;//鎏金石有效时间
string ljs_sw;//鎏金石开关

//挂机升级相关字段 Evan 2008.11.20
int auto_learn_dazuo;// 打坐剩余时间
int query_auto_learn_dazuo(){
	return auto_learn_dazuo;
}
int max_yao;
int query_max_yao(){
	object me=this_player();
	int vip_flag = 0;
	if(me && me->query_vip_flag) {
		vip_flag = me->query_vip_flag();
	}
	max_yao=5*(vip_flag+1);
	//werror("========me->query_vip_flag() "+me->query_vip_flag()+"\n");
	return max_yao;
}
string query_max_yao_info(){
	string s="会员最大食用次数:\n";
	s+="水晶会员10次\n";
	s+="黄金会员15次\n";
	s+="白金会员20次\n";
	s+="钻石会员25次\n";
	s+="捐赠获得会员 QQ：1811117272\n";
	return s;
}
void set_auto_learn_dazuo(int s)
{
	auto_learn_dazuo = s;
}
int auto_learn_xiuchan;// 修禅剩余时间
int query_auto_learn_xiuchan(){
	return auto_learn_xiuchan;
}
void set_auto_learn_xiuchan(int s)
{
	auto_learn_xiuchan = s;
}
//end of Evan 2008.11.20

// HTTP API 模式标记：用于标识从 HTTP API 登录的玩家，跳过 exec() 避免 Request 对象被析构
int http_api_mode;

// 设置 HTTP API 模式
void set_http_api_mode(int value) {
    http_api_mode = value;
}

// 查询 HTTP API 模式状态
int query_http_api_mode() {
    return http_api_mode;
}

string inhome_pos;//玩家在某个home(家园系统)中的标志 Evan 2008.08.29 

int home_yushi;
int home_money;
void set_home_sale(int money_fg,int price){
	if(money_fg==1){
		home_yushi += price;
	}
	else if(money_fg==0){
		home_money += price;
	}
}

string query_inhome_pos(){
	return inhome_pos;
}
void set_inhome_pos(string masterName)
{
	inhome_pos = masterName;
}
//end of Evan added 2008.08.29

string home_path;//玩家是否拥有home的标志  Evan 2008.09.16
string query_home_path(){
	return home_path;
}
void set_home_path(string a)
{
	home_path = a;
}
//end of Evan added 2008.09.16


//一开始免费20个位置
//每增加10个位置100g,总共能买8次，放置100个物品
int packageLevel = 20;

//add by calvin 20080806
string bandpswd;//安全码变量

string query_bandpswd_link(){
	if(bandpswd&&sizeof(bandpswd))
		return "";
	else
		return "[设定安全码:set_bandpsw]";
}
//add by calvin 20080806

//和会员制度相关的字段和存、取方法  added by evan 2008.07.16
int vip_flag;      //会员标志 0:非会员 1:水晶会员  2:黄金会员  3:白金会员  4:钻石会员
int vip_end_time;  //会员到期时间 
mapping(int:int) vip_history=([]);//玩家会员历史记录 【结构  会员到期时间:会员等级】
void add_vip_history(int endtime,int level){  //向历史记录中添加相关信息
	vip_history[endtime] = level;
}
//end of evan added


/**
 * 游戏中的关注系统
 * @author evan 
 * 2008/07/06
 * 
 *【数据结构】
 * 1、mapping(string:int) spy_info  每个玩家的资料中都将增加这个字段，用于记录其所关注的玩家
 *      其中，string:  所关注的玩家id
 *               int： 关注标志位，"1"表示某玩家已在关注列表中，但是尚未付费进行关注操作
 *		                   "*****"表示已经开始关注该玩家，其具体数值为开始关注的时间
 * 2、int spy_flush_time       每次关注的持续时间
 * 3、int spy_max_num          每个玩家可以关注的最大数量
 *
 *【方法说明】
 * insert_spy_info()  将某个玩家添加到关注列表
 * delete_spy_info()  将某个玩家从关注列表中删除
 * start_spy()        开始关注某个玩家
 * query_spy_info()   显示所有的关注信息
 * is_spied()         判断某个玩家是否处于"关注"状态
 *
 *【实现逻辑】
 *  1、spy_info中记录了每个玩家的关注列表，当用户的关注内容发生变化时，该字段发生相应变化；
 *  2、query_spy_info()将得到spy_info中的所有信息，展示在页面上，从而实现关注功能 
 */
mapping(string:int) spy_info =([]);       //记录关注列表  结构："玩家名:开始关注时间"
protected int spy_flush_time = 3600;         //每次关注的持续时间
protected int spy_max_num =10;               //每个玩家可以关注的最大数量

/*  【功能】  将玩家添加到关注列表中
    【变量】  id:玩家ID
    【返回值】   0:所关注的玩家数达到上限
1:该玩家已在关注列表中，无需再添加
2:添加成功
 * @author evan 
 * 2008/07/06
 */
int insert_spy_info(string id)
{
	int re = 0;
	if(!LOGICALZONED->can_user_interact(query_name(),id))
		return 0;
	if(sizeof(spy_info)<spy_max_num)    //每个玩家最多可以关注spy_max_num个目标
	{
		if(!spy_info[id])           //本次添加的玩家未在列表中
		{
			spy_info[id]= 1;    //将该人添加到列表中。"1"表示该玩家在列表中，但尚未付费开始关注。    
			re=2;               //添加成功
		}
		else
			re = 1;             //该人已在列表中，无需再添加
	}
	else
		re = 0;                     //已经达到人数上限，不能再添加                      
	return re;
}

/*  【功能】  开始关注某个玩家
    【变量】  id:玩家ID
    【返回值】   0:此人已经处于关注状态下，不能重复关注
1:关注成功
 * @author evan 
 * 2008/07/06
 */
int start_spy(string id)
{
	int re = 0;
	if(!LOGICALZONED->can_user_interact(query_name(),id))
		return 0;
	if(!is_spied(id))                   //尚未开始关注此人。
	{   
		spy_info[id] = time();      //开始关注的时间
		re = 1;                     //开始关注成功
	}
	return re;
}

/*  【功能】  展示当前玩家的所有关注信息
    【返回值】  string re:该字符串直接写入到游戏中即可，展示当前玩家的所有关注信息。
 * @author evan 
 * 2008/07/06
 */
string qurey_spy_info()
{
	string re ="";
	array(string) all_user = indices(spy_info);
	object tmp_user;
	int load_flag = 0;
	if(sizeof(all_user)==0)
		re += "你还没有关注的对象\n";
	else{
		re += "当前关注的玩家：\n";
		re += "\n";
		foreach(all_user,string single)//轮询得到关注列表中的所有信息
		{
			if(single=="")
				continue;
			if(!LOGICALZONED->can_user_interact(query_name(),single))
				continue;
			tmp_user = find_player(single);
			if(!tmp_user)
			{
				tmp_user = load_player(single); // 使用当前玩家加载，无需依赖其他在线用户。
				load_flag =1;
			}
			if(tmp_user)
			{
				re += tmp_user->query_name_cn();
				if(is_spied(single))                              //此人正在关注状态下
				{
					if(load_flag)                             //如果此人不在游戏中，则显示"离线"
						re += " 离线 ";
					else
						re += " "+environment(tmp_user)->query_name_cn();  //得到此人所在房间   
				}
				else{
					re +="  [关注:spy_start "+single+"]";
				}
				re += "  [删除:spy_del "+ single +"]\n";
			}
			if(load_flag)
			{
				tmp_user->remove(); //将加载的玩家踢下线，同时改变标志位。
				load_flag=0;
			}
		}
		re += "\n\n[刷新看看:spy_mylist]\n";
	}
	return re;
}

/*  【功能】  将玩家冲关注列表中删除
    【变量】  id:玩家ID
    【返回值】   0:删除失败
1:该玩家已经不在列表中
2:删除成功
 * @author evan 
 * 2008/07/06
 */
int delete_spy_info(string id)
{
	int re = 0; 
	if(!spy_info[id]) re = 1;
	else{
		spy_info = spy_info - ([id:1]);
		if(spy_info)re = 2;
	}
	return re;
}
//=== 判断某个用户是否正处于关注状态 ===//
/*  【功能】  判断某个用户是否正处于关注状态
    【变量】  id:玩家ID
    【返回值】   0:不再关注状态
1:处于关注状态
 * @author evan 
 * 2008/07/06
 */
int is_spied(string id)
{
	int re = 0;
	if(spy_info[id]&&(time()-spy_info[id])<spy_flush_time)
		re =1;
	return re;
}
//========================== End of evan added 2008.07.07 ==============================//


void set_term(string t){
	// 队伍护盾只属于施法时的队伍。离队、被踢、解散或加入另一队时
	// 立即清除，避免短时间把上一支队伍的保护带入新队。
	if(query_term()!=t && query_buff("team_guard",0)!="none")
		clean_buff("team_guard");
	if(query_term()!=t)
		clean_lingyi_medicine_pacts();
	term = t;
}
	string query_term(){
		if(term&&sizeof(term))
			return term;
		else
			return "noterm";
	}
void set_chatid(string t){
	chatid = t;
}
string query_chatid(){
	return chatid;
}

string query_honer_desc(){
	object me = this_object();
	return WAP_HONERD->query_honer_level_desc(me->honerlv,me->query_raceId());
}

//新添加的mobile属性的query和set方法；evan added 2007.12.06
string query_mobile(){
	return mobile;
}
void set_mobile(string|zero arg){
	mobile = arg;
}
//新添加的yushiflag属性的query和set方法
int query_yushi_flag(){
	return yushi_flag;
}
void set_yushi_flag(int arg){
	yushi_flag = arg;
}
//end of evan added 2007.12.06

string game_fg;//合区的原区域 标识



int fee;//天下币
array(string) query_command_prefix(){
	return ({ROOT+"/gamelib/cmds/",})+::query_command_prefix();
}
/////////////////////////////////////////////////////
protected protected protected protected protected void create(){
	::create();
	//term = "noterm";
	picture = "nosex";	
	living_time=10*60;
	// 只有定时存档才续排下一次，避免手动 save 叠加多条定时链。
	call_out(save,SAVE_TIME,1);
}
string query_extra_links(void|int count)
{
	object env=environment(this_object());
	object me = this_player();
	USERD->check_daily(me);//检查每天需要重置的事项，包括吃药啊等等
	if(env&&env->is("menu")){
		return "";
	}
	string addstr = "[注册帐号:reg_account]\n";
	string status = "";
	if(me->query_profeId()=="yinggui" && me->hind == 1){
		status = "(影遁状态)";
		if(me->query_buff("spec_attack_buff",0) == "jinchanmeiying2")
			status += "(+"+me->query_buff("spec_attack_buff",1)+"%)";
	}
	string topten= "[排行榜:look_top]\t";
	string returnLinks="[刷新:look]"+topten+status+"\n[状态:myhp](生命"+this_player()->get_cur_life()+"/"+this_player()->query_life_max()+")\n[技能:myskills](法力"+this_player()->get_cur_mofa()+"/"+this_player()->query_mofa_max()+")\n[物品:inventory]|[地图:map_display]|[队伍:my_term]|[玉石:yushi_change]\n[任务:mytasks]|[万灵:pet]|[帮派:my_bang]|[江湖:my_games]\n[限时玩法:timed_event]|[传送:userlist]|[仙玉:yushi_myzone]|[设置:game_detail]|[会员:vip_service_list]|[url 首页:http://www.wapmud.com/gamehome/]\n";
	if(env && FBD->is_fb_room_path(file_name(env)))
		returnLinks = "【幻境安全通道】[紧急离开幻境:fb_leave]\n"+
			returnLinks;
	if(me->query_autofight()=="enable")
		returnLinks = "[停止自动挂机:autofightclose]\n"+returnLinks;
	else
		returnLinks = "[自动打怪／挂机:autofight open]\n"+returnLinks;
	if(me->query_level() <= 10)
		returnLinks = "【新手助手】[新手引导:newbie_guide]|[自动穿装:auto_equip]\n" + returnLinks;
	//string returnLinks="[刷新:look]"+status+"\n[状态:myhp](生命"+this_player()->get_cur_life()+"/"+this_player()->query_life_max()+")\n[技能:myskills](法力"+this_player()->get_cur_mofa()+"/"+this_player()->query_mofa_max()+")\n[物品:inventory]|[地图:map_display]|[任务:mytasks]\n[队伍:my_term]|[好友:my_qqlist]\n[聊天:chatroom_list]|[玩家:userlist]\n[我的帮派:my_bang]\n[仙玉妙坊:yushi_myzone]\n[游戏设置:game_detail]\n[url 仙道官方站:http://xd.dogstart.com]\n";
	if(this_player()->sid == "5dwap")
		returnLinks += addstr;
	//returnLinks += "[邮箱:1811117272@qq.com]\n";
	returnLinks += "--------\n";
	//returnLinks += "仙界时间\n"+TIMESD->query_cur_time()+"\n";
	returnLinks += TIPSD->get_tail_desc();
	///////////////////////////////////////////////////////
	string powers = MANAGERD->checkpower(me->name);
	if(powers=="admin"||powers=="assist")
		returnLinks += "\n[在线管理平台入口:game_deal]\n"; 
	///////////////////////////////////////////////////////
	return returnLinks;
}

int save_with_result(void|int autosave){
	object env=environment(this_object());
	if(this_object()->sid == "5dwap"){
		//tell_object(this_object(),"欢迎尝试仙道，您现在是游客身份，你的档案将不会被保存，欢迎点击注册一个正式帐号来体验仙道的乐趣。\n[注册帐号:reg_account]\n");
		this_object()->command("quit");
		return 0;
	}
	// 先排好下一次：即使排行榜或文件存档抛异常，定时链也不会永久中断。
	if(autosave)
		call_out(save,SAVE_TIME,1);
	if(env&&!env->is("character")&&!env->is("menu")&&
	   !TIMED_EVENTD->is_event_room(env)){
		last_pos=file_name(env)-ROOT;
	}
	string now=ctime(time());
	//更新排行榜数据
	string zhenying="【仙】";
	if(this_object()->query_raceId()=="monst")
		zhenying="【妖】";
	else if(this_object()->query_raceId()=="third"){
		if(this_object()->query_profeId()=="zhenyue")
			zhenying="【越】";
		else if(this_object()->query_profeId()=="tianxiang")
			zhenying="【象】";
		else if(this_object()->query_profeId()=="lingyi")
			zhenying="【医】";
		else
			zhenying="【方】";
	}
	string topname = this_object()->query_name_cn()+"("+this_object()->query_level()+"级)"+zhenying;
	TOPTEN->try_top(this_object()->query_name(),topname,"等级",this_object()->query_level());
	TOPTEN->try_top(this_object()->query_name(),topname,"富翁",this_object()->query_account());
	if(this_object()->query_raceId()=="monst")
		TOPTEN->try_top(this_object()->query_name(),topname,"妖气",this_object()->honerpt);
	if(this_object()->query_raceId()=="human")
		TOPTEN->try_top(this_object()->query_name(),topname,"仙气",this_object()->honerpt);
	if(this_object()->query_raceId()=="third")
		TOPTEN->try_top(this_object()->query_name(),topname,"灵气",this_object()->honerpt);
	/*
	TOPTEN->try_top(this_object()->query_name(),topname,"攻击",this_object()->query_fight_attack());
	TOPTEN->try_top(this_object()->query_name(),topname,"防御",this_object()->query_defend_power());
	TOPTEN->try_top(this_object()->query_name(),topname,"躲闪",(int)this_object()->query_phy_dodge());
	TOPTEN->try_top(this_object()->query_name(),topname,"招架",(int)this_object()->query_phy_parry());
	TOPTEN->try_top(this_object()->query_name(),topname,"命中",(int)this_object()->query_phy_hitte());
	TOPTEN->try_top(this_object()->query_name(),topname,"暴击",(int)this_object()->query_phy_baoji());
	*/
	TOPTEN->try_top(this_object()->query_name(),topname+"("+this_object()->all_fee+")("+this_object()->name+")","捐赠",(int)this_object()->all_fee);
	//end 更新排行榜数据
	// 界面链接依赖 this_player 与当前地图，是动态缓存，不应持久化。
	// 关服连接或HTTP定时器上下文下强行序列化会调用 query_links，
	// 从而使整次玩家存档失败。
	this_object()->links = 0;
	this_object()->inventory_links = 0;
	if(YUSHID && functionp(YUSHID->prepare_wallet_payment_player_save))
		YUSHID->prepare_wallet_payment_player_save(this_object());
	int save_ok = ::save();
	// HTTP/Vue 玩家在界面切换时可能短暂不在地图中，不能因此中断存档链。
	// 玩家对象销毁时 Pike 会自动取消其 call_out。
	return save_ok;
}

void save(void|int autosave){
	save_with_result(autosave);
}
void remove(){
	SUMMOND->player_logout(this_object()->query_name());
	if(term && term != "noterm"){
		TERMD->leave_term(term,this_object()->query_name(),this_object()->query_name_cn()); 
	}
	::remove();
}
void fight_die()
{
	object me = this_object();
	string t = "";
	string w_kill = "";
	int my_level = me->query_level();
	object env =environment(me);//城战中加入，要是城战，装备耐久将会损耗很小
	me->red_flag=0;
	// 灵兽最后一击的PK、荣誉与击杀记录归属主人。
	enemy = SUMMOND->query_combat_credit_owner(enemy);
	// 限时活动死亡由活动状态机原子结算；不触发普通复活、掉级、耐久或荣誉流程。
	if(TIMED_EVENTD->handle_player_defeat(me,enemy))
		return;
	// 灵医百炼复苏必须在任何击杀奖励、死亡惩罚和召唤清理之前判定。
	// 成功代表人物没有真正死亡，后续死亡流程必须完整跳过。
	if(me->try_lingyi_auto_revive(enemy))
		return;
	// 无相化身（120 级被动）：每日一次免疫致命伤，必须在召唤清理前判定。
	if(me->try_wuxiang_avatar_revive(enemy))
		return;
	// 太极·生生不息（被动自复活）：5 分钟冷却，PVP 可触发。
	if(me->try_taiji_self_revive(enemy))
		return;
	// 灵医职业复苏优先；未触发时才判定隐藏鸾鸟的账号级回生羽。
	if(PETD->try_pet_owner_revive(me,enemy))
		return;
	// 所有免死/活动复活均未触发，只有真实死亡才累计挂机死亡循环。
	if(functionp(me->query_autofight) && me->query_autofight()=="enable")
		AUTOFIGHTD->record_afk_death(me);
	// 主人死亡时立即清理全部灵兽，不能继续留场攻击或治疗。
	SUMMOND->player_death(me->query_name());

	if(enemy)
		w_kill += enemy->query_name_cn();

	//获得杀人者应获得荣誉点，然后根据单杀或者团队杀分配
	//该接口不管是否得到荣誉点,都记录调用者即杀人者的杀人计数并++
	int gain_honer = 0;
	int gain_lunhui = 0;//轮回值
	//在这里也加入帮战获得霸气的值，由liaocheng于08/08/30 添加
	int gain_baqi = 0;
	if(enemy&&!enemy->is("npc")){
		if(me->query_level() - enemy->query_level()>5)
			;
		else {
			gain_honer = WAP_HONERD->honer_killed(enemy,me);
			gain_lunhui = WAP_HONERD->lunhui_killed(enemy,me);
		}
		//在这里也加入帮战获得霸气的值，由liaocheng于08/08/30 添加 
		if(enemy->bangid && me->bangid){
			if(BANGZHAND->is_in_bangzhan(enemy->bangid,me->bangid)){
				gain_baqi = BANGZHAND->get_baqi(enemy,me);
			}
		}
	}

	//如果被杀者有团队，告诉被杀者团队信息
	if(me->query_term()!=""&&me->query_term()!="noterm"){
		if(TERMD->query_termId((string)me->query_term()))
			if(w_kill&&sizeof(w_kill))
				TERMD->term_tell(me->query_term(),me->query_name_cn()+" 被 "+w_kill+" 杀死了。\n");
			else
				TERMD->term_tell(me->query_term(),me->query_name_cn()+" 已经死亡。\n");
	}
	///////////////////////////////////////////
	//如果杀人者有团队，告诉杀人者团队，谁杀了被击杀者，每个人分了多少荣誉值
	if(enemy&&!enemy->is("npc")&&enemy->query_term()!=""&&enemy->query_term()!="noterm"){
		//刷新队伍，看是否自动解散或队长解散
		TERMD->flush_term(enemy->query_term());
		//看队伍是否在内存
		if(TERMD->query_termId(enemy->query_term())){
			//获得团队内存mapping指针
			mapping(string:array) map_term = ([]);
			map_term = (mapping)TERMD->query_term_m(enemy->query_term());
			if(map_term&&sizeof(map_term)){
				array(int) level_tmp = TERMD->query_term_level(map_term);
				//假如团队中有队员等级超过被击杀目标等级5级，则给荣誉值和轮回值
				if(level_tmp[sizeof(level_tmp)-1]-my_level<=5){
					//是团队杀死,得到荣誉值，平均分配///////////////
					if(gain_honer>0){
						string tmp = "";
						if(enemy->query_raceId()=="human")
							tmp += "仙气";
						else if(enemy->query_raceId()=="third")
							tmp += "灵气";
						else
							tmp += "妖气";
						//荣誉点数量不变，然后平均分配给每个打怪的队员
						//如果只有一个人打，就把钱给那个打怪的队员了
						//1.先得到当前打这个怪的队员人数
						int t_count = 0;//sizeof(map_term);
						foreach(indices(map_term),string uid){
							object termer = find_player(uid);
							if(termer && environment(enemy) &&
							   environment(termer)){
								//判断是否一个房间，一个房间可以分配
								if(environment(enemy)==environment(termer))
									t_count++;
							}
						}
						// 队伍状态可能在死亡回调中变化；没有同房有效成员时
						// 保持奖励无人领取，但不能让除法异常中断死亡结算。
						if(t_count<1)
							t_count = 1;
						int t_money = gain_honer/t_count;
						if(t_money<=0)
							t_money = 1;
						//均分荣誉点给房间的队员	
						foreach(indices(map_term),string uid){
							int flag = 0;
							object termer = find_player(uid);
							if(termer && environment(enemy) &&
							   environment(termer)){
								//判断是否一个房间，一个房间可以分配
								if(environment(enemy)==environment(termer))
									flag = 1;
							}
							if(flag){//玩家在同一房间中
								//加入特药的荣誉加成，由liaocheng于07/11/21添加
								int te_honer = termer->query_buff("te_honer",1);
								if(te_honer){
									t_money = t_money+t_money*te_honer/100;
								}
								termer->honerpt+=t_money;
								//刷新得到荣誉者的荣誉表现
								termer->honerlv = WAP_HONERD->flush_honer_level(termer->honerpt,termer->honerlv);
								string mstr = "";
								mstr += enemy->query_name_cn()+" 杀死了 "+me->query_name_cn()+" 。\n";
								mstr += "你的 "+tmp+" 增加了 "+t_money+" 点。\n";
								//在这里也加入帮战获得霸气的值，由liaocheng于08/08/30 添加              
								if(gain_baqi)
									mstr += "你的帮派增加了 "+gain_baqi+" 点霸气。\n";
								tell_object(termer,mstr);
							}
						}
					}
					//获得轮回值
					if(gain_lunhui>0){
						string tmp = "";
						//1.先得到当前打这个怪的队员人数
						int t_count = 0;//sizeof(map_term);
						foreach(indices(map_term),string uid){
							object termer = find_player(uid);
							if(termer && environment(enemy) &&
							   environment(termer)){
								//判断是否一个房间，一个房间可以分配
								if(environment(enemy)==environment(termer))
									t_count++;
							}
						}
						if(t_count<1)
							t_count = 1;
						int t_lunhui = gain_lunhui/t_count;
						if(t_lunhui<=0){
							t_lunhui = 1;
						}
						if(me->query_raceId()=="human" || me->query_raceId()=="third"){
							t_lunhui = 0 - t_lunhui;
						}
						//均分轮回点给房间的队员	
						foreach(indices(map_term),string uid){
							int flag = 0;
							object termer = find_player(uid);
							if(termer && environment(enemy) &&
							   environment(termer)){
								//判断是否一个房间，一个房间可以分配
								if(environment(enemy)==environment(termer))
									flag = 1;
							}
							if(flag){//玩家在同一房间中
								termer->lunhuipt+=t_lunhui;//分配轮回值
								string mstr = "";
								mstr += "你的轮回值增加了 "+t_lunhui+" 点。\n";
								tell_object(termer,mstr);
							}
						}
					}
				}
			}
		}
	}
	else{
		//没有团队，单杀的
		if(enemy&&!enemy->is("npc")){
			tell_object(enemy,"你杀死了"+me->query_name_cn()+"。\n");
			if(enemy->query_level()-my_level<=5){
				if(gain_honer>0){
					string tmp = "";
					if(enemy->query_raceId()=="human")
						tmp += "仙气";
					else if(enemy->query_raceId()=="third")
						tmp += "灵气";
					else
						tmp += "妖气";
					//加入特药的荣誉加成，由liaocheng于07/11/21添加
					int te_honer = enemy->query_buff("te_honer",1);
					if(te_honer){
						gain_honer = gain_honer+gain_honer*te_honer/100;
					}
					enemy->honerpt += gain_honer;
					tell_object(enemy,"你的"+tmp+"增加了 "+gain_honer+" 点。\n");
					//刷新该击杀者的荣誉表现
					enemy->honerlv = WAP_HONERD->flush_honer_level(enemy->honerpt,enemy->honerlv);
				}
				//加入轮回值
				if(gain_lunhui>0){
					if(me->query_raceId()=="human" || me->query_raceId()=="third"){
						enemy->lunhuipt -= gain_lunhui;
					}
					else
						enemy->lunhuipt += gain_lunhui;
				}
				//在这里也加入帮战获得霸气的值，由liaocheng于08/08/30 添加
				string baqi_s = "";
				if(gain_baqi){
					baqi_s = "你的帮派增加了 "+gain_baqi+" 点霸气。\n";
					tell_object(enemy,baqi_s);
				}
			}
		}
	}
	//被对方杀死的惩罚
	if(me->sucide == 0){
		if(env->query_room_type() != "city"){
			if(w_kill&&sizeof(w_kill))
				t ="\n你被"+w_kill+"杀死了。所有装备当前耐久损失百分之一。\n";
			else
				t = "\n你已经死亡。所有装备当前耐久损失百分之一。\n";
			//死亡惩罚，所有装备当前耐久损失25%
			array(object) items=all_inventory(me);
			if(items&&sizeof(items)){
				for(int i=0;i<sizeof(items);i++){
					//每件装备的耐久损失
					if(items[i]->equiped && items[i]->item_dura<10000){
						if(items[i]->item_cur_dura>0){
							//items[i]->item_cur_dura -= items[i]->item_dura*25/100;
							items[i]->item_cur_dura -= items[i]->item_dura*1/100;//提高游戏易玩性，扣1%耐久度
							if(items[i]->item_cur_dura<=0)
								items[i]->item_cur_dura = 0;
						}
						else
							items[i]->item_cur_dura = 0;
					}
				}
			}
		}
		else{
			//城战时，将不会有装备的损耗惩罚
			if(w_kill&&sizeof(w_kill))
				t ="\n你被"+w_kill+"杀死了。\n";
			else
				t = "\n你已经死亡。\n";
		}
		//无论是被怪杀死还是被玩家杀死，都会损失经验
		//如果敌人是npc则不掉经验，如果和玩家pk则掉落经验
		if(enemy&&(enemy->query_level()-my_level<=5)&&!enemy->is_npc){
			//这里添加鎏金石使用效果，鎏金石效果用两个字段控制，一个是时间ljs_time，一个是使用开关ljs_sw，当时间用完后或者鎏金石处于关闭状态是被对方杀死会损失相应的经验
			if(!me->ljs_time||me->ljs_time<=0||(me->ljs_sw&&me->ljs_sw=="close")){
				int drop_exp = me->killed_exp(enemy);
				if(drop_exp){
					int del_result = me->del_exp(drop_exp);
					if(del_result==1){
						t += "等级降了1级\n";
					}
					else if(del_result==2){
						t += "同时损失"+drop_exp+"点经验\n";
					}
				}
			}
		}
	}
	else 
		t += "你服毒自杀了~~\n";
	tell_object(me,t);
	_clean_fight();
	if(enemy)
		enemy->clean_targets(me);
	//身上的药效消失
	me->reset_buff();

	//如果设置了复活点，从复活点复活，否则从默认阵营复活地复活
	//首先城战中死亡将被自动送往城池复活点
	if(env->query_room_type() == "city" &&
	   me->can_use_room_race(env->room_race)){
		string city_name = env->query_belong_to();                                                  
		string rest_room = CITYD->query_rest_room(city_name);
		if(rest_room && sizeof(rest_room)){
			mixed err=catch{
				(object)(rest_room);
			};
			if(!err){
				me->move(rest_room);
				return;
			}
		}
	}
	//如果设置了合法复活点则移动；路径无效或移动失败时必须回退默认广场。
	int moved_to_relife = 0;
	if(me->relife && me->is_valid_relife_path(me->relife)){
		mixed err=catch{
			moved_to_relife = me->move(ROOT+me->relife);
		};
		if(err)
			moved_to_relife = 0;
	}
	if(!moved_to_relife){
		if(me->relife)
			me->relife = "";
		//没有复活点，从默认阵营复活地复活
		if(me->query_raceId()=="human")
			me->last_pos="/gamelib/d/congxianzhen/congxianzhenguangchang";
		if(me->query_raceId()=="monst")
			me->last_pos="/gamelib/d/jinaodao/yuhuacunguangchang";
		if(me->query_raceId()=="third"){
			// 方士随机在人类或妖魔区复活
			if(random(2)==0)
				me->last_pos="/gamelib/d/congxianzhen/congxianzhenguangchang";
			else
				me->last_pos="/gamelib/d/jinaodao/yuhuacunguangchang";
		}
		if(me->last_pos){
			mixed err=catch{
				(object)(ROOT+me->last_pos);
			};
			if(!err)
				me->move(ROOT+me->last_pos);
		}
	}
}
string query_links(void|int count)
{
	string out="";
	if(this_object()->home_path&&this_object()->home_path!="")
	{
		out += "家园：["+HOMED->query_homeName_by_masterId(this_object()->query_name())+":home_display "+this_object()->query_home_path()+"]\n";
	}
	object tp=this_player();
	if(tp&&this_object()->can_socialize_with(tp)){
		int neutral_cross_race =
			this_object()->query_raceId()!=tp->query_raceId();
		//增加了帮战杀戮的显示，由liaocheng于08/08/30添加
		object env=environment(this_object());
		if(env && env->room_race == "third" && this_object()->bangid && this_player()->bangid && BANGZHAND->is_in_bangzhan(this_object()->bangid,this_player()->bangid))
			out += "[杀戮:kill "+this_object()->query_name()+" "+count+"]\n";
		// 方士与仙、妖玩家之间同时保留中立PK入口和社交入口。
		else if(neutral_cross_race)
			out += "[杀戮:kill "+this_object()->query_name()+" "+count+"]\n";
		//添加跟随链接，由liaocheng于07/09/21添加
		else if(this_player()->follow == "_none" && this_player()->query_term()==this_object()->query_term() && this_player()->query_term() != "noterm")
			out += "[跟随:follow_you "+this_object()->query_name()+" "+count+"]\n";
		out += "[观察:view_equip "+this_object()->query_name()+"] ";
		out += "[关注:spy_add "+this_object()->query_name()+"]\n";
		out += "[对话:ask "+this_object()->query_name()+" "+count+"] ";
		out += "[决斗:fight "+this_object()->query_name()+" "+count+" 0]\n";
		out += "[交易:trade "+this_object()->query_name()+"] ";
		out += "[赠送:sendother "+this_object()->query_name()+"]\n";
		out += "[加为好友:qqlist "+this_object()->query_name()+"]\n";
		if(this_object()->query_term()==""||this_object()->query_term()=="noterm")
			out += "[组队邀请:term_assist "+this_object()->query_name()+"]\n";
	}
	else{
		out += "[观察:view_equip "+this_object()->query_name()+"] ";
		out += "[杀戮:kill "+this_object()->query_name()+" "+count+"]\n";
		out += "[关注:spy_add "+this_object()->query_name()+"]\n";
	}
	out = out + ::query_links(count);                                                                                        
	return out;
}
string query_bangstatus(){
	string rst = "";
	if(this_object()->bangid){
		rst += BANGD->query_bang_name(this_object()->bangid);
	}
	if(rst&&sizeof(rst))
		rst = "帮派：<"+rst+">*"+BANGD->query_level_cn(this_object()->query_name(),this_object()->bangid);
	return rst;                                                                   
}
string query_bc_msg()
{
	object me = this_object();
	object env=environment(me);
	if(env&&env->is("menu")){
		return "";
	}
	string tmp = "";
	string bc_msg = BROADCASTD->bcShow(query_name());
	if(bc_msg&&sizeof(bc_msg))
		tmp += bc_msg; 
	return tmp;
}
string query_chat_msg()
{
	object me = this_object();
	object env=environment(me);
	if(env&&env->is("menu")){
		return "";
	}
	string tmp = "";
	if(me->roomchatid=="pub" || me->roomchatid=="open"){
		//if(me->query_level() >=6)//为了屏蔽枪手而做的修改
			tmp +="[ui_chat ...]\n";
		tmp += RACECHATD->query_chatroom_msg(
			me->query_raceId(),"pub_channel",me->query_name());
		tmp += "公|";
		//tmp += "[交:ui_select_room sale]|";
		tmp += "[队:ui_select_room term]|";
		tmp += "[帮:ui_select_room bang]|";
		tmp += "[关:ui_select_room close]";
		tmp += "[更多:chatroom_entry pub_channel]\n";
	}
	/*else if(me->roomchatid=="sale"){
		if(me->query_level() >=6)
			tmp +="[ui_chat ...]\n";
		if(me->query_raceId()=="human")
			tmp += CHATROOMD->query_chatroom_msg("sales_channel",me->query_name());
		else if(me->query_raceId()=="monst")
			tmp += CHATROOM2D->query_chatroom_msg("sales_channel",me->query_name());
		tmp += "[公:ui_select_room pub]|";
		tmp += "交|";
		tmp += "[队:ui_select_room term]|";
		tmp += "[帮:ui_select_room bang]|";
		tmp += "[关:ui_select_room close]\n";
	}*/
	else if(me->roomchatid=="term"){
		if(me->query_term()=="" || me->query_term()=="noterm"){
			tmp += "你没有在任何队伍里\n";
			tmp += "[公:ui_select_room pub]|";
			//tmp += "[交:ui_select_room sale]|";
			tmp += "队|";
			tmp += "[帮:ui_select_room bang]|";
			tmp += "[关:ui_select_room close]\n";
		}
		else{
			tmp += "[ui_chat ...]\n";
			tmp += TERMD->query_termChat_ui(
				me->query_term(),me->query_name());
			tmp += "[公:ui_select_room pub]|";
			//tmp += "[交:ui_select_room sale]|";
			tmp += "队|";
			tmp += "[帮:ui_select_room bang]|";
			tmp += "[关:ui_select_room close]\n";
		}
	}
	else if(me->roomchatid=="bang"){
		if(me->bangid == 0){
			tmp += "你还未加入任何帮派\n";
			tmp += "[公:ui_select_room pub]|";
			//tmp += "[交:ui_select_room sale]|";
			tmp += "[队:ui_select_room term]|";
			tmp += "帮|";
			tmp += "[关:ui_select_room close]\n";
		}
		else if(!BANGD->bang_allows_user(me->bangid,me->query_name())){
			tmp += "该帮派当前属于其他逻辑区，隔离期间不可见。\n";
			tmp += "[公:ui_select_room pub]|[队:ui_select_room term]|帮|";
			tmp += "[关:ui_select_room close]\n";
		}
		else if(BANGD->query_level(me->query_name(),me->bangid) > 1){
			tmp += "[ui_chat ...]\n";
			tmp += BANGD->query_ui_bangChat(me->bangid); 
			tmp += "[公:ui_select_room pub]|";
			//tmp += "[交:ui_select_room sale]|";
			tmp += "[队:ui_select_room term]|";
			tmp += "帮|";
			tmp += "[关:ui_select_room close]\n";
		}
		else if(BANGD->query_level(me->query_name(),me->bangid) == 1){
			tmp += "你已被帮主或者官员禁言了\n";
			tmp += BANGD->query_ui_bangChat(me->bangid); 
			tmp += "[公:ui_select_room pub]|";
			//tmp += "[交:ui_select_room sale]|";
			tmp += "[队:ui_select_room term]|";
			tmp += "帮|";
			tmp += "[关:ui_select_room close]\n";
		}
	}
	else if(me->roomchatid=="close"){
		//tmp += me->query_mini_picture_url("open_chat")+"[打开聊天:ui_select_room open]\n";
		tmp +="[打开聊天:ui_select_room open]\n";
	}
	return tmp;
}
string query_tips_msg()
{
	object me = this_object();
	object env=environment(me);
	if(env&&env->is("menu")){
		return "";
	}
	string tmp = "";
	string sys_msg = TIPSD->query_server_tips();
	string yun_msg = "[游戏更新信息:check_yun_msg]\n"; 
	if(sys_msg&&sizeof(sys_msg))
		tmp += sys_msg; 
	if(TIPSD->query_yunying_status())
		tmp += yun_msg; 
	return tmp;
}
int remove_combine_item(string name,int count)
{
	if(!count){
		return 0;
	}
	object me = this_object();
	int i = 0;
	int temp_num = count;
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob1){
		if(ob1->is_combine_item()&&ob1->query_name() == name){
			//该复数物品一组20个不够交付任务，接着轮询下一组
			if(ob1->amount<=temp_num){
				i+=ob1->amount;
				temp_num -= ob1->amount;
				ob1->remove();
			}
			else{
				i+=temp_num;
				ob1->amount -= temp_num;
			}
			if(i >= count)
				break;
		}
	}
	return i;
}

// 复数物品事务扣除：记录每个堆叠的精确变化，后续发奖或存档失败时
// 可以恢复原堆叠，而不是用等价物补偿造成面额或物品形态漂移。
mapping(string:mixed) remove_combine_item_transaction(string name,int count)
{
	mapping(string:mixed) state=(["ok":0,"removed":0,"changes":({})]);
	array(mapping(string:mixed)) changes=({});
	int remaining=count;
	if(!name || name=="" || count<=0)
		return state;
	foreach(all_inventory(this_object()),object item){
		int available;
		int take;
		mapping(string:mixed) change;
		if(remaining<=0)
			break;
		if(!item || !item->is_combine_item() || item->query_name()!=name)
			continue;
		available=(int)item->amount;
		if(available<=0)
			continue;
		take=available;
		if(take>remaining)
			take=remaining;
		change=(["object":item,"path":(file_name(item)/"#")[0],
			"amount":take,"max_count":(int)item->max_count,
			"removed":0]);
		if(take>=available){
			change["removed"]=1;
			item->remove();
		}
		else
			item->amount=available-take;
		changes+=({change});
		remaining-=take;
	}
	state["changes"]=changes;
	state["removed"]=count-remaining;
	if(remaining>0){
		rollback_combine_item_transaction(state);
		return (["ok":0,"removed":0,"changes":({})]);
	}
	state["ok"]=1;
	return state;
}

int rollback_combine_item_transaction(mapping(string:mixed) state)
{
	int restored_ok=1;
	array changes;
	if(!mappingp(state) || !arrayp(state["changes"]))
		return 0;
	changes=state["changes"];
	foreach(changes,mapping change){
		object item=change["object"];
		if((int)change["removed"]){
			mixed err=catch{ item=clone((string)change["path"]); };
			if(err || !item){
				restored_ok=0;
				continue;
			}
			item->amount=(int)change["amount"];
			item->max_count=(int)change["max_count"];
			if(item->move(this_object())!=1 ||
			   environment(item)!=this_object()){
				destruct(item);
				restored_ok=0;
			}
		}
		else if(item)
			item->amount=(int)item->amount+(int)change["amount"];
		else
			restored_ok=0;
	}
	if(!restored_ok)
		werror("[USER] combine item rollback incomplete player=%s\n",
			query_name());
	return restored_ok;
}
string query_danyao_effect()
{
	object me = this_object();
	string s_rtn = "";
	int flag = 0;
	mapping(string:string) have_yao = me["/danyao"];
	if(have_yao && sizeof(have_yao)){
		foreach(sort(indices(have_yao)),string kind){
			flag += 1;
			string yao_name = have_yao[kind];
			if(yao_name && sizeof(yao_name) > 0){
				int time_remain = me->query_buff(kind,2);
				if(flag != 1)
					s_rtn += "|";
				s_rtn += yao_name+"("+time_remain+"m)";
			}
		}
	}
	if(s_rtn == "")
		s_rtn += "无";
	return s_rtn;
}
string query_teyao_effect()
{
	object me = this_object();
	string s_rtn = "";
	int flag = 0;
	mapping(string:array) have_yao = me["/teyao"];
	if(have_yao && sizeof(have_yao)){
		foreach(sort(indices(have_yao)),string kind){
			array yao_data = have_yao[kind];
			if(yao_data && sizeof(yao_data) >= 4){
				flag += 1;
				string yao_name = yao_data[3];
				if(yao_name && sizeof(yao_name) > 0){
					int time_remain = me->query_buff(kind,2);
					if(flag != 1)
						s_rtn += "|";
					s_rtn += yao_name+"("+time_remain+"m)";
				}
			}
		}
	}
	if(s_rtn == "")
		s_rtn += "无";
	return s_rtn;
}

string query_homeBuff_effect()
{
	object me = this_object();
	string s_rtn = "";
	int flag = 0;
	mapping(string:array) have_buff = me["/homeBuff"];
	if(have_buff && sizeof(have_buff)){
		foreach(sort(indices(have_buff)),string kind){
			array buff_data = have_buff[kind];
			if(buff_data && sizeof(buff_data) >= 4){
				flag += 1;
				string buff_name = buff_data[3];
				if(buff_name && sizeof(buff_name) > 0){
					int time_remain = me->query_buff(kind,2);
					if(flag != 1)
						s_rtn += "|";
					s_rtn += buff_name+"("+time_remain+"m)";
				}
			}
		}
	}
	if(s_rtn == "")
		s_rtn += "无";
	return s_rtn;
}

//增加基本属性 caijie 080910
void set_base_add(string base,int value)
{
	if(base=="think"){
		base_think += value;
	}
	else if(base=="str"){
		base_str += value;
	}
	else if(base=="dex"){
		base_dex += value;
	}
	else if(base=="luck"){
		_lunck += value;
	}
}

//判断在线玩家是否在一个home中
int if_in_home()
{
	object env = environment(this_player());//当前所在房间
	if(env->query_room_type()&&env->query_room_type() == "home")
		return 1;
	return 0;
}

//查询玩家的装备中镶嵌玉石的数量
//equip==0--统计全部（包括穿戴的和不穿戴的）装备所镶嵌的宝石;equip==1---统计穿戴的装备所镶嵌的宝石
int query_baoshi_xiangqian_num(void|string baoshi_name,int equip){
	object me = this_player();
	array(object) all_items = all_inventory(me); 
	int baoshi_num = 0;
	array tmp = ({});
	if(!equip){
		foreach(all_items,object eachitem){
			if(eachitem->query_if_aocao("all")&&eachitem->query_baoshi("all")){
				tmp += eachitem->query_baoshi("all");
			}
		}
	}
	else if(equip==1){
		foreach(all_items,object eachitem){
			if(eachitem["equiped"]&&eachitem->query_if_aocao("all")&&eachitem->query_baoshi("all")){
				tmp += eachitem->query_baoshi("all");
			}
		}
	}
	if(!baoshi_name){
		//全部宝石的数量
		baoshi_num = sizeof(tmp);
	}
	else{
		foreach(tmp,object eachbaoshi){
			werror("==============baoshi file name "+eachbaoshi->query_name()+"\n");
			werror("==============baoshi_name "+baoshi_name+"\n");
			if(eachbaoshi->query_name()==baoshi_name || search(eachbaoshi->query_name(),"_") != -1 && (eachbaoshi->query_name()/"_")[0] == baoshi_name){
				baoshi_num ++;
			}
		}
	}
	return baoshi_num;
}
//返回玩家身上所有玉石的中文描述
string query_yushi_cn()
{
	string re = "";
	re += YUSHID->query_yushi_cn(this_player());
	return re;
}
//记录了玩家捐赠的总数量
int query_all_fee(){
	return all_fee;
}
void set_all_fee(int s)
{
	all_fee = s;
}
