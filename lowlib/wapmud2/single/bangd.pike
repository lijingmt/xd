#!/usr/local/bin/pike
//bangd.pike:帮派系统的守护程序。
//由liaocheng于07/04/23首次编写
#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#define BANG_LIST DATA_ROOT+"bangpai/bang_list"
#define BANG_MEMBERS DATA_ROOT+ "bangpai/bang_members"
#define BANG_SIZE DATA_ROOT+"bangpai/bang_size"
#define BANG_APPLY DATA_ROOT+"bangpai/bang_apply"
#define NAME_NAMECN	DATA_ROOT+"bangpai/name_namecn"
#define CHAT_NUM 10 //聊天室最多显示的聊天数
#define SAVE_TIME 1200 //10分钟存档一次
inherit LOW_DAEMON;

//系统启动时从/usr/local/games/usrdata5/bangpai/bang_list中读入数据，以建立帮派总表bang_list
//格式为:([bangid:({bangname,1级称谓,2级称谓,3级称谓,4级称谓,5级称谓,6级称谓,帮派通告,帮派简介})])
//                      [0]    [1]     [2]     [3]     [4]     [5]     [6]      [7]    [8] 
//缺省为:                   小黑屋     会员   精英    官员     副帮主  帮主    
private static mapping(int:array(string)) bang_list = ([]);

//帮派人员表，系统启动时从/usr/local/games/usrdata5/bangpai/bang_members中读入数据，以建立帮派人员表bang_members
//格式为：([bangid:([成员名称:成员等级,...]),])
private static mapping(int:mapping(string:int)) bang_members = ([]);
//从/usr/local/games/usrdata5/bangpai/name_namecn 中读入数据，以建立帮派人员id与人员名称的映射表
private static mapping(int:mapping(string:string)) name_namecn = ([]);

private static mapping(int:array(string)) bang_chat = ([]);

//记录申请加入帮派的信息
private static mapping(int:array(string)) bang_apply = ([]);

//记录已建立的帮派名称，以免重名
private static mapping(string:int) bang_exist = ([]);

//系统启动时从/usr/local/games/usrdata5/bangpai/bang_size中读入数据，
//格式为：monster_size
//        human_size
int monster_size; //记录最后一个妖魔帮派id,妖魔阵营的bangid=1，3，5，7.....
int human_size; //记录最后一个人类帮派的id,人类阵营的bangid=2，4，6，8.....

void create()
{
	if(!readFile_bangList()){
		werror("---------------readFile_bangList error!!--------------\n");
		exit(1);
	}
	if(!readFile_bangApply()){
		werror("---------------readFile_bangApply error!!--------------\n");
		exit(1);
	}
	if(!readFile_bangMembers()){
		werror("---------------readFile_bangMembers error!!--------------\n");
		exit(1);
	}
	if(!readFile_bangSize()){
		werror("---------------readFile_bangList error!!--------------\n");
		exit(1);
	}
	if(!readFile_name_namecn()){
		werror("---------------readFile_bangList error!!--------------\n");
		exit(1);
	}
	werror("\n----------------/gamelib/single/daemons/bangd.pike create call compeleted!!!----------------\n");
	call_out(save_bang,SAVE_TIME);
}

//存档
void save_bang(void|int fg)
{
	//先存档bang_list
	string now=ctime(time());
	string writeBack = "";
	foreach(indices(bang_list),int bangid){
		writeBack += bangid+"|";
		for(int i=0;i<9;i++){
			writeBack += bang_list[bangid][i]+",";
		}
		writeBack += "\n";
	}
	mixed err=catch
	{
		Stdio.write_file(BANG_LIST,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":rewrite bang_list failed\n");
	}

	//再存档bang_apply
	writeBack = "";
	foreach(sort(indices(bang_apply)),int bangid){
		if(bang_apply[bangid] && sizeof(bang_apply[bangid])){
			writeBack += bangid+"|";
			for(int i=0;i<sizeof(bang_apply[bangid]);i++){
				if(bang_apply[bangid][i] != "" || sizeof(bang_apply[bangid][i])>0)
					writeBack += bang_apply[bangid][i]+",";
			}
			writeBack += "\n";
		}
	}
	err=catch
	{
		Stdio.write_file(BANG_APPLY,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":rewrite bang_apply failed\n");
	}

	//再存档name_namecn
	writeBack = "";
	foreach(indices(name_namecn),int bangid){
		writeBack += bangid+"|";
		mapping(string:string) tmp = name_namecn[bangid];
		foreach(indices(tmp),string name){
			writeBack += name+":"+tmp[name]+",";
		}
		writeBack += "\n";
	}
	err=catch
	{
		Stdio.write_file(NAME_NAMECN,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":rewrite name_namecn failed\n");
	}

	//再存档bang_members
	writeBack = "";
	foreach(indices(bang_members),int bangid){
		writeBack += bangid+"|";
		mapping(string:int) tmp = bang_members[bangid];
		foreach(indices(tmp),string name){
			writeBack += name+":"+tmp[name]+",";
		}
		writeBack += "\n";
	}
	err=catch
	{
		Stdio.write_file(BANG_MEMBERS,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":rewrite bang_members failed\n");
	}

	//最后存档bang_size
	writeBack = "";
	writeBack += monster_size+"\n"+human_size;
	err=catch
	{
		Stdio.write_file(BANG_SIZE,writeBack);
	};
	if(err)
	{
		Stdio.append_file(ROOT+"/log/bang.log",now[0..sizeof(now)-2]+":rewrite bang_size failed\n");
	}
	if(!fg)
		call_out(save_bang,SAVE_TIME);
}

//从/usr/local/games/usrdata5/bangpai/bang_list中读入数据的接口
//写入到bang_list映射表中
int readFile_bangList()
{
	string Filedata = Stdio.read_file(BANG_LIST);
	if(Filedata){
		array(string) bangs = Filedata/"\n";
		foreach(bangs,string eachbang){
			if(eachbang && sizeof(eachbang)){
				array(string) tmp = eachbang/"|";
				array(string) content = tmp[1]/",";
				bang_exist[content[0]]=1;
				bang_list[(int)tmp[0]] = content[0..8];
				//初始化帮派聊天室
				bang_chat[(int)tmp[0]] = ({"欢迎来到帮派聊天室"});
			}
		}
		return 1;
	}
	else
		return 0;	
}

int readFile_bangApply()
{
	string Filedata = Stdio.read_file(BANG_APPLY);
	if(Filedata){
		array(string) bangs = Filedata/"\n";
		foreach(bangs,string eachbang){
			if(eachbang && sizeof(eachbang)){
				array(string) tmp = eachbang/"|";
				array(string) content = tmp[1]/","-({""});
				bang_apply[(int)tmp[0]] = content;
			}
		}
		return 1;
	}
	else
		return 0;	
}

//从/usr/local/games/usrdata5/bangpai/bang_members中读入数据
//写入到bang_members映射表中
int readFile_bangMembers()
{	
	string fileData = Stdio.read_file(BANG_MEMBERS);
	if(fileData){
		array(string) bangs = fileData/"\n";
		foreach(bangs,string eachbang){
			if(eachbang && sizeof(eachbang)){
				array(string) tmp = eachbang/"|";
				//tmp[0]为帮id，tmp[1]为帮成员
				array(string) members = (tmp[1]/",")-({""});
				foreach(members,string member){
					if(member && sizeof(member)){
						array(string) mem_tmp = member/":";
						string name = mem_tmp[0];
						int level = (int)mem_tmp[1];
						bang_members[(int)tmp[0]] += ([name:level]);
					}
				}
			}
		}
		return 1;
	}
	else 
		return 0;
}

//读入帮派个数文件bangsize
int readFile_bangSize()
{
	string fileData = Stdio.read_file(BANG_SIZE);
	if(fileData && sizeof(fileData)){
		array(string) tmp = fileData/"\n";
		monster_size = (int)tmp[0];
		human_size = (int)tmp[1];
		return 1;
	}
	else 
		return 0;
}

//读入帮员id与名称对应文件
int readFile_name_namecn()
{
	string fileData = Stdio.read_file(NAME_NAMECN);
	if(fileData){
		array(string) bangs = fileData/"\n";
		foreach(bangs,string eachbang){
			if(eachbang && sizeof(eachbang)){
				array(string) tmp = eachbang/"|";
				//tmp[0]为帮id，tmp[1]为帮成员
				array(string) members = (tmp[1]/",")-({""});
				foreach(members,string member){
					if(member && sizeof(member)){
						array(string) mem_tmp = member/":";
						string name = mem_tmp[0];
						string name_cn = mem_tmp[1];
						name_namecn[(int)tmp[0]] += ([name:name_cn]);
					}
				}
			}
		}
		return 1;
	}
	else 
		return 0;
}

//获得帮派名字的接口
string query_bang_name(int bangid)
{
	string s = "";
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		s = bang_info[0];
	}
	return s;
}

//获得帮派通告的接口
string query_bang_notice(int bangid)
{
	string s = "无";
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		if(bang_info[7] && sizeof(bang_info[7]))
			s = bang_info[7];
	}
	return s;
}

//设置帮派通告的接口
void set_bang_notice(int bangid,string content)
{
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		bang_info[7]=content;
	}
}

//获得帮派简介的接口
string query_bang_desc(int bangid)
{
	string s = "无";
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		if(bang_info[8] && sizeof(bang_info[8])){
			s = bang_info[8];
			if(sizeof(s)>80){
				s = s[0..79];
				bang_info[8]=s;
			}
		}
	}
	return s;
}

//设置帮派简介的接口
void set_bang_desc(int bangid,string content)
{
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		bang_info[8]=content;
	}
}

//获得帮派所有等级描述的接口，帮主可以看见修改链接
string query_bang_levels(int bangid,int level)
{
	string s = "";
	string tmp = "";
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		if(level != 6){
			for(int i=1;i<7;i++){
				tmp = bang_info[i];
				if(sizeof(tmp)>12){
					tmp = tmp[0..11];
					bang_info[i]=tmp;
				}
				s += i+"级称谓:"+tmp;
				if(i%2 == 1)
					s += "|";
				else if(i != 6)
					s += "\n";
			}
		}
		else{
			for(int i=1;i<7;i++){
				tmp = bang_info[i];
				if(sizeof(tmp)>12){
					tmp = tmp[0..11];
					bang_info[i]=tmp;
				}
				s += "["+i+"级称谓:bang_change_level "+i+"]:"+tmp;
				if(i%2 == 1)
					s += "|";
				else
					s += "\n";
			}

		}
	}
	return s;
}

//获得帮派指定等级描述
string query_bang_level(int bangid,int level)
{
	string s = "";
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		s = bang_info[level];
		if(sizeof(s)>12)
			s = s[0..11];
	}
	return s;
}

//设置帮派指定的等级描述
void set_bang_level(int bangid,int level,string content)
{
	array(string) bang_info = bang_list[bangid];
	if(bang_info && sizeof(bang_info)==9){
		bang_info[level]=content;
	}
}

//获得在帮派里的等级称谓
string query_level_cn(string player,int bangid)
{
	string s = "";
	mapping(string:int) mem_lev = bang_members[bangid];
	if(mem_lev && sizeof(mem_lev)){
		int level = mem_lev[player];
		if(!level)
			s += "你并不在该帮派，请速与管理员联系哦~~\n";
		else{
			array(string) bang_info = bang_list[bangid];
			if(bang_info && sizeof(bang_info)==9){
				s = bang_info[level];
				if(sizeof(s)>12){
					s = s[0..11];
					bang_info[level]=s;
				}
			}
			else{ 
				s += "没有此帮派，可能已经解散\n";
				werror("------bang_info size = "+sizeof(bang_info)+"------\n");
			}
		}
	}
	return s;
}
//获得帮派内的等级
int query_level(string player,int bangid)
{
	int level = 0;
	mapping(string:int) mem_lev = bang_members[bangid];
	if(mem_lev && sizeof(mem_lev)){
		level = mem_lev[player];
		return level;
	}
}

//设置帮派成员的等级
int set_level(string player,int bangid,int level)
{
	mapping(string:int) mem_lev = bang_members[bangid];
	if(mem_lev && sizeof(mem_lev)){
		if(mem_lev[player]){
			mem_lev[player] = level;
			return 1;
		}		
	}
	return 0;
}

//获得帮派聊天的内容
//content的格式:"[player_name:bang_view_player]:chat_content"
string query_bang_chat(int bangid,string|void content)
{
	string s = "";
	//玩家是刷新聊天室则直接给出聊天记录
	if(!content || content == ""){
		array(string) tmp = bang_chat[bangid];
		if(tmp && sizeof(tmp)){
			for(int i=sizeof(tmp)-1;i>=0;i--){
				s += tmp[i]+"\n";
			}
		}
	}
	//玩家说话，则要更新聊天记录
	else{
		array(string) tmp = bang_chat[bangid];
		//聊天信息没有满，则直接在尾部加入
		if(sizeof(tmp)<CHAT_NUM){
			bang_chat[bangid] += ({content});
			tmp = bang_chat[bangid];
			for(int i=sizeof(tmp)-1;i>=0;i--){
				s += tmp[i]+"\n";
			}
		}
		else{
			for(int i=0;i<CHAT_NUM-1;i++)
				tmp[i]=tmp[i+1];
			tmp[CHAT_NUM-1] = content;
			bang_chat[bangid]=tmp;
			for(int j=CHAT_NUM-1;j>=0;j--)
				s += tmp[j]+"\n";
		}
	}
	return s;
}

//ui上调用的获得聊天记录的接口
string query_ui_bangChat(int bangid){
	string s_rtn = "";
	array(string) tmp = bang_chat[bangid];
	int nums = sizeof(tmp);
	if(nums>0 && nums<=3){
		for(int i=nums-1;i>=0;i--){
			s_rtn += tmp[i]+"\n";
		}
	}
	else if(nums>3){
		for(int i=nums-1;i>nums-4;i--){
			s_rtn += tmp[i]+"\n";
		}
	}
	return s_rtn;
}

//ui上调用的加入聊天内容的接口
int add_ui_chat(int bangid,string content){
	if(content && sizeof(content)){
		array(string) tmp = bang_chat[bangid];
		//聊天信息没有满，则直接在尾部加入
		if(sizeof(tmp)<CHAT_NUM){
			bang_chat[bangid] += ({content});
			tmp = bang_chat[bangid];
		}
		else{
			for(int i=0;i<CHAT_NUM-1;i++)
				tmp[i]=tmp[i+1];
			tmp[CHAT_NUM-1] = content;
			bang_chat[bangid]=tmp;
		}
	}
} 

//获得帮内人数
//第二个参数为"online",返回的是在线的人数；为"all"，返回的是总人数
int query_nums(int bangid,string flag)
{
	int online = 0;
	int all = 0;
	if(bang_list[bangid] && sizeof(bang_list[bangid])){
		mapping(string:int) members = bang_members[bangid];
		if(members && sizeof(members)){
			if(flag == "all"){
				all = sizeof(members);
				return all;
			}
			else if(flag == "online"){
				foreach(indices(members),string mem){
					if(sizeof(mem)){
						object ob = find_player(mem);
						if(ob)
							online++;
					}
				}
				return online; 
			}
		}
	}
	return 0;
}

//获得帮员列表，根据玩家在帮派里的等级来给与不同的权限
string query_bang_members(object viewer,int bangid,int level)
{
	string online = "";
	string offline = "";
	string s_rtn = "";
	if(name_namecn[bangid] == 0){
		string viewer_name = viewer->query_name();
		string viewer_name_cn = viewer->query_name_cn();
		name_namecn[bangid] = ([viewer_name:viewer_name_cn]);
	}
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		foreach(indices(members),string mem){
			object member = find_player(mem);
			if(member){
				//玩家在线
				string name = member->query_name();
				string name_cn = member->query_name_cn();
				if(!name_namecn[bangid][name])
					name_namecn[bangid][name]=name_cn;
				string idle="";
				if(member->query_idle()/60>3) 
					idle="<发呆"+member->query_idle()/60+"分钟>";
				string postions="";
				object env = environment(member);
				postions = (string)env->query_name_cn();
				string level_cn = query_level_cn(name,bangid);
				online += member->query_name_cn()+"("+member->query_level()+"级"+member->query_profe_cn(member->query_profeId())+")-"+level_cn+""+idle+"*"+postions+" [加为好友:qqlist "+name+"]|[发消息:tell "+name+"]";
				if(member->query_term()=="noterm" || member->query_term()=="")
					online += "|[组队邀请:term_assist "+name+"]";
				//等级〉4级，将有特殊权限
				if(level>3){
					online += "|[提升:bang_view_members "+name+" 1]|[降级:bang_view_members "+name+" 2]|[开除:bang_view_members "+name+" 3]";
				}
				online += "\n";
			}
			else{
				//玩家当前不在线，只有官员能看到离线用户
				if(level>3){
					mapping(string:string) tmp_m = name_namecn[bangid];
					if(tmp_m && sizeof(tmp_m)){
						if(tmp_m[mem] != 0){
							offline += tmp_m[mem]+"(离线)";
							//if(level>3){
							offline += "|[提升:bang_view_members "+mem+" 1]|[降级:bang_view_members "+mem+" 2]|[开除:bang_view_members "+mem+" 3]";
							//}
							offline += "\n";
						}
						else{
							member = viewer->load_player(mem);
							if(member){
								string name = member->query_name();
								offline += member->query_name_cn()+"(离线)";
								name_namecn[bangid][name] = member->query_name_cn();
								//if(level>3){
								offline += "|[提升:bang_view_members "+name+" 1]|[降级:bang_view_members "+name+" 2]|[开除:bang_view_members "+name+" 3]";
								//}
								offline += "\n";
								member->remove();
							}
						}
					}
				}
			}
		}
		s_rtn = online + offline;
	}
	return s_rtn;
}

//查询新的入帮申请信息
//格式 name_cn:name:level:profe
string query_bang_apply(int bangid)
{
	string s_rtn = "";
	array(string) tmp = ({});
	array(string) applys = bang_apply[bangid];
	if(applys && sizeof(applys)){
		for(int i=0;i<sizeof(applys);i++){
			tmp = applys[i]/":";
			if(tmp && sizeof(tmp) == 4){
				s_rtn += tmp[0]+"("+tmp[2]+"级"+tmp[3]+")申请加入帮派。[通过:bang_accept "+tmp[1]+" 1 "+(i+1)+"] [拒绝:bang_accept "+tmp[1]+" 0 "+(i+1)+"]\n";
			}
		}
	}
	return s_rtn;
}

//判断是否在申请列表中
int if_in_apply(object applyer,int index,int bangid)
{
	array(string) applys = bang_apply[bangid];
	if(applys && sizeof(applys)>=index+1){
		if(applys[index]){
			array(string)tmp = applys[index]/":";
			if(applyer->query_name()==tmp[1])
				return 1;
		}
	}
	return 0;
}
//删除已处理的入帮信息
void rmove_bang_apply(int bangid,int index)
{
	array(string) applys = bang_apply[bangid];
	if(applys && sizeof(applys)>=index+1){
		if(applys[index])
			bang_apply[bangid] -= ({applys[index]});
	}
}

//添加新的入帮信息
void add_bang_apply(int bangid,object applyer)
{
	array(string) applys = bang_apply[bangid];
	string content = applyer->query_name_cn()+":"+applyer->query_name()+":"+applyer->query_level()+":"+applyer->query_profe_cn(applyer->query_profeId());
	if(applys && sizeof(applys)){
		bang_apply[bangid] += ({content});	
	}
	else{
		bang_apply[bangid] = ({content});	
	}
}

//提升某个玩家的帮会等级
int update_level(object viewer,string target_name,int bangid)
{
	int target_level = query_level(target_name,bangid);
	int viewer_level = query_level(viewer->query_name(),bangid);
	if(target_level >= viewer_level-1)
		return 0;//已不能再提升对方等级
	else{
		mapping(string:int) members = bang_members[bangid];
		if(members && sizeof(members)){
			if(members[target_name]){
				members[target_name]++;
				return 1;//提升成功
			}
			else
				return 2;//没有这个成员
		}
		else 
			return 3;//帮派有些问题
	}
}

//降低某个玩家的帮会等级
int down_level(object viewer,string target_name,int bangid)
{
	int target_level = query_level(target_name,bangid);
	int viewer_level = query_level(viewer->query_name(),bangid);
	if(target_level >= viewer_level)
		return 0;//不能降低对方等级
	else{
		mapping(string:int) members = bang_members[bangid];
		if(members && sizeof(members)){
			if(members[target_name]){
				members[target_name]--;
				if(members[target_name]<1)
					members[target_name]=1;
				return 1;//降级成功
			}
			else
				return 2;//没有这个成员
		}
		else 
			return 3;//帮派有些问题
	}
}

//开除成员，和权限有关系
int fire_member(object viewer,string target_name,int bangid)
{
	int target_level = query_level(target_name,bangid);
	int viewer_level = query_level(viewer->query_name(),bangid);
	if(target_level >= viewer_level)
		return 0;//不能开除对方
	else{
		mapping(string:int) members = bang_members[bangid];
		if(members && sizeof(members)){
			if(members[target_name]){
				m_delete(members,target_name);
				return 1;
			}
			else{ 
				return 2;
			}
		}
		else
			return 3;
	}
}

//向帮会在线玩家发消息
void bang_notice(int bangid,string content)
{
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		foreach(indices(members),string member){
			object ob = find_player(member);
			if(ob)
				tell_object(ob,"<帮派消息>："+content);
			else
				continue;
		}
	}
}

//获得转让帮主权限的人物列表
string query_for_root(object root)
{
	string online = "";
	string offline = "";
	string s_rtn = "";
	int bangid = root->bangid;
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		foreach(indices(members),string mem){
			object member = find_player(mem);
			if(member){
				//玩家在线
				string name = member->query_name();
				int level = query_level(name,bangid);
				if(level <= 4)
					continue;
				string level_cn = query_level_cn(name,bangid);
				online += "["+member->query_name_cn()+"("+member->query_level()+"级"+member->query_profe_cn(member->query_profeId())+")-"+level_cn+":bang_be_root "+name+"]\n";
			}
			/*
			   else{
			//玩家当前不在线
			member = root->load_player(mem);
			if(member){
			string name = member->query_name();
			int level = query_level(name,bangid);
			string level_cn = query_level_cn(name,bangid);
			if(level<4){
			member->remove();
			continue;
			}
			offline += "["+member->query_name_cn()+"("+member->query_level()+"级"+member->query_profe_cn(member->query_profeId())+")-"+level_cn+":bang_be_root "+name+"](离线)\n";
			member->remove();
			}

			}
			 */
		}
		s_rtn = online + offline;
	}
	return s_rtn;
}

//设置帮主
int set_bang_root(object old,string new_name)
{
	int bangid = old->bangid;
	string old_name = old->query_name();
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		if(members[new_name]>3 && members[new_name]!=6){
			members[new_name] = 6; //新帮主
			members[old_name]--; //原帮主降一级
			return 1;
		}
		else if(members[new_name] == 6)
			return 3;
		else
			return 2;
	}
	else
		return 0;
}

//退出帮派
int quit_bang(string name,int bangid)
{
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		if(members[name]){
			int level = query_level(name,bangid);
			if(level != 6){
				m_delete(members,name);
				return 1;
			}
			else
				return 2;
		}
		else 
			return 3;
	}
	else 
		return 0;
}

//建立帮派
int create_bang(object creater,string bang_name)
{
	if(bang_exist[bang_name] == 1){
		return 0;	
	}
	else if(creater->bangid != 0)
		return 2;
	else{
		string creater_name = creater->query_name();
		string creater_name_cn = creater->query_name_cn();
		array(string) bang_info = ({bang_name,"小黑屋","会员","精英","官员","副帮主","帮主","","",});
		string profId = creater->query_raceId();
		int bangid;
		if(profId == "monst"){
			if(!monster_size)
				bangid = 1;
			else 
				bangid = monster_size+2;
			if(bang_list[bangid])
				return 0;
			bang_list[bangid]=bang_info;
			bang_members[bangid]=([creater_name:6]);
			bang_exist[bang_name]=1;
			bang_chat[bangid]=({"欢迎来到帮派聊天室"});
			monster_size = bangid;
			creater->bangid = bangid;
			name_namecn[bangid]=([creater_name:creater_name_cn]);
			werror("-----bangid = "+bangid+"-----\n");
			return 1;
		}
		else if(profId == "human"){
			if(!human_size)
				bangid = 2;
			else 
				bangid = human_size+2;
			if(bang_list[bangid])
				return 0;
			bang_list[bangid]=bang_info;
			bang_members[bangid]=([creater_name:6]);
			bang_exist[bang_name]=1;
			bang_chat[bangid]=({"欢迎来到帮派聊天室"});
			human_size = bangid;
			creater->bangid = bangid;
			name_namecn[bangid]=([creater_name:creater_name_cn]);
			werror("-----bangid = "+bangid+"-----\n");
			return 1;
		}
	}
}

//获得当前帮派列表
string query_bang_list(object player)
{
	string s = "";
	int flag = 0;
	string prof = player->query_raceId();
	if(prof == "monst"){
		foreach(indices(bang_list),int bangid){
			if(bangid == 0)
				continue;
			if(bangid%2 == 1){
				string bang_name = bang_list[bangid][0];
				if(flag%2 == 0)
					s += "[＜"+bang_name+"＞:bang_apply_in "+bangid+" 0] | ";
				else
					s += "[＜"+bang_name+"＞:bang_apply_in "+bangid+" 0]\n";
				flag += 1;
			}
			else
				continue;
		}
	}
	else if(prof == "human"){
		foreach(indices(bang_list),int bangid){
			if(bangid == 0)
				continue;
			if(bangid%2 == 0){
				string bang_name = bang_list[bangid][0];
				if(flag%2 == 0)
					s += "[＜"+bang_name+"＞:bang_apply_in "+bangid+" 0] | ";
				else
					s += "[＜"+bang_name+"＞:bang_apply_in "+bangid+" 0]\n";
				flag += 1;
			}
			else
				continue;
		}
	}
	return s;
}

//获得帮主的id
string query_root_name(int bangid)
{
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		foreach(indices(members),string name){
			if(members[name]==6)
				return name;
			else
				continue;
		}	
	}
	return "";
}

//返回帮主姓名
string query_root_name_cn(object player,int bangid)
{
	string s_rtn = "";
	string root_name = query_root_name(bangid);
	mapping(string:string) tmp = name_namecn[bangid];
	if(tmp&&sizeof(tmp)){
		s_rtn = tmp[root_name];
		if(sizeof(s_rtn) == 0){
			object root = find_player(root_name);
			if(root){
				s_rtn = root->query_name_cn();
				//name_namecn[bangid][root_name]=s_rtn;
			}
			else{
				root = player->load_player(root_name);
				s_rtn = root->query_name_cn();
				//name_namecn[bangid][root_name]=s_rtn;
				root->remove();
			}
		}
	}
	return s_rtn;
}

//加入新成员
int add_new_member(string name,int bangid)
{
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		members[name]=2;
		return 1;
	}
	else
		return 0;
}

//解散帮派
void dismiss_bang(object root)
{
	int bangid = root->bangid;
	string bang_name = query_bang_name(bangid);
	if(bang_list[bangid])
		m_delete(bang_list,bangid);
	mapping(string:int) members = bang_members[bangid];
	if(members && sizeof(members)){
		foreach(indices(members),string member ){
			int rmflag = 0;
			object ob = find_player(member);
			//优化了帮派解散，只解散在线玩家，不在线的将在登录时的init中自动解散
			//由liaocheng于08/09/04添加
			//if(!ob){
			//	ob = root->load_player(member);
			//	rmflag = 1;
			//}
			ob->bangid = 0;
			tell_object(ob,"帮主解散了帮派\n");
			//if(rmflag)
			//	ob->remove();
		}
		m_delete(bang_members,bangid);
	}
	if(bang_exist[bang_name])
		m_delete(bang_exist,bang_name);
	m_delete(bang_chat,bangid);
	//帮派解散，要是在帮战中则自动退出帮战
	BANGZHAND->quit_bangzhan(bangid);
}

//判断是否存在这个帮派
//liaocheng于07/09/04添加
int if_is_bang(int bangid)
{
	if(bang_list[bangid])
		return 1;
	else
		return 0;
}
