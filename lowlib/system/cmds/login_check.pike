#include <globals.h>
#include <gamelib/include/gamelib.h>
// 检查 HTTP API 登录标记（来自 http_api_daemon）
int is_http_api_login(string user_name) {
    object http_api_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
    if(http_api_daemon && functionp(http_api_daemon->query_http_api_login_pending)) {
        int pending = http_api_daemon->query_http_api_login_pending(user_name);
        return pending;
    }
    return 0;
}

// 同一人物从HTTP界面切换到Socket界面时必须先在账号锁内可靠保存，
// 不能直接destruct在线对象，否则最近装备/仓库状态可能被旧.o覆盖。
private int safely_remove_http_player(object player,string user_name,
	object http_api_daemon)
{
	object account_key;
	object connd;
	int saved = 0;
	mixed err;
	if(!player)
		return 1;
	account_key = ACCOUNT_CHARACTERD->
		query_account_runtime_mutex(user_name)->lock();
	err = catch{
		if(functionp(player->save_with_result))
			saved = player->save_with_result();
	};
	if(err || !saved){
		destruct(account_key);
		return 0;
	}
	if(http_api_daemon && functionp(
	   http_api_daemon->remove_virtual_connection))
		http_api_daemon->remove_virtual_connection(user_name);
	connd = find_object(SROOT+"/connd.pike");
	if(connd && functionp(connd->erase_user))
		connd->erase_user(player);
	err = catch{
		player->remove();
	};
	destruct(account_key);
	return !err;
}

int main(string arg)
{
	string path,user_name,lgpswd,userip,forwarded_ip;
	string title = "";
	title += "=玩家登录=\n";
	int parsed = arg ? sscanf(arg,"%s %s %s %s %s",path,user_name,
		lgpswd,userip,forwarded_ip) : 0;
	if(parsed!=5 && arg){
		forwarded_ip = "";
		parsed = sscanf(arg,"%s %s %s %s",path,user_name,lgpswd,userip);
	}
	if(parsed==4 || parsed==5){
		if(!path || !user_name || !lgpswd || !userip){
			title += "登录错误！\n";
			title += "您输入的用户名和密码不符合规范，请返回重试。\n";
			title += "[url 返回:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(lgpswd)<2 ){
			title += "登录错误！\n";
			title += "您输入的用户名和密码不符合规范，请返回重试。\n";
			title += "[url 返回:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		if(path!="gamelib"){
			title += "登录错误！\n";
			write(title);
			return 1;
		}
		if(!is_http_api_login(user_name) &&
		   !authentication_rate_limit_allowed(forwarded_ip)){
			title += "登录尝试过于频繁，请稍后重试。\n";
			write(title);
			return 1;
		}
		for(int i=0;i<sizeof(user_name);i++){
			if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
				;
			else{
				title += "登录错误！\n";
				title += "您输入的用户名和密码含有特殊字符，请返回重试。\n";
				title += "[url 返回:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
		}
		object logical_zoned = LOGICALZONED;
		if(logical_zoned && functionp(logical_zoned->login_allowed) &&
		   !logical_zoned->login_allowed(user_name)){
			title += "登录错误！\n";
			title += "该逻辑区尚未开放或正在维护，请稍后再试。\n";
			title += "[url 返回:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
		if(!user){
			object me = find_player(user_name);
			//内存里有，也是正常登陆，可以登入游戏
			if(me){
				//两个验证，sessionid和password
				if(userip&&userip==me->userip&&me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
					// 检查并清除虚拟连接（解决新老界面切换白屏问题）
					object http_api_d = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
					if(http_api_d && functionp(http_api_d->has_virtual_connection)
					   && http_api_d->has_virtual_connection(user_name)) {
						// 用户有虚拟连接（从新界面登录过），现在从老界面登录
						// 需要清除虚拟连接并重新创建玩家对象
						if(!safely_remove_http_player(me,user_name,http_api_d)){
							title += "登录切换保存失败，请稍后重试。\n";
							write(title);
							return 1;
						}
						// 重新创建玩家对象（首次登录流程）
						program u;
						object m;
						catch{
							m=(object)(ROOT+"/"+path+"/master.pike");
						};
						if(m){
							u=m->connect();
						}
						if(!u){
							u=(program)(ROOT+"/"+path+"/clone/user.pike");
						}
						me=u();
						me->set_name(user_name);
						me->set_userip(userip);
						me->set_project(path);
						if(me->setup(lgpswd)) {
							me->is_http_api_user = 0;
							exec(me,previous_object());
							if(environment(me)==0){
								me->move(LOW_VOID_OB);
							}
							destruct(previous_object());
						}
					}
					else if(is_http_api_login(user_name)) {
						// HTTP API 模式检测：检查全局标记
						// 标记玩家为 HTTP API 用户（用于经验加成等）
						me->is_http_api_user = 1;
						// HTTP API 模式：不调用 exec()，更新虚拟连接池
						if(http_api_d && functionp(http_api_d->set_virtual_connection)) {
							http_api_d->set_virtual_connection(user_name, ({0, time(), me}));
						}
					} else {
						// Socket 模式：重置 HTTP API 标记，正常调用 exec()
						me->is_http_api_user = 0;
						exec(me,previous_object());
						destruct(previous_object());
					}
				}
				else{
					title += "登录错误！\n";
					title += "您输入的用户名不存在或密码错误，请返回重新输入，或进入新账号注册页面进行注册。\n";
					title += "[url 返回:http://"+INDEX_URL+"]\n";
					write(title);
					return 1;
				}
			}
			else{
				//内存里也没有这个帐号,不允许登陆
				title += "登录错误！\n";
				title += "您输入的用户名不存在，是否要注册这个帐户?\n";
				title += "[url 返回:http://"+REG_URL+"]\n";
				write(title);
				return 1;
			}
		}
		else{
			object me = find_player(user_name);
			//有这个用户，用户在线，进行验证
			if(me){
				if(me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
					// 检查并清除虚拟连接（解决新老界面切换白屏问题）
					object http_api_d = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
					if(http_api_d && functionp(http_api_d->has_virtual_connection)
					   && http_api_d->has_virtual_connection(user_name)) {
						// 用户有虚拟连接（从新界面登录过），现在从老界面登录
						// 需要清除虚拟连接并重新创建玩家对象
						if(!safely_remove_http_player(me,user_name,http_api_d)){
							title += "登录切换保存失败，请稍后重试。\n";
							write(title);
							return 1;
						}
						// 重新创建玩家对象（首次登录流程）
						program u;
						object m;
						catch{
							m=(object)(ROOT+"/"+path+"/master.pike");
						};
						if(m){
							u=m->connect();
						}
						if(!u){
							u=(program)(ROOT+"/"+path+"/clone/user.pike");
						}
						me=u();
						me->set_name(user_name);
						me->set_userip(userip);
						me->set_project(path);
						if(me->setup(lgpswd)) {
							me->is_http_api_user = 0;
							exec(me,previous_object());
							if(environment(me)==0){
								me->move(LOW_VOID_OB);
							}
							destruct(previous_object());
						}
					}
					else if(is_http_api_login(user_name)) {
						// HTTP API 模式检测：检查全局标记
						// 标记玩家为 HTTP API 用户（用于经验加成等）
						me->is_http_api_user = 1;
						// HTTP API 模式：不调用 exec()，更新虚拟连接池
						if(http_api_d && functionp(http_api_d->set_virtual_connection)) {
							http_api_d->set_virtual_connection(user_name, ({0, time(), me}));
						}
					} else {
						// Socket 模式：重置 HTTP API 标记，正常调用 exec()
						me->is_http_api_user = 0;
						exec(me,previous_object());
						destruct(previous_object());
					}
				}
				else{
					title += "登录错误！\n";
					title += "您输入的用户名和密码认证失败\n";
					title += "[url 返回:http://"+INDEX_URL+"]\n";
					write(title);
					return 1;
				}
			}
			else{
				//有这个用户，但是用户不在线，这里需要找到该用户档案中的密码字段并对比lgpswd
				string pswd;
				array(string) usr_content=user/"\n";
				foreach(usr_content,string strCompare){
					if((strCompare/" ")[0]=="password"){
						if( (strCompare/" ")[1] ){
							string pswdTmp = (strCompare/" ")[1];
							pswd =(pswdTmp/"\"")[1];
						}
					}
				}
				if(!pswd){
					title += "登录错误！\n";
					//title += "您输入的用户名和密码认证失败，是否需要找回密码？\n";
					title += "您输入的用户名和密码认证失败\n";
					title += "[url 返回:http://"+INDEX_URL+"]\n";
					write(title);
					return 1;
				}
				if(pswd && lgpswd!=pswd){
					title += "登录错误！\n";
					//title += "您输入的用户名和密码认证失败，是否需要找回密码？\n";
					title += "您输入的用户名和密码认证失败\n";
					title += "[url 返回:http://"+INDEX_URL+"]\n";
					write(title);
					return 1;
				}
				if(pswd && lgpswd==pswd){
					program u;
					object m;
					catch{
						m=(object)(ROOT+"/"+path+"/master.pike");
					};
					if(m){
						u=m->connect();
					}
					if(!u){
						u=(program)(ROOT+"/"+path+"/clone/user.pike");
					}
					me=u();
					me->set_name(user_name);
					me->set_userip(userip);
					me->set_project(path);
					int setup_ok = 0;
					mixed setup_result = catch { setup_ok = me->setup(lgpswd); };
					if(setup_result==0 && setup_ok){
						// HTTP API 模式检测：检查全局标记
						int is_http_api = is_http_api_login(user_name);
						if(is_http_api) {
							// 标记玩家为 HTTP API 用户（用于经验加成等）
							me->is_http_api_user = 1;
							// HTTP API 模式：不调用 exec()，将玩家添加到虚拟连接池
							object http_api_daemon = find_object(ROOT + "/gamelib/single/daemons/http_api_daemon.pike");
							if(http_api_daemon && functionp(http_api_daemon->set_virtual_connection)) {
								http_api_daemon->set_virtual_connection(user_name, ({0, time(), me}));
							}
							if(environment(me)==0){
								me->move(LOW_VOID_OB);
							}
						} else {
							// Socket 模式：重置 HTTP API 标记，正常调用 exec()
							me->is_http_api_user = 0;
							exec(me,previous_object());
							if(environment(me)==0){
								me->move(LOW_VOID_OB);
							}
							destruct(previous_object());
						}
					}
					return 1;
				}
			}
		}
	}
	else{
		title += "登陆错误！\n";
		title += "[url 返回:http://"+INDEX_URL+"]\n";
	}
	write(title);
	return 1;
}
