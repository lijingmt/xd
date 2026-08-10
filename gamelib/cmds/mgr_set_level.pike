#include <command.h>
#include <gamelib/include/gamelib.h>

int valid_userid(string userid)
{
	if(!userid || sizeof(userid)<2)
		return 0;
	for(int i=0;i<sizeof(userid);i++){
		int c = userid[i];
		if(!((c>='a' && c<='z') ||
		   (c>='A' && c<='Z') ||
		   (c>='0' && c<='9')))
			return 0;
	}
	return 1;
}

void discard_offline_player(object player)
{
	if(!player)
		return;
	foreach(all_inventory(player),object item)
		item->remove();
	destruct(player);
}

mapping(string:mixed) change_user_level(object operator,
	string userid,int new_level)
{
	mapping(string:mixed) result = ([
		"ok":0,
		"message":"修改失败",
		"old_level":0,
		"new_level":new_level,
		"online":0,
	]);
	object player;
	int offline = 0;
	int old_level;
	int old_current_exp;
	int save_ok;

	if(!operator ||
	   MANAGERD->checkpower(operator->query_name())!="admin"){
		result["message"] = "需要管理员权限。";
		return result;
	}
	if(!valid_userid(userid)){
		result["message"] = "账号格式不正确。";
		return result;
	}
	if(new_level<1 || new_level>MAX_LEVEL){
		result["message"] = "等级必须在1至"+MAX_LEVEL+"之间。";
		return result;
	}

	player = find_player(userid);
	if(!player){
		player = operator->load_player(userid);
		offline = 1;
	}
	if(!player){
		result["message"] = "账号不存在。";
		return result;
	}

	old_level = player->query_level();
	old_current_exp = player->current_exp;
	result["old_level"] = old_level;
	result["online"] = offline ? 0 : 1;

	// 旧灵兽仍保留原等级战斗属性，改级时统一回收。
	SUMMOND->player_logout(userid);
	player->level = new_level;
	player->current_exp = 0;
	player->set_att_by_level();
	save_ok = player->save_with_result();
	if(!save_ok){
		player->level = old_level;
		player->current_exp = old_current_exp;
		player->set_att_by_level();
		player->save_with_result();
		result["message"] = "玩家档案写入失败，等级已回滚。";
	}
	else{
		string now = ctime(time());
		result["ok"] = 1;
		result["message"] = "等级修改成功并已立即存档。";
		Stdio.append_file(ROOT+"/log/manage_set_level.log",
			now[0..sizeof(now)-2]+
			" admin="+operator->query_name()+
			" target="+userid+
			" old="+old_level+
			" new="+new_level+
			" state="+(offline ? "offline" : "online")+"\n");
	}

	if(offline)
		discard_offline_player(player);
	return result;
}

int main(string|zero arg)
{
	object me = this_player();
	string userid = "";
	string action = "";
	int new_level = 0;
	string s = "====管理员修改玩家等级====\n";

	if(!me || MANAGERD->checkpower(me->query_name())!="admin"){
		write("需要管理员权限才可以执行此操作。\n[返回游戏:look]\n");
		return 1;
	}
	if(MAP_WORKERD->query_node_role()=="worker"){
		write("多Worker试运行期间已关闭直接改级，避免从错误进程复制并覆盖在线档案。\n"+
			"[返回管理主界面:game_deal]\n[返回游戏:look]\n");
		return 1;
	}
	if(!arg || arg==""){
		s += "请先从用户数据管理页选择账号。\n";
	}
	else if(sscanf(arg,"%s %d %s",userid,new_level,action)==3 &&
		action=="confirm"){
		mapping result = change_user_level(me,userid,new_level);
		s += result["message"]+"\n";
		if(result["ok"]){
			s += "账号："+userid+"\n";
			s += "等级："+result["old_level"]+" -> "+
				result["new_level"]+"\n";
			s += "状态："+(result["online"] ? "在线" : "离线")+"\n";
		}
	}
	else if(sscanf(arg,"%s %d",userid,new_level)==2){
		if(!valid_userid(userid) ||
		   new_level<1 || new_level>MAX_LEVEL)
			s += "账号或等级无效，等级范围为1至"+MAX_LEVEL+"。\n";
		else{
			object player = find_player(userid);
			int offline = 0;
			if(!player){
				player = me->load_player(userid);
				offline = 1;
			}
			if(!player)
				s += "账号不存在。\n";
			else{
				s += "账号："+userid+"\n";
				s += "请确认将等级从"+player->query_level()+
					"改为"+new_level+"。\n";
				s += "当前等级进度会归零，属性将按职业重算。\n";
				s += "[确认修改:mgr_set_level "+userid+" "+
					new_level+" confirm]\n";
				if(offline)
					discard_offline_player(player);
			}
		}
	}
	else if(sscanf(arg,"%s %s",userid,action)==2 &&
		action=="input"){
		if(valid_userid(userid))
			s += "请输入1至"+MAX_LEVEL+"的新等级：\n"+
				"[string:mgr_set_level "+userid+" ...]\n";
		else
			s += "账号格式不正确。\n";
	}
	else
		s += "参数错误。\n";

	if(userid!="")
		s += "[返回用户详情:mgr_usr_data "+userid+"]\n";
	s += "[返回管理主界面:game_deal]\n";
	s += "[返回游戏:look]\n";
	write(s);
	return 1;
}
