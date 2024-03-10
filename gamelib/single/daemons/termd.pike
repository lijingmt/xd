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
inherit LOW_DAEMON;
/********************************************************************** 
 队伍内存结构:每创建一个队伍，增加一个临时队伍id，对应id，放置
 该队列中队员的一些固定信息，可以在队列信息中查阅，至于队员所在房间
 这样的动态信息，可以用(string)environment(player)->query_name_cn()动态得到
([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
 **********************************************************************/
private static mapping(string:mapping(string:array)) termMain=([]);

//队伍人员聊天信息mapping对象
private static mapping(string:array(string)) termChat=([]);

//队伍物品仓库，在boss掉落物品后放入其中，队友可以查看，但只有队长才能分配
//([队伍id:（{物品一，物品二}）])
//由liaocheng于07/06/20添加，为了boss装备的分配
private mapping(string:array(object)) termItems=([]);
void add_termItems(string termid,object item)
{
	if(termItems[termid] == 0)
		termItems[termid] = ({item});
	else
		termItems[termid] += ({item});
	return;
}
//删除已经分配了的物品
void delete_termItems(string termid,int index)
{
	//flush_term(termid);
	if(termMain[termid]&&sizeof(termMain[termid])){
		termItems[termid] -= ({termItems[termid][index]});
	}
	if(sizeof(termItems[termid])==0)
		m_delete(termItems,termid);
}
//查看仓库里物品时调用
string query_termItems(string tid,int flag)
{
	string s_rtn = "";
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
			if(index > sizeof(tmp))
				return 1;
			array(string)tmp_str = file_name(tmp[index])/"#";
			if(s_file == tmp_str[0] && fg == (int)tmp_str[1])
				return 0;
		}
	}
	return 1;
}

//分配仓库物品时列出队友列表
string query_termers_for_assign(string tid,string s_file,int fg,int index)
{
	string s_rtn = "";
	flush_term(tid);
	if(termMain[tid]&&sizeof(termMain[tid])){
		//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
		foreach(indices(termMain[tid]), string uid){
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
string query_termers_for_assign_bz(string tid,string s_file,int fg,int index)
{
	string s_rtn = "";
	if(termMain[tid]&&sizeof(termMain[tid])){
		//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
		foreach(indices(termMain[tid]), string uid){
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
void create(){
	//内存写入锁定
	if(termMain==0)
		termMain=([]);
	if(termChat==0)
		termChat=([]);
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
//private static mapping(string:mapping(string:array)) termMain=([]);
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
				//该创建者加上队伍id
				player->set_term(tid);
				//初始化新队伍的聊天内存
				array(string) chatTmp;
				//string strchat = "队伍信息\n:暂无\n";                                                                  
				string strchat = " : \n";                                                                  
				chatTmp = strchat/":";
				termChat[tid] = chatTmp;
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
				m_delete(termMain,termid);
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
//private static mapping(string:mapping(string:array)) termMain=([]);
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
//private static mapping(string:mapping(string:array)) termMain=([]);
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
//private static mapping(string:array(string)) termChat=([]);
string query_termChat(string tid){
	string results = "";
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
string query_termChat_ui(string tid){
	string results = "";
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
//private static mapping(string:array(string)) termChat=([]);
//注意，传来的msg信息中已经带了发言者中文名，这里就不用加了
int add_termChat(string tid,string msg)
{
	//string now=ctime(time());
	//Stdio.append_file(ROOT+"/txonline/bangpai.log",now[0..sizeof(now)-2]+":["+tid+"]["+uid+"]:\n"+msg+"\n");
	int flag = 1;
	if(tid&&sizeof(tid)&&msg&&sizeof(msg)){
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
	return flag;
}



//转让队长：队伍的建立者可以转让队长，转让不用对方确认，
//([队伍临时id:([队员id:({队员中文名字,队员权限,队员职业,队员等级,})]),])
//private static mapping(string:mapping(string:array)) termMain=([]);
int update_termLeader(string tid, string olduid, string lname, string lname_cn)
{
	int flag = 0;
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
//private static mapping(string:mapping(string:array)) termMain=([]);
int add_termer(string tid, string uid, string uname){
	if(tid&&sizeof(tid)&&uid&&sizeof(uid)&&uname&&sizeof(uname)){
		if(termMain[tid]&&sizeof(termMain[tid])){
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
//private static mapping(string:mapping(string:array)) termMain=([]);
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
//private static mapping(string:mapping(string:array)) termMain=([]);
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
				//未解散前，发消息给所有队员
				string msg = "你所在的队伍解散了。\n";
				term_tell(termid,msg);
				//let every termer's "term" = "noterm" and then delete termMain[tid]
				foreach(indices(termMain[termid]), string termer){
					object who = find_player(termer);
					if(who)
						who->set_term("noterm");
				}
				m_delete(termMain,termid);
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
					//if the term leader offline, the next termer will be term leader	
					if(termMain[tid][userid][1]=="leader")
						term_no_leader = 1;	
					msg += "当前不在线的玩家 "+termMain[tid][userid][0]+" 被移出了队伍。\n";
					m_delete(termMain[tid],userid);	
				}
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
//给所有队伍中的人发一条即时信息
//private static mapping(string:mapping(string:array)) termMain=([]);
void term_tell(string tid,string msg){
	if(tid&&sizeof(tid)&&msg&&sizeof(msg)){
		if(termMain[tid]&&sizeof(termMain[tid])){
			foreach(indices(termMain[tid]),string uid){
				object ob = find_player(uid);
				if(ob)
					tell_object(ob,msg);
			}
		}
	}
}
//返回所有队员内存状态
//private static mapping(string:mapping(string:array)) termMain=([]);
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
