#include <globals.h>
inherit LOW_BASE;
inherit LOW_F_CMDS;

int online_time;
int first_login;
int login_time;
private int update_time;
private int reconnect_time;
private int reconnect_count;
private int last_activity_time;

/****   添加的代码     ****/      
//通过链接的频率来滤出外挂的玩家，由liaocheng于2008-10-24添加
private int reconnect_delay;//这次连接与上次连接的时间差
private int illegal_count;//若这次时间差与上次时间差一样，则视为一次非法记录，非法记录超过某一值了则视为外挂
private int bad_rcd;//非法记录的次数，超过一个值了则视为外挂，送小黑屋     //新增

void check_reconnect_delay()
{
	if(reconnect_time){
		string now=ctime(time());
		string s_mon,s_day;
		int day,mon,year;
		mapping now_time = localtime(time());
		string s_log = "";
		string time_tail = "";
		int this_delay = time()-reconnect_time;
		if(this_delay == reconnect_delay && reconnect_delay <= 2)
			illegal_count++;
		else
			illegal_count = 0;
		if(illegal_count >= 20){
		//if(illegal_count >= 2){//测试用
			//外挂的处理在这里添加
			//目前是记录非法用户，不做其他任何操作
			//踢入到输入验证码的房间
			//this_object()->command("qge74hye check_room");    //需要输入验证的房间
			bad_rcd++;
			s_log = ""+now[0..sizeof(now)-2]+"|user:"+this_object()->query_name()+"|time_delay:"+reconnect_delay+"s|bad_rcd:"+bad_rcd+"\n"; 
			day = now_time["mday"];	
			mon = now_time["mon"]+1;
			year = now_time["year"]+1900;
			if(mon<10)
				s_mon = "0"+mon;
			else
				s_mon = (string)mon;
			if(day<10)
				s_day = "0"+day;
			else
				s_day = (string)day;
			time_tail = ""+year+"-"+s_mon+"-"+s_day;
			Stdio.append_file(ROOT+"/log/waigua/waigua_check_"+time_tail+".log",s_log); //写入log文件

			illegal_count = 0;
		}
		    if(bad_rcd >0 &&bad_rcd%10== 0){
		    //if(bad_rcd >0 &&bad_rcd%2== 0){//测试用
			//非法记录超过规定次数，送小黑屋
			this_object()->command("qge74hye check_room");    //需要输入验证的房间
			//this_object()->command("qge74hye xinshou/xiaoheiwu");   //小黑屋
			//Stdio.append_file(ROOT+"/txonline/etc/reserved_mobile",this_object()->query_name()+"\n");
			//由于玩家对象正在被访问，所以不能让玩家对象当即存档下线，这里设置一个定时器，让系统踢下线
			//call_out(waigua_remove,2);
			s_log = ""+now[0..sizeof(now)-2]+"|user:"+this_object()->query_name()+"|time_delay:"+reconnect_delay+"s|bad_rcd:"+bad_rcd+"|caught\n"; 
			bad_rcd++;
			day = now_time["mday"];	
			mon = now_time["mon"]+1;
			year = now_time["year"]+1900;
			if(mon<10)
				s_mon = "0"+mon;
			else
				s_mon = (string)mon;
			if(day<10)
				s_day = "0"+day;
			else
				s_day = (string)day;
			time_tail = ""+year+"-"+s_mon+"-"+s_day;
			Stdio.append_file(ROOT+"/log/waigua/waigua_in_heiwu_"+time_tail+".log",s_log); //写入log文件

		}

		reconnect_delay = this_delay;
	}
	return;
}
int update_online_time(){
	online_time+=time()-update_time;
	update_time=time();
	return online_time;
}
int query_idle(){
	int idle_from = last_activity_time;
	if(idle_from<=0)
		idle_from = reconnect_time;
	if(idle_from<=0)
		idle_from = time();
	return time()-idle_from;
}
void mark_user_activity(){
	last_activity_time = time();
}
string query_idle_label(){
	int idle_minutes;
	int vip_level = 0;
	int vip_active = 0;
	if(functionp(this_object()->query_autofight) &&
	   this_object()->query_autofight()=="enable")
		return "<挂机中>";
	idle_minutes = query_idle()/60;
	if(idle_minutes<=3)
		return "";
	if(functionp(this_object()->query_vip_flag))
		vip_level = (int)this_object()->query_vip_flag();
	if(vip_level>0 && functionp(this_object()->query_vip_end_time) &&
	   (int)this_object()->query_vip_end_time()>time())
		vip_active = 1;
	if(vip_active)
		return "<VIP发呆"+idle_minutes+"/120分钟>";
	return "<发呆"+idle_minutes+"/60分钟>";
}
int query_online(){
	return time()-update_time;
}
int query_reconnect_count(){
	return reconnect_count;
}
#ifdef __INTERACTIVE_CATCH_TELL__
void catch_tell(string str) {
    receive(str);
}
#endif
string query_cwd(){
	return "";
}
void write_prompt() {}
array(string) query_command_prefix(){
	return ({COMMAND_PREFIX, SROOT+"/wapmud2/cmds/", ROOT+"/gamelib/cmds/"});
}
string process_input(string arg){
	mark_user_activity();
    if(arg=="flush_filter"){
	    flush_filter();
	    return 0;
    }
    return arg;
}
void init(){
	if (this_object() == this_player()) {
		add_action("command_hook", "", 1);
	}
}
protected void create()
{
}
void receive_message(string newclass, string msg){
	receive(msg);
}
int setup(string arg){
	object account_characterd;
	object seasonal_chard;
	object account_storaged;
	object account_walletd;
	object yushid;
	object homed;
	object petd;
	object account_runtime_key;
	object http_api_daemon;
	int http_login_pending = 0;
	int map_worker_arrival = 0;
	int account_login_ready = 1;
	if(functionp(this_object()->query_account_owner)){
		account_characterd = (object)(ROOT+
			"/gamelib/single/daemons/account_characterd.pike");
		http_api_daemon = find_object(ROOT+
			"/gamelib/single/daemons/http_api_daemon.pike");
		if(http_api_daemon && functionp(
		   http_api_daemon->query_http_api_login_pending))
			http_login_pending = http_api_daemon->
				query_http_api_login_pending(name);
		// HTTP首次命令已经持有账号运行锁；Socket/JSP入口在这里补锁。
		if(account_characterd && !http_login_pending &&
		   functionp(account_characterd->query_account_runtime_mutex))
			account_runtime_key = account_characterd->
				query_account_runtime_mutex(name)->lock();
		if(functionp(this_object()->query_pending_worker_arrival))
			map_worker_arrival = this_object()->query_pending_worker_arrival();
		seasonal_chard = (object)(ROOT+
			"/gamelib/single/daemons/seasonal_chard.pike");
		// 赛季回归必须先于共享仓库/钱包恢复。跨Worker到达只是地图迁移，
		// 由目标节点的自动结算器处理，不能重复执行完整登录迁移。
		if(!map_worker_arrival && seasonal_chard && functionp(
		   seasonal_chard->reconcile_player_login))
			account_login_ready = seasonal_chard->
				reconcile_player_login(this_object(),1);
		account_storaged = (object)(ROOT+
			"/gamelib/single/daemons/account_storaged.pike");
		if(account_login_ready && account_storaged && functionp(
		   account_storaged->reconcile_player_login))
			account_login_ready = account_storaged->
				reconcile_player_login(this_object());
		account_walletd = (object)(ROOT+
			"/gamelib/single/daemons/account_walletd.pike");
		if(account_login_ready && account_walletd && functionp(
		   account_walletd->reconcile_player_login))
			account_login_ready = account_walletd->
				reconcile_player_login(this_object());
		yushid = (object)(ROOT+
			"/gamelib/single/daemons/yushid.pike");
		if(account_login_ready && yushid && functionp(
		   yushid->reconcile_wallet_payment))
			account_login_ready = yushid->
				reconcile_wallet_payment(this_object());
		homed = (object)(ROOT+"/gamelib/single/daemons/homed.pike");
		if(account_login_ready && homed && functionp(
		   homed->reconcile_function_room_transaction))
			account_login_ready = homed->
				reconcile_function_room_transaction(this_object());
		petd = (object)(ROOT+
			"/gamelib/single/daemons/petd.pike");
		if(account_login_ready && petd && functionp(
		   petd->reconcile_pet_player_login))
			petd->reconcile_pet_player_login(this_object());
		if(account_login_ready && account_characterd && functionp(
		   account_characterd->prepare_character_login_locked))
			account_login_ready = account_characterd->
				prepare_character_login_locked(this_object());
	}
	if(!account_login_ready){
		if(account_runtime_key)
			destruct(account_runtime_key);
		write("账号共享数据或待完成交易恢复失败，请稍后重试。\n");
		return 0;
	}
	first_login=login_time=update_time=reconnect_time=last_activity_time=time();
	// 同一注册账号的会员资格在登录时对账到本人物（账号最高档共享）。
	catch{
		((object)(ROOT "/gamelib/single/daemons/vipd.pike"))->
			reconcile_account_vip(this_object());
	};
    set_heart_beat(1);
    set_living_name(name);
    enable_commands();
    //add for password by calvin 2006-12-08
   // 只在密码不存在时才设置（避免覆盖已有密码）
    if(!password) {
        set_password(arg);
    }
	//add for password by calvin 2006-12-08
	set_this_player(this_object());

	// 踢掉 HTTP API 虚拟连接（如果有）
	http_api_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
	if(http_api_daemon && functionp(http_api_daemon->remove_virtual_connection)) {
		http_api_daemon->remove_virtual_connection(name);
	}
	if(account_runtime_key)
		destruct(account_runtime_key);

    return 1;
}
#ifndef __NO_ENVIRONMENT__
void tell_room(object ob, string msg){
    foreach (all_inventory(ob,this_object()) - ({ this_object() }),ob)
        tell_object(ob, msg);
}
#endif
void net_dead(){
	// 清理 HTTP API 虚拟连接（如果有）
	object http_api_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
	if(http_api_daemon && functionp(http_api_daemon->remove_virtual_connection)) {
		http_api_daemon->remove_virtual_connection(name);
	}
	call_out(remove,3);
}
int reconnect(string arg){
	if(arg&&arg==password){
		//check_reconnect_delay(); //在这里添加检查频率的方法
		reconnect_time=time();
		mark_user_activity();
		reconnect_count++;
		remove_call_out(remove);

		// 踢掉 HTTP API 虚拟连接（如果有）
		object http_api_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
		if(http_api_daemon && functionp(http_api_daemon->remove_virtual_connection)) {
			http_api_daemon->remove_virtual_connection(name);
		}

		return 1;
	}
	else
		return 0;
}
private string project;
void set_project(string arg){
	project=arg;
}
string query_project(){
	return project;
}

// 自动打怪状态只在当前在线对象中生效，重新登录后默认关闭。
string autofight = "disable";
void set_autofight(string arg)
{
	if(arg == "enable")
		autofight = "enable";
	else
		autofight = "disable";
}
string query_autofight()
{
	return autofight;
}
