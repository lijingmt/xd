/*gamelib/single/daemons/termd.pike
 * 组队管理类
 ********************************************************************** 
 * 组队系统守护进程
 本系统主要负责玩家组队的界面管理，状态管理等等，玩家重新登陆游戏后
 将不在任何队伍中
 * 1.关于组队打怪，掉落物品经验金钱分配的模块，统一在战斗系统和npc的
   fight_die调用中进行处理，本模块相对独立，只负责队伍表现层和管理层。
 * 2.本管理模块将在内存中创建一块队列管理内存，专门负责在线所有队列的
   信息和接口，如果玩家在某个队列中，下线之后，重新登陆将不再属于任何
   队列，这样做的原因是减少存储队列信息所带来的系统负担。
 * @author calvin 
 * $Date: 2007/03/09 10:56 $
 ***********************************************************************/
#include <globals.h>
#include <wapmud2/include/wapmud2.h>
#define TERM_NUM 5 //队伍上限5人,以后有可能有不同人数的选择
#define TERM_INVITE_TIMEOUT 120
#define LOGICALZONED ((object)(ROOT "/gamelib/single/daemons/logical_zoned.pike"))
#define MAPWORKERD ((object)(ROOT "/gamelib/single/daemons/map_workerd.pike"))
inherit LOW_DAEMON;

// 组队经验先提高全队共享池，再按同房合法队员数分配。
// 五人上限与TERM_NUM一致；非法人数不获得额外加成。
int query_team_exp_pool_percent(int member_count)
{
	if(member_count==2)
		return 120;
	if(member_count==3)
		return 140;
	if(member_count==4)
		return 160;
	if(member_count==5)
		return 200;
	return 100;
}
/********************************************************************** 
 队伍内存结构:每创建一个队伍，增加一个临时队伍id，对应id，放置
 该队列中队员的一些固定信息，可以在队列信息中查阅，至于队员所在房间
 这样的动态信息，可以用(string)environment(player)->query_name_cn()动态得到
([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
 **********************************************************************/
private mapping(string:mapping(string:array)) termMain=([]);

//队伍人员聊天信息mapping对象
private mapping(string:array(string)) termChat=([]);

//队伍物品仓库，在boss掉落物品后放入其中，队友可以查看，但只有队长才能分配
//([队伍id:（{物品一，物品二}）])
//由liaocheng于07/06/20添加，为了boss装备的分配
private mapping(string:array(object)) termItems=([]);

// HTTP/Vue玩家没有持续socket输出，组队邀请必须在守护进程中暂存，
// 由状态轮询和“我的队伍”页面共同展示。
private mapping(string:array(mixed)) termInvites=([]);
// Distributed workers keep primitive replicas only; room objects and loot stay
// on the one worker that owns their room affinity.
private mapping(string:int) termRevisions=([]);
private mapping(string:string) termRevisionWriters=([]);
private mapping(string:int) termCreatedAt=([]);
private int distributedTermApply;
int add_termItems(string termid,object item)
{
	if(!termid || termid=="" || !item || !query_termId(termid))
		return 0;
	if(termItems[termid] == 0)
		termItems[termid] = ({item});
	else
		termItems[termid] += ({item});
	return 1;
}

int query_term_item_count(string termid)
{
	return arrayp(termItems[termid]) ? sizeof(termItems[termid]) : 0;
}
//删除已经分配了的物品
void delete_termItems(string termid,int index)
{
	//flush_term(termid);
	if(termMain[termid]&&sizeof(termMain[termid]) && termItems[termid] &&
	   index>=0 && index<sizeof(termItems[termid])){
		termItems[termid] -= ({termItems[termid][index]});
	}
	if(termItems[termid] && sizeof(termItems[termid])==0)
		m_delete(termItems,termid);
}
//查看仓库里物品时调用
string query_termItems(string tid,int flag,void|string viewer_id)
{
	string s_rtn = "";
	if(viewer_id && !can_read_term(tid,viewer_id))
		return "队伍仓库不可用。\n";
	//flush_term(tid);
	if(termMain[tid]&&sizeof(termMain[tid])){
		array(object) tmp = termItems[tid];
		if(tmp && sizeof(tmp)){
			for(int i=0;i<sizeof(tmp);i++){
				string s_file = file_name(tmp[i]);
				array tmp_arr = s_file/"#";
				int fg = 0;
				if(sizeof(tmp_arr)>=2)
					fg = (int)tmp_arr[1];
				s_file = tmp_arr[0];
				s_rtn += "["+tmp[i]->query_name_cn()+":inv_other "+s_file+"] ";
				if(flag==1)
					s_rtn += "[分配:fb_items_assign "+tid+" "+i+" "+s_file+" "+fg+"]\n";
				else
					s_rtn += "\n";
			}
		}
	}
	return s_rtn;
}
//检查是否已经分配过此物品了，为了防止刷装备情况出现
int if_have_assigned(string tid,string s_file,int fg,int index)
{
	if(termMain[tid]&&sizeof(termMain[tid])){
		array(object) tmp = termItems[tid];
		if(tmp && sizeof(tmp)){
			if(index<0 || index>=sizeof(tmp))
				return 1;
			array(string)tmp_str = file_name(tmp[index])/"#";
			if(sizeof(tmp_str)<2)
				return 1;
			if(s_file == tmp_str[0] && fg == (int)tmp_str[1])
				return 0;
		}
	}
	return 1;
}

//分配仓库物品时列出队友列表
string query_termers_for_assign(string tid,string s_file,int fg,int index,
	void|string viewer_id)
{
	string s_rtn = "";
	if(viewer_id && !can_read_term(tid,viewer_id))
		return s_rtn;
	flush_term(tid);
	if(termMain[tid]&&sizeof(termMain[tid])){
		//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
		foreach(indices(termMain[tid]), string uid){
			if(viewer_id &&
			   !LOGICALZONED->can_user_interact(viewer_id,uid))
				continue;
			object ob = find_player(uid);
			if(ob){
				s_rtn += "["+ob->query_name_cn()+":fb_assign_confirm "+ob->query_name()+" "+tid+" "+s_file+" "+fg+" "+index+"]("+ob->query_level()+"级"+ob->query_profe_cn(ob->query_profeId())+")\n";
			}
		}
	}
	return s_rtn;
}
//分配帮战特殊物品的接口
//由liaocheng于07/09/03添加
string query_termers_for_assign_bz(string tid,string s_file,int fg,int index,
	void|string viewer_id)
{
	string s_rtn = "";
	if(viewer_id && !can_read_term(tid,viewer_id))
		return s_rtn;
	if(termMain[tid]&&sizeof(termMain[tid])){
		//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
		foreach(indices(termMain[tid]), string uid){
			if(viewer_id &&
			   !LOGICALZONED->can_user_interact(viewer_id,uid))
				continue;
			object ob = find_player(uid);
			if(ob){
				if(ob->bangid == BANGZHAND->query_top_bang(1))
					s_rtn += "["+ob->query_name_cn()+":fb_assign_confirm "+ob->query_name()+" "+tid+" "+s_file+" "+fg+" "+index+"]("+ob->query_level()+"级"+ob->query_profe_cn(ob->query_profeId())+")\n";
			}
		}
	}
	return s_rtn;
}


//该守护进程在系统启动时被gamelib/master.pike负责调用并在create方法中初始化
protected void create(){
	//内存写入锁定
	if(termMain==0)
		termMain=([]);
	if(termChat==0)
		termChat=([]);
	if(termInvites==0)
		termInvites=([]);
	if(termRevisions==0)
		termRevisions=([]);
	if(termRevisionWriters==0)
		termRevisionWriters=([]);
	if(termCreatedAt==0)
		termCreatedAt=([]);
}

private int valid_distributed_team_token(string value,int maximum)
{
	if(!value || value=="" || sizeof(value)>maximum || search(value,"..")!=-1)
		return 0;
	foreach(value;int index;int one)
		if(!((one>='a' && one<='z') || (one>='A' && one<='Z') ||
		     (one>='0' && one<='9') || one=='_' || one=='-' || one=='.'))
			return 0;
	return 1;
}

private mapping distributed_online_user(string userid)
{
	if(MAPWORKERD->query_node_role()!="worker")
		return ([]);
	return MAPWORKERD->query_local_online_user(userid);
}

mapping query_distributed_team_snapshot(string tid)
{
	mapping members = mappingp(termMain[tid]) ?
		copy_value(termMain[tid]) : ([]);
	array chat = arrayp(termChat[tid]) ? copy_value(termChat[tid]) : ({});
	return (["team_id":tid,"revision":termRevisions[tid],
		"writer":termRevisionWriters[tid] || "",
		"members":members,"chat":chat,
		"created_at":termCreatedAt[tid],"updated_at":time()]);
}

private void publish_distributed_team_snapshot(string tid,string source_user,
	void|int tombstone)
{
	if(distributedTermApply || MAPWORKERD->query_node_role()!="worker" ||
	   !valid_distributed_team_token(tid,96) ||
	   !valid_distributed_team_token(source_user,64))
		return;
	termRevisions[tid] = max(0,termRevisions[tid])+1;
	termRevisionWriters[tid] = MAPWORKERD->query_local_worker_id();
	mapping snapshot = query_distributed_team_snapshot(tid);
	if(tombstone){
		snapshot["members"] = ([]);
		snapshot["chat"] = ({});
		snapshot["tombstone"] = 1;
	}
	mapping staged = MAPWORKERD->stage_local_social_event(
		"team_snapshot",source_user,"",(["snapshot":snapshot]));
	if(!(int)staged["ok"])
		werror("[TERMD][SYNC_QUEUE_FAILED] team=%s source=%s\n",tid,source_user);
}

private void reconcile_local_team_members(string tid,mapping old_members,
	mapping new_members)
{
	foreach(indices(old_members),string userid){
		if(new_members[userid])
			continue;
		object player = find_player(userid);
		if(player && (string)player->query_term()==tid)
			player->set_term("noterm");
	}
	foreach(indices(new_members),string userid){
		object player = find_player(userid);
		if(player && (string)player->query_term()!=tid)
			player->set_term(tid);
	}
}

mapping apply_distributed_team_snapshot(mapping snapshot)
{
	string tid = (string)(snapshot["team_id"] || "");
	string writer = (string)(snapshot["writer"] || "");
	mapping raw_members = mappingp(snapshot["members"]) ?
		(mapping)snapshot["members"] : ([]);
	array raw_chat = arrayp(snapshot["chat"]) ? (array)snapshot["chat"] : ({});
	mapping(string:array) members = ([]);
	array(string) chat = ({});
	int revision = (int)snapshot["revision"];
	int leaders;
	if(MAPWORKERD->query_node_role()!="worker" ||
	   !valid_distributed_team_token(tid,96) ||
	   !valid_distributed_team_token(writer,48) || revision<1 ||
	   sizeof(raw_members)>TERM_NUM || sizeof(raw_chat)>16)
		return (["ok":0,"code":"invalid_team_snapshot"]);
	foreach(indices(raw_members),mixed raw_userid){
		if(!stringp(raw_userid) || !arrayp(raw_members[raw_userid]))
			return (["ok":0,"code":"invalid_team_snapshot"]);
		string userid = (string)raw_userid;
		array row = (array)raw_members[raw_userid];
		if(!valid_distributed_team_token(userid,64) || sizeof(row)<4 ||
		   !stringp(row[0]) || sizeof((string)row[0])>160 ||
		   !has_value(({"leader","termer"}),(string)row[1]) ||
		   !stringp(row[2]) || sizeof((string)row[2])>48 ||
		   !intp(row[3]) || (int)row[3]<0 || (int)row[3]>10000)
			return (["ok":0,"code":"invalid_team_snapshot"]);
		if((string)row[1]=="leader")
			leaders++;
		members[userid] = ({(string)row[0],(string)row[1],
			(string)row[2],(int)row[3]});
	}
	if(sizeof(members) && leaders!=1)
		return (["ok":0,"code":"invalid_team_leader"]);
	if(sizeof(members)){
		string anchor = "";
		foreach(indices(members),string userid)
			if((string)members[userid][1]=="leader"){
				anchor = userid;
				break;
			}
		foreach(indices(members),string userid)
			if(!LOGICALZONED->can_user_action("team",anchor,userid))
				return (["ok":0,"code":"cross_zone_team_snapshot"]);
	}
	foreach(raw_chat,mixed raw_line){
		if(!stringp(raw_line) || sizeof((string)raw_line)>2048)
			return (["ok":0,"code":"invalid_team_chat_snapshot"]);
		chat += ({(string)raw_line});
	}
	if(revision<termRevisions[tid] ||
	   (revision==termRevisions[tid] &&
	    writer<= (termRevisionWriters[tid] || "")))
		return (["ok":1,"replayed":1,"team_id":tid]);
	mapping old_members = mappingp(termMain[tid]) ?
		copy_value(termMain[tid]) : ([]);
	distributedTermApply = 1;
	termRevisions[tid] = revision;
	termRevisionWriters[tid] = writer;
	if(sizeof(members)){
		termMain[tid] = members;
		termChat[tid] = chat;
		termCreatedAt[tid] = max(0,(int)snapshot["created_at"]);
	}
	else{
		m_delete(termMain,tid);
		m_delete(termChat,tid);
		m_delete(termItems,tid);
		m_delete(termCreatedAt,tid);
	}
	reconcile_local_team_members(tid,old_members,members);
	distributedTermApply = 0;
	return (["ok":1,"team_id":tid,"revision":revision]);
}

mapping query_distributed_team_snapshot_for_user(string userid)
{
	object player = find_player(userid);
	string tid = player ? (string)player->query_term() : "";
	if(!player || tid=="" || tid=="noterm" || !termMain[tid])
		return (["ok":1,"snapshot":0]);
	return (["ok":1,"snapshot":query_distributed_team_snapshot(tid)]);
}

int create_term_invite(string inviter_uid,string target_uid)
{
	object inviter;
	object target;
	mapping remote_target;
	string team_id;
	if(!inviter_uid || inviter_uid=="" ||
	   !target_uid || target_uid=="" || inviter_uid==target_uid)
		return 0;
	inviter = find_player(inviter_uid);
	target = find_player(target_uid);
	if(!inviter)
		return 0;
	if(!target)
		remote_target = distributed_online_user(target_uid);
	if(!target && !(int)remote_target["ok"])
		return 0;
	if(!LOGICALZONED->can_user_interact(inviter_uid,target_uid)){
		tell_object(inviter,"逻辑分区隔离中，不能邀请该玩家组队。\n");
		return 0;
	}
	if(target && target->query_term()!="" && target->query_term()!="noterm"){
		if(query_termId(target->query_term()))
			return 2;
		target->set_term("noterm");
	}
	team_id = (string)inviter->query_term();
	if(team_id=="" || team_id=="noterm" || !query_termId(team_id)){
		team_id = term_create(inviter_uid);
		if(sizeof(team_id)<=1)
			return 0;
	}
	if(!target){
		mapping staged = MAPWORKERD->stage_local_social_event(
			"team_invite",inviter_uid,target_uid,([
				"inviter_uid":inviter_uid,
				"inviter_name_cn":inviter->query_name_cn(),
				"team_id":team_id,"expires_at":time()+TERM_INVITE_TIMEOUT,
				"snapshot":query_distributed_team_snapshot(team_id),
			]));
		return (int)staged["ok"] ? 1 : 0;
	}
	termInvites[target_uid] = ({inviter_uid,
		inviter->query_name_cn(),time()+TERM_INVITE_TIMEOUT,team_id});
	return 1;
}

mapping apply_distributed_team_invite(string event_id,string target_uid,
	mapping payload)
{
	object target = find_player(target_uid);
	string inviter_uid = (string)(payload["inviter_uid"] || "");
	string inviter_name_cn = (string)(payload["inviter_name_cn"] || "");
	string team_id = (string)(payload["team_id"] || "");
	int expires_at = (int)payload["expires_at"];
	if(!target || !valid_distributed_team_token(event_id,96) ||
	   !valid_distributed_team_token(inviter_uid,64) ||
	   !valid_distributed_team_token(team_id,96) ||
	   inviter_name_cn=="" || sizeof(inviter_name_cn)>160 ||
	   expires_at<time() || expires_at>time()+TERM_INVITE_TIMEOUT+5 ||
	   !mappingp(payload["snapshot"]) ||
	   !LOGICALZONED->can_user_action("team",inviter_uid,target_uid))
		return (["ok":0,"code":"invalid_team_invite"]);
	mapping imported = apply_distributed_team_snapshot(
		(mapping)payload["snapshot"]);
	if(!(int)imported["ok"])
		return imported;
	if(target->query_term()!="" && target->query_term()!="noterm")
		return (["ok":1,"code":"target_already_teamed"]);
	termInvites[target_uid] = ({inviter_uid,inviter_name_cn,
		expires_at,team_id});
	tell_object(target,inviter_name_cn+
		"邀请你加入一个队伍，是否同意？\n[同意:term_ok "+inviter_uid+
		"] [拒绝:term_refuse "+inviter_uid+"]\n");
	return (["ok":1,"team_id":team_id]);
}

mapping query_term_invite(string target_uid)
{
	mapping result = ([]);
	array(mixed) invite;
	object inviter;
	object target;
	if(!target_uid || target_uid=="" || !termInvites[target_uid])
		return result;
	invite = termInvites[target_uid];
	if(sizeof(invite)<3 || (int)invite[2]<time()){
		m_delete(termInvites,target_uid);
		return result;
	}
	inviter = find_player((string)invite[0]);
	target = find_player(target_uid);
	if(!inviter && !(int)distributed_online_user((string)invite[0])["ok"]){
		m_delete(termInvites,target_uid);
		return result;
	}
	if(!target ||
	   !LOGICALZONED->can_user_interact(target_uid,(string)invite[0]) ||
	   (target->query_term()!="" && target->query_term()!="noterm")){
		m_delete(termInvites,target_uid);
		return result;
	}
	result["pending"] = 1;
	result["from"] = (string)invite[0];
	result["from_name"] = (string)invite[1];
	result["expires_at"] = (int)invite[2];
	result["team_id"] = sizeof(invite)>3 ? (string)invite[3] : "";
	return result;
}

int valid_term_invite(string target_uid,string inviter_uid)
{
	mapping invite = query_term_invite(target_uid);
	return invite["pending"] && invite["from"]==inviter_uid;
}

void clear_term_invite(string target_uid,void|string inviter_uid)
{
	if(!target_uid || target_uid=="" || !termInvites[target_uid])
		return;
	if(!inviter_uid || inviter_uid=="" ||
	   (string)termInvites[target_uid][0]==inviter_uid)
		m_delete(termInvites,target_uid);
}
////////////////队伍基本接口////////////////////////////////////////////
//	提供队伍基本接口：队伍建立，解除，更新，聊天内容更新
////////////////////////////////////////////////////////////////////////
//--------察看队伍状态接口--------
string query_termStatus(string tid,string uid){
	string result = "";
	if(tid&&sizeof(tid)&&uid&&sizeof(uid)){
		//every time user check term status, call flush_term to 
		//check if termer who offline, and if leader offline, reset term leader
		flush_term(tid);
		if(termMain[tid]&&sizeof(termMain[tid]))
			result += query_termList(tid,uid);
	}
	if(!result||result=="")
		result += "你现在没有在任何队伍中。\n";	
	return result;
}
//获取根据时间获得的随机队伍id,保证没有重复的队伍id
	string get_random_tid(string uid){
		if(uid&&sizeof(uid))
			return uid+time();
		return "";
	}
//----------建立队伍接口,只有第一次邀请，开始建立队伍，队长为第一个邀请者----------
//----返回建立的队伍临时id----------
//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
//private protected mapping(string:mapping(string:array)) termMain=([]);
string term_create(string user){
	if(user&&sizeof(user)){
		object player = find_player(user);
		if(player){
			string tid = get_random_tid(user);	
			if(tid&&sizeof(tid)){
				if(termMain[tid]&&sizeof(termMain[tid]))
					return "1";//失败，该新创建的队伍id，已经存在于termMain内存列表中
				mapping(string:array) t_m = ([]);
				array t_a = ({});
				t_a += ({player->query_name_cn()});//队员中文名称
				t_a += ({"leader"});//队员权限，创建者为队长
				t_a += ({player->query_profeId()});//队员职业
				t_a += ({player->query_level()});//队员等级
				t_m[user] = t_a;
				termMain[tid] = t_m;
				termCreatedAt[tid] = time();
				//该创建者加上队伍id
				player->set_term(tid);
				//初始化新队伍的聊天内存
				array(string) chatTmp;
				//string strchat = "队伍信息\n:暂无\n";                                                                  
				string strchat = " : \n";                                                                  
				chatTmp = strchat/":";
				termChat[tid] = chatTmp;
				publish_distributed_team_snapshot(tid,user);
				return tid;//成功创建队伍,返回队列id
			}
			else
				return "2";//创建失败,未取到队伍随机id
		}
		else
			return "3";//创建失败，创建者对象未找到
	}
	return "4";//创建失败,传递的创建者id为空
}
//----------解散队伍接口，必须在调用接口上层过判断是否是队长权限----------
int destory_term(string termid,string uid){
	if(termid&&sizeof(termid)&&uid&&sizeof(uid)){
		//判断权限，如果非队长，不能操作
		if(get_term_power(termid,uid)!="leader")
			return 4;//非队长权限，不能解散队伍 
		if(termMain[termid]&&sizeof(termMain[termid])){
			if(query_termId(termid)){
				//未解散前，发消息给所有队员
				string msg = "你所在的队伍解散了。\n";
				term_tell(termid,msg);
				//let every termer's "term" = "noterm" and then delete termMain[tid]
				foreach(indices(termMain[termid]), string termer){
					object who = find_player(termer);
					if(who)
						who->set_term("noterm");
				}
				publish_distributed_team_snapshot(termid,uid,1);
				m_delete(termMain,termid);
				m_delete(termCreatedAt,termid);
				if(termChat[termid])
					m_delete(termChat,termid);
				//liaocheng 解散后，队伍仓库清空
				if(termItems[termid])
					m_delete(termItems,termid);
				return 1;//成功解散队伍
			}
			else
				return 0;//解散失败，队列mapping中没有该队伍
		}
		else
			return 2;//解散失败,未在队列mapping中找到该队伍
	}
	else
		return 3;//解散失败，队伍对象id为空
}
//----------判断队员权限----------
//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
//private protected mapping(string:mapping(string:array)) termMain=([]);
string get_term_power(string termid,string uid){
	if(termid&&sizeof(termid)&&uid&&sizeof(uid)){
		if(query_termId(termid)){
			if(termMain[termid]&&sizeof(termMain[termid])){
				if(termMain[termid][uid]&&sizeof(termMain[termid][uid])){
					if(termMain[termid][uid][1]&&sizeof(termMain[termid][uid][1]))
						return termMain[termid][uid][1];//取得并返回该用户权限描述
				}
			}
		}
	}
	else
		return "fail";//队伍id和队员id无效
}
//----------查找当前队伍id列表内存主文件中是否有该队列id----------
//private protected mapping(string:mapping(string:array)) termMain=([]);
int query_termId(string tid){
	int flag = 0;
	if(tid&&sizeof(tid)){
		foreach(indices(termMain),string index){
			if(index==tid)
				flag = 1;
		}
	}
	else
		flag = 0;
	return flag;
}
//----------队伍聊天操作------------
//返回队伍聊天信息列表，加上聊天指令
//private protected mapping(string:array(string)) termChat=([]);
private string query_term_anchor(string tid)
{
	if(!tid || !termMain[tid] || !sizeof(termMain[tid]))
		return "";
	foreach(indices(termMain[tid]),string uid)
		if(termMain[tid][uid] && sizeof(termMain[tid][uid])>1 &&
		   termMain[tid][uid][1]=="leader")
			return uid;
	return indices(termMain[tid])[0];
}

private int can_read_term(string tid,string viewer_id)
{
	string anchor = query_term_anchor(tid);
	return anchor!="" && viewer_id && termMain[tid][viewer_id] &&
		LOGICALZONED->can_user_interact(anchor,viewer_id);
}

string query_termChat(string tid,void|string viewer_id){
	string results = "";
	if(viewer_id && !can_read_term(tid,viewer_id))
		return "队伍信息暂无。\n";
	if(tid&&sizeof(tid)){
		if(termChat&&sizeof(termChat)){
			array(string) tmp = ({});
			if(termChat[tid]&&sizeof(termChat[tid]))
				tmp = (array)termChat[tid];
			mapping(int:string) chatrever = ([]);
			if(tmp&&sizeof(tmp)){
				int count = 0;
				foreach(tmp,string msg){
					if(msg&&sizeof(msg)){
						chatrever[count] = msg;
						count++;
					}
				}
				foreach(reverse(sort(indices(chatrever))), int ind)
					results += (string)chatrever[ind];	
			}
		}
		if(results&&sizeof(results))
			;
		else
			results += "队伍信息暂无。\n";
	}
	else
		results += "队伍信息暂无。\n";
	return results;
}

//ui上调用的队伍聊天接口
string query_termChat_ui(string tid,void|string viewer_id){
	string results = "";
	if(viewer_id && !can_read_term(tid,viewer_id))
		return "队伍信息暂无。\n";
	if(tid&&sizeof(tid)){
		if(termChat&&sizeof(termChat)){
			array(string) tmp = ({});
			if(termChat[tid]&&sizeof(termChat[tid]))
				tmp = (array)termChat[tid];
			mapping(int:string) chatrever = ([]);
			int count = 0;
			if(sizeof(tmp)>0 && sizeof(tmp)<=3){
				foreach(tmp,string msg){
					if(msg&&sizeof(msg)){
						chatrever[count] = msg;
						count++;
					}
				}
			}
			else if(sizeof(tmp)>3){
				int end = sizeof(tmp);
				for(int i=end-3;i<end;i++){
					string msg = tmp[i];
					if(msg&&sizeof(msg)){
						chatrever[count] = msg;
						count++;
					}
				}
			}
			foreach(reverse(sort(indices(chatrever))), int ind)
				results += (string)chatrever[ind];	
		}
		if(results&&sizeof(results))
			;
		else
			results += "队伍信息暂无。\n";
	}
	else
		results += "队伍信息暂无。\n";
	return results;
}

//----------队伍聊天操作--------
//更新队伍聊天信息列表
//private protected mapping(string:array(string)) termChat=([]);
//注意，传来的msg信息中已经带了发言者中文名，这里就不用加了
int add_termChat(string tid,string msg,void|string sender_id)
{
	//string now=ctime(time());
	//Stdio.append_file(ROOT+"/txonline/bangpai.log",now[0..sizeof(now)-2]+":["+tid+"]["+uid+"]:\n"+msg+"\n");
	int flag = 1;
	if(tid&&sizeof(tid)&&msg&&sizeof(msg) &&
	   (!sender_id || can_read_term(tid,sender_id))){
		array tmparr;
		if(termChat&&sizeof(termChat))
			tmparr = termChat[tid];
		if(!tmparr){
			string str1 = "队伍信息\n"+":"+msg+"\n";
			array a1 = str1/":";
			termChat[tid] = a1;
			flag = 1;
		}
		else{//聊天信息不为空，顺延并删除头信息
			if(sizeof(tmparr)<=15){
				string s1 = "";
				//小于15行，顺延加入聊天信息
				for(int i=0; i<sizeof(tmparr); i++)
					s1 += (string)tmparr[i]+":";
				s1 += msg + "\n";
				array newarr = s1/":";
				//更新聊天内存文件
				termChat[tid] = newarr;
				flag = 1;
			}
			else{
				string s1 = "";
				//大于15行，去掉头信息，再顺延加入聊天信息至尾
				for(int i=1; i<sizeof(tmparr); i++)
					s1 += (string)tmparr[i]+":";
				s1 += msg + "\n";
				array newarr = s1/":";
				//更新聊天内存文件
				termChat[tid] = newarr;
				flag = 1;
			}
		}
	}
	else
		flag = 0;
	if(flag && sender_id && sender_id!="" && !distributedTermApply &&
	   MAPWORKERD->query_node_role()=="worker")
		MAPWORKERD->stage_local_social_event("team_chat",sender_id,"",([
			"team_id":tid,"message":msg,
		]));
	return flag;
}

/*
 * Team events are fanned out to every worker.  A worker with no local member
 * must acknowledge the event instead of forcing the source to retry forever.
 * The authoritative worker-local lease table avoids online-snapshot lag.
 */
private int local_worker_has_team_player(string tid)
{
	if(MAPWORKERD->query_node_role()!="worker")
		return 1;
	return MAPWORKERD->local_team_player_exists(tid);
}

mapping apply_distributed_team_chat(string tid,string msg,string sender_id)
{
	int added;
	if(!valid_distributed_team_token(tid,96) ||
	   !valid_distributed_team_token(sender_id,64) || msg=="" ||
	   sizeof(msg)>2048)
		return (["ok":0,"code":"invalid_team_chat"]);
	if(!termMain[tid] || !termMain[tid][sender_id]){
		if(local_worker_has_team_player(tid))
			return (["ok":0,"code":"team_snapshot_missing"]);
		return (["ok":1,"ignored":1,"code":"no_local_team_member",
			"team_id":tid]);
	}
	distributedTermApply = 1;
	added = add_termChat(tid,msg,sender_id);
	distributedTermApply = 0;
	return (["ok":added ? 1 : 0,"team_id":tid]);
}



//转让队长：队伍的建立者可以转让队长，转让不用对方确认，
//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
//private protected mapping(string:mapping(string:array)) termMain=([]);
int update_termLeader(string tid, string olduid, string lname, string lname_cn)
{
	int flag = 0;
	if(!LOGICALZONED->can_user_interact(olduid,lname))
		return 0;
	if(tid&&sizeof(tid)&&olduid&&sizeof(olduid)&&lname&&sizeof(lname)&&lname_cn&&sizeof(lname_cn)){
		//更新队列内存文件
		if(termMain[tid]&&sizeof(termMain[tid])){//判断队列是否存在内存中
			foreach(indices(termMain[tid]),string index){
				if(index&&sizeof(index)){//得到原队长队列内存状态
					if(index==olduid){
						if(termMain[tid][olduid]&&sizeof(termMain[tid][olduid])){//队长内存状态正常
							if((string)termMain[tid][olduid][1]=="leader"){//判断原来是否是队长
								if(termMain[tid][lname]&&sizeof(termMain[tid][lname])){//判断新队长内存状态
									termMain[tid][olduid][1] = "termer";//原队长状态改变
									termMain[tid][lname][1] = "leader";//新队长状态改变
									flag = 1;
								}
							}
						}
					}
				}
			}
		}
	}
	else 
		flag = 0;
	if(flag){
		//发消息给该队伍中的队员通知队长转让
		string msg = "现在队长是"+lname_cn+"\n";
		publish_distributed_team_snapshot(tid,olduid);
		term_tell(tid,msg);
	}
	return flag;
}
//返回队员权限等级描述
string query_termPower(string tid,string uid){
	string results = "";
	if(tid&&sizeof(tid)&&uid&&sizeof(uid)){
		if(termMain[tid]&&sizeof(termMain[tid])){//判断队列是否存在内存中
			foreach(indices(termMain[tid]),string index){
				if(index==uid){
					results += (string)termMain[tid][uid][1]; 
					break;
				}
			}
		}
	}
	if(results=="leader")
		return "队长";
	return "";
}
//队伍增加队员,被动调用，在玩家接受组队邀请时调用
//private protected mapping(string:mapping(string:array)) termMain=([]);
int add_termer(string tid, string uid, string uname){
	if(tid&&sizeof(tid)&&uid&&sizeof(uid)&&uname&&sizeof(uname)){
		if(termMain[tid]&&sizeof(termMain[tid])){
			array(string) current_members = indices(termMain[tid]);
			if(!sizeof(current_members) ||
			   !LOGICALZONED->can_user_interact(current_members[0],uid))
				return 4;//逻辑分区不同，拒绝伪造或过期的入队请求
			if(sizeof(termMain[tid])>=TERM_NUM)
				return 2;//队伍人数已经5人，无法添加新队员
			else{
				object player = find_player(uid);
				if(player){
					array t_a = ({});
					t_a += ({player->query_name_cn()});//队员中文名称
					t_a += ({"termer"});//队员权限，
					t_a += ({player->query_profeId()});//队员职业
					t_a += ({player->query_level()});//队员等级
					termMain[tid][uid] = t_a;
					//将该用户的队伍临时id赋值
					player->set_term(tid);
					string msg = player->query_name_cn()+"加入了队伍\n";
					//发消息给该队伍中的队员通知增加新队员
					publish_distributed_team_snapshot(tid,uid);
					term_tell(tid,msg);
					return 1;//成功加入新队员
				}
				else
					return 3;//被加入的队员不再线
			}
		}
	}
	return 0;//参数有问题
}
//查看队伍人员
//队长察看和队员察看，返回结果中附加的连接不同
//private protected mapping(string:mapping(string:array)) termMain=([]);
string query_termList(string tid,string userid){//这里传回调用者id，判断是否队长返回不同连接
	string results = "";
	if(tid&&sizeof(tid)&&userid&&sizeof(userid)){
		//在线队伍人数
		int count;
		if(termMain[tid]&&sizeof(termMain[tid])){
			int is_leader = 0;
			string leader_name = "";
			foreach(indices(termMain[tid]), string uid){
				if(termMain[tid][uid]&&sizeof(termMain[tid][uid])){
					if(uid==userid)
						//调用者为队长
						if(termMain[tid][uid][1]=="leader"){
							is_leader = 1;
							leader_name = termMain[tid][uid][0];
							break;
						}
				}
			}
			//调用者是队长或者队员，返回不同带功能连接
			foreach(indices(termMain[tid]), string uid){
				if(!LOGICALZONED->can_user_interact(userid,uid))
					continue;
				count++;
				object ob = find_player(uid);
				if(ob){
					//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
					results += ob->query_name_cn()+"("+ob->query_profe_cn(ob->query_profeId())+")("+ob->query_level()+"级)";
					results += "("+(string)environment(ob)->query_name_cn()+")";
					//if(is_leader&&userid==ob->query_name())
					if(termMain[tid][uid][1]=="leader")	
						results+="(队长)\n";
					else
						results+="\n";
					if(is_leader){
						if(userid!=ob->query_name()){
							results += "[提为队长:term_changeleader "+ob->query_name()+"] ";
							results += "[移出队伍:term_kick "+ob->query_name()+"]\n";
						}
					}
				}
				else{
					mapping remote = distributed_online_user(uid);
					if((int)remote["ok"]){
						array member = termMain[tid][uid];
						results += (string)member[0]+"("+(string)member[2]+")("+
							(string)(int)member[3]+"级)("+
							(string)(remote["room_name"] || "跨地图")+")";
						if((string)member[1]=="leader")
							results += "(队长)\n";
						else
							results += "\n";
						if(is_leader && userid!=uid)
							results += "[提为队长:term_changeleader "+uid+"] "+
								"[移出队伍:term_kick "+uid+"]\n";
					}
				}
			}
			if(is_leader){
				results += "[解散队伍:term_release "+tid+"] ";
				results += "[队伍仓库:fb_term_cangku "+tid+" 1]\n"; //1表示队长，可分配

			}
			else{
				results += "[离开队伍:term_leave "+tid+"] ";
				results += "[队伍仓库:fb_term_cangku "+tid+" 0]\n"; //0表示队员，可观看
			}
			results = "队伍人数："+count+"/"+TERM_NUM+"\n"+results+"--------\n[队伍聊天:term_chat]\n--------\n";
		}
		else
			return "";
	}
	return results;
}
//删除队员，队长将某个队员踢出队伍
//private protected mapping(string:mapping(string:array)) termMain=([]);
int kick_termer(string tid, string uid, string uname){
	int flag = 0;
	if(tid&&sizeof(tid)&&uid&&sizeof(uid)&&uname&&sizeof(uname)){
		if(termMain[tid]&&sizeof(termMain[tid])){
			foreach(indices(termMain[tid]), string userid){
				if(userid==uid){
					if(termMain[tid][uid][1]=="leader"){
						//if now is leader, can not be kick out term
						return 2;//term leader now, can not be kick out term
					}
					object ob = find_player(uid);
					if(ob){
						ob->set_term("noterm");	
						tell_object(ob,"你被移出了队伍。\n");
					}
					m_delete(termMain[tid],uid);	
					flag = 1;
					break;
				}
			}
		}
	}
	if(flag){
		string msg = uname+"被移出了队伍。\n";
		//发消息给该队伍中的队员通知增加新队员
		publish_distributed_team_snapshot(tid,uid);
		term_tell(tid,msg);
		return 1;//成功删除队员
	}
	return 0;
}
//脱离队伍 
//由队员自己调用,立即生效，无须队长确定
int leave_term(string tid, string uid, string uname)
{
	int flag = 0;
	if(tid&&sizeof(tid)&&uid&&sizeof(uid)&&uname&&sizeof(uname)){
		if(termMain[tid]&&sizeof(termMain[tid])){
			foreach(indices(termMain[tid]), string userid){
				if(userid==uid){
					//if(termMain[tid][uid][1]=="leader"){
					//	//if now is leader, can not leave term
					//	return 2;//term leader now, can not leave term
					//}
					m_delete(termMain[tid],uid);	
					flag = 1;
					object ob = find_player(uid);
					if(ob){
						ob->set_term("noterm");
						tell_object(ob,"你脱离了这个队伍。\n");
					}
					break;
				}
			}
		}
	}
	if(flag){
		string msg = uname+"离开了队伍。\n";
		flush_term(tid);
		//发消息给该队伍中的队员通知增加新队员
		publish_distributed_team_snapshot(tid,uid);
		term_tell(tid,msg);
		return 1;//成功删除队员
	}
	return 0;
}
//----------解散队伍内部接口，程序判断只有一人的队伍自动解散功能----------
private int term_free(string termid){
	if(termid&&sizeof(termid)){
		if(termMain[termid]&&sizeof(termMain[termid])){
			if(query_termId(termid)){
				string source_user = query_term_anchor(termid);
				//未解散前，发消息给所有队员
				string msg = "你所在的队伍解散了。\n";
				term_tell(termid,msg);
				//let every termer's "term" = "noterm" and then delete termMain[tid]
				foreach(indices(termMain[termid]), string termer){
					object who = find_player(termer);
					if(who)
						who->set_term("noterm");
				}
				if(source_user!="")
					publish_distributed_team_snapshot(termid,source_user,1);
				m_delete(termMain,termid);
				m_delete(termCreatedAt,termid);
				if(termChat[termid])
					m_delete(termChat,termid);
				//liaocheng 解散后，队伍仓库清空
				if(termItems[termid])
					m_delete(termItems,termid);
				return 1;//成功解散队伍
			}
			else
				return 0;//解散失败，队列mapping中没有该队伍
		}
		else
			return 2;//解散失败,未在队列mapping中找到该队伍
	}
	else
		return 3;//解散失败，队伍对象id为空
}

//刷新队伍
void flush_term(string tid){
	if(tid&&sizeof(tid)){
		if(termMain[tid]&&sizeof(termMain[tid])){
			//队伍建立之后，起码两人，如果刷新之后只有一人，立刻解散。。。。。
			if(sizeof(termMain[tid])==1){
				// 跨 worker 邀请先创建队伍快照，再由目标节点接受；给这
				// 个单人预备队伍一个与邀请相同的有界存活窗口。
				if(MAPWORKERD->query_node_role()=="worker" &&
				   termCreatedAt[tid]+TERM_INVITE_TIMEOUT>=time())
					return;
				term_free(tid);			
				return;
			}
			int term_no_leader = 0;	
			string msg = "";
			foreach(indices(termMain[tid]), string userid){
				object ob = find_player(userid);	
				if(ob){
					if(ob->query_term()!=tid)
						m_delete(termMain[tid],userid);	
				}
				else{
					mapping remote = distributed_online_user(userid);
					if((int)remote["ok"])
						continue;
					//if the term leader offline, the next termer will be term leader	
					if(termMain[tid][userid][1]=="leader")
						term_no_leader = 1;	
					msg += "当前不在线的玩家 "+termMain[tid][userid][0]+" 被移出了队伍。\n";
					m_delete(termMain[tid],userid);	
				}
			}
			if(!termMain[tid] || sizeof(termMain[tid])==0){
				m_delete(termMain,tid);
				if(termChat[tid])
					m_delete(termChat,tid);
				if(termItems[tid])
					m_delete(termItems,tid);
				return;
			}
			if(sizeof(termMain[tid])==1){
				term_free(tid);
				return;
			}
			//if the term leader is offline, let's next termer be term leader
			if(term_no_leader){
				foreach(indices(termMain[tid]), string userid){
					object ob = find_player(userid);	
					if(ob){
						termMain[tid][userid][1]="leader";
						msg += ob->query_name_cn()+" 现在是队长。\n";
						break;
					}
				}
			}
			//发消息给该队伍中的队员通知增加新队员
			term_tell(tid,msg);
		}
	}
}

// 配置热切换后清理旧邀请和跨逻辑区队伍，避免在线合区/拆区遗留引用。
void enforce_zone_isolation()
{
	array(string) invite_targets = indices(termInvites);
	array(string) team_ids = indices(termMain);
	int i;
	for(i=0;i<sizeof(invite_targets);i++){
		string target_uid = invite_targets[i];
		array(mixed) invite = termInvites[target_uid];
		if(!invite || sizeof(invite)<1 ||
		   !LOGICALZONED->can_user_interact(target_uid,(string)invite[0]))
			m_delete(termInvites,target_uid);
	}
	for(i=0;i<sizeof(team_ids);i++){
		string tid = team_ids[i];
		array(string) members;
		string anchor = "";
		int j;
		if(!termMain[tid] || !sizeof(termMain[tid]))
			continue;
		members = indices(termMain[tid]);
		for(j=0;j<sizeof(members);j++){
			if(termMain[tid][members[j]] &&
			   sizeof(termMain[tid][members[j]])>1 &&
			   termMain[tid][members[j]][1]=="leader"){
				anchor = members[j];
				break;
			}
		}
		if(anchor=="" && sizeof(members))
			anchor = members[0];
		for(j=0;j<sizeof(members);j++){
			object player;
			if(LOGICALZONED->can_user_interact(anchor,members[j]))
				continue;
			player = find_player(members[j]);
			if(player){
				player->set_term("noterm");
				tell_object(player,"逻辑分区配置已更新，你已安全离开跨区队伍。\n");
			}
			m_delete(termMain[tid],members[j]);
			if(termChat[tid])
				m_delete(termChat,tid);
		}
		if(!termMain[tid] || sizeof(termMain[tid])<=1)
			term_free(tid);
		else
			flush_term(tid);
	}
}
//给所有队伍中的人发一条即时信息
//private protected mapping(string:mapping(string:array)) termMain=([]);
void term_tell(string tid,string msg){
	if(tid&&sizeof(tid)&&msg&&sizeof(msg)){
		if(termMain[tid]&&sizeof(termMain[tid])){
			string anchor = query_term_anchor(tid);
			foreach(indices(termMain[tid]),string uid){
				if(anchor!="" &&
				   !LOGICALZONED->can_user_interact(anchor,uid))
					continue;
				object ob = find_player(uid);
				if(ob)
					tell_object(ob,msg);
			}
			if(anchor!="" && !distributedTermApply &&
			   MAPWORKERD->query_node_role()=="worker")
				MAPWORKERD->stage_local_social_event(
					"team_notice",anchor,"",([
						"team_id":tid,"message":msg,
					]));
		}
	}
}

mapping apply_distributed_team_notice(string tid,string msg,string source_user)
{
	if(!valid_distributed_team_token(tid,96) ||
	   !valid_distributed_team_token(source_user,64) || msg=="" ||
	   sizeof(msg)>2048)
		return (["ok":0,"code":"invalid_team_notice"]);
	if(!termMain[tid] || !termMain[tid][source_user]){
		if(local_worker_has_team_player(tid))
			return (["ok":0,"code":"team_snapshot_missing"]);
		return (["ok":1,"ignored":1,"code":"no_local_team_member",
			"team_id":tid]);
	}
	distributedTermApply = 1;
	term_tell(tid,msg);
	distributedTermApply = 0;
	return (["ok":1,"team_id":tid]);
}
//返回所有队员内存状态
//private protected mapping(string:mapping(string:array)) termMain=([]);
//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
mapping query_term_m(string tid){
	mapping(string:array) m = ([]);
	if(tid&&sizeof(tid)){
		if(query_termId(tid)){
			if(termMain[tid]&&sizeof(termMain[tid])){
				m = termMain[tid];
			}
		}
	}
	return m;
}

int get_term_nums()
{
	if(termMain&&sizeof(termMain)){
		return sizeof(termMain);
	}
	else
		return 0;
}

//返回队员中所有最高等级
array(int) query_term_level(mapping m){
	if(m&&sizeof(m)){
		array(int) level_tmp = ({});
		foreach(indices(m),string uid){
			array tmp = m[uid];
			level_tmp += ({m[uid][3]});
		}
		if(level_tmp&&sizeof(level_tmp)){
			level_tmp = sort(level_tmp);
		}
		return level_tmp;
	}
	return 0;
}
