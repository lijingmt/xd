/*gamelib/single/daemons/chatroomd.pike
 * 聊天室内容及频道管理类
 ********************************************************************** 
 * 聊天室系统守护进程
 本系统主要负责玩家聊天室的界面管理，状态管理等等
 * .本管理模块将在内存中创建聊天管理内存，专门负责在线所有聊天频道的
   内容和接口,内容管理方式为用户自己屏蔽其他不良发言,自管理聊天频道.

   扩展(暂未实现):
		特殊权限用户可以当在线状态时,自己创建一个聊天频道
 * @author calvin 
 * $Date: 2007/04/16 13:13 $
 ***********************************************************************/
#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;
/**********************************************************************
聊天频道动态处理内存：

初始化一个mapping表影射游戏中现有聊天频道
根据配置文件的内容来形成对外给用户观察调用的接口，配置文件
可以动态添加，然后调用外部指令来呼叫内部更新接口来update现存聊天频道
(配置文件:ROOT/gamelib/data/chat/chatindex)
private static mapping(string:array) chatIndex = ([]);
([聊天频道id:({聊天频道名字,主题(可以在作活动时候临时添加注明),房间类型(系统或者自建),其他(创建时间等等)})]);
m**********************************************************************/
#define CHATROOM_LIMITTIME 7200 //玩家自创房间的存在时间限制,默认两个小时
private static mapping(string:array) chatIndex=([]);

/**********************************************************************
聊天频道对应内容内存：

mapping(string:array(string)) chatCont = ([]);
很简单，一个mapping影射，([聊天频道id,({聊天信息1,聊天信息2,聊天信息3,......(max=20)})])
每天聊天信息的格式：[发言者id]|发言信息
注意：每一页的聊天信息保留20条，最多60条聊天记录，分页为3页
***********************************************************************/
#define CHATLINE_MAX 60
private static mapping(string:array(string)) chatCont=([]);

/**********************************************************************
聊天频道管理功能：

用玩家自管理方法来进行管理，玩家可以屏蔽某个不良用户
的发言信息，在聊天信息列表的该发言用户旁边会有一个 屏蔽 的连接，如何实现
考虑屏蔽的帐号存放在该用户身上，每次登录清空即可(gamelib/d/init实现)。字段如下
 if(me["/plus/chatblock"])
	me["/plus/chatblock"] = 0;
以上是个array字符串数组，存放屏蔽的名单
***********************************************************************/
//["/plus/chatblock"] 用户内存字段

/**********************************************************************
	接口设计
	
	很简单,本守护进程就是实现一个动态的聊天房间,可以根据配置文件来读出
	写好的各个聊天频道,并提供给用户连接,选择登陆那个聊天频道,并在该频道
	输出和回显用户输入的信息(可以加上分页,最多3页)
	1.create():
		初始化接口，调用配置文件，读出聊天频道分配内存等等
	2.query_chatroom_list():
		返回现在开放频道列表，形成连接返回给用户
	3.query_chat_msg(string chatid, string look_id):
		取得某频道的聊天内容，返回并分页处理,这里需要注意的是,根据察看
		者传来的id得到察看者身上的屏蔽id列表，屏蔽掉屏蔽id的发言信息并
		返回聊天内容.
	4.add_chat_msg(string chatid, string msg, string uid):
		加入一条聊天信息在某频道，回显后，需要在该信息上附加该发言用户
		的连接，其他聊天用户点击后，可以看到 发信息和加为好友 两个连接
	5.reload_chatroom():
		重新读入配置文件，清空所有聊天信息
	6.add_chatroom(string uid):
		添加一个具有权限的玩家(或管理员)自创的聊天频道,更新chatIndex内存,但不清空
		其他频道聊天内容.
	7.del_chatroom(string chatid):
		删除某个频道,并清空其中内容.
	8.pagnition(string allmsg):
		分页处理接口,获得固定的60个聊天信息,实现分页管理.
	9.flush_all_room():
		定时更新在线频道状态，清除过期的用户自建聊天频道
***********************************************************************/

#define FILE_PATH "/gamelib/data/chat/chatindex"

void create(){
	//聊天频道主索引内存
	if(chatIndex==0)
		chatIndex=([]);
	//聊天频道所有内容内存
	if(chatCont==0)
		chatCont=([]);
	//加载聊天频道配置文件到内存块
	reload_chatroom();
}
private void reload_chatroom(){
	//聊天频道主索引内存
	chatIndex=([]);
	//聊天频道所有内容内存
	chatCont=([]);
	string strlists = "";
	strlists = Stdio.read_file(ROOT+FILE_PATH); 
	if(strlists&&sizeof(strlists)){
		array rooms = strlists/"\n";
		if(rooms&&sizeof(rooms)){
			foreach(rooms,string cont){
			//([聊天频道id:({聊天频道名字,主题(可以在作活动时候临时添加注明),房间类型(系统或者自建),其他(创建时间等等)})]);
			//example:  pub_channel|公共频道|寻人找物，紧急呼叫，公共频道，请慎言！|system|0
				if(cont&&sizeof(cont)){
					string r_index = (cont/"|")[0];
					string r_title = (cont/"|")[1];
					string r_desc = (cont/"|")[2];
					string r_type = (cont/"|")[3];
					string r_createtime = (cont/"|")[4];
					chatIndex[r_index]=({"","","",""});//聊天频道id，比如：pub_channel是公共频道
					chatIndex[r_index][0]=r_title;//聊天频道title:比如公共频道
					chatIndex[r_index][1]=r_desc;//聊天频道desc:聊天频道描述
					chatIndex[r_index][2]=r_type;//聊天频道type:聊天频道类型 如system为系统频道
					chatIndex[r_index][3]=r_createtime;//聊天频道建立时间：只有自建聊天频道才有此选择
					//初始化新聊天频道的聊天内存
					//array(string) chatTmp;
					//string strchat = " | \n";                                                                  
					//chatTmp = strchat/"|";
					chatCont[r_index] = ({" | \n",});//chatTmp;
				}
			}
		}
	}
	/*
	foreach(indices(chatIndex), string index){
		werror("   chatIndex[index]= "+index+"    \n");
	}
	*/
}
//返回聊天频道列表
string query_chatroom_list(){
	string rst = "";
	rst += "当前聊天频道列表：\n";
	if(chatIndex&&sizeof(chatIndex)){
		foreach(sort(indices(chatIndex)),string cid){
			if(cid&&sizeof(cid)){
				rst += "["+chatIndex[cid][0]+":chatroom_entry "+cid+"]\n";	
				rst += "("+chatIndex[cid][1]+")\n";
				rst += "--------\n";
			}
		}
	}
	else
		rst+="暂无聊天频道开放。\n";
	return rst;	
}
//返回某个频道,某个人看到的聊天信息
string query_chat_msg(string cid, string look_id){
	string rst = "";
	if(chatIndex&&sizeof(chatIndex)){
		if(chatIndex[cid][0]&&sizeof(chatIndex[cid][0]))
			rst += chatIndex[cid][0]+"\n";
	}
	else
		return rst += "该频道已经关闭,请返回。\n";
	object looker = find_player(look_id);
	if(!looker)
		return "聊天系统出现暂时性问题，请返回重试。\n";
	//mapping(string:array(string)) chatCont = ([]);
	//([聊天频道id,({聊天信息1,聊天信息2,聊天信息3,......(max=60)})])
	if(chatCont&&sizeof(chatCont)){
		array(string) tmp = ({});
		if(chatCont[cid]&&sizeof(chatCont[cid]))
			tmp = (array)chatCont[cid];
		mapping(int:string) chatrever = ([]);
		if(tmp&&sizeof(tmp)){
			tmp -= ({});
			int count = 0;
			foreach(tmp,string msg){
				int flag = 1;
				if(msg&&sizeof(msg)){
					//每天聊天信息的格式：[发言者id]|发言信息
					//werror("     msg="+msg+"\n");
					array(string) marr = msg/"|";
					if(marr&&sizeof(marr)){
						marr -= ({});
						//得到该条信息发言者的id
						string defendid = (string)marr[0];
						//werror("    屏蔽者="+defendid+"\n");
						//得到该条发言者应该显示出来的信息
						string contents = (string)marr[1];
						//werror("    屏蔽者发言="+contents+"\n");
						if(looker["/plus/chatblock"]&&sizeof(looker["/plus/chatblock"])){
							//看该信息的发言者id是否在观察者的屏蔽列表中
							foreach(looker["/plus/chatblock"],string who){
								if(who&&who==defendid)
									//如果发言者id在观察者屏蔽id列表中，则不显示该条信息
									flag = 0;
							}
						}
						if(flag){
							chatrever[count] = contents;
							count++;
						}
					}
				}
			}
			if(chatrever&&sizeof(chatrever)){
				foreach(reverse(sort(indices(chatrever))), int ind)
					rst += (string)chatrever[ind];	
			}
			if(rst&&sizeof(rst))
				;
			else
				rst += "暂时没有人发布信息。\n";
		}
	}
	else
		rst += "所有频道已经关闭。\n";
	return rst;
}
//聊天频道发布信息，成功返回1
int add_chat_msg(string tid, string msg){
	int flag = 1;
	if(tid&&sizeof(tid)&&msg&&sizeof(msg)){
		//mapping(string:array(string)) chatCont = ([]);
		//([聊天频道id,({聊天信息1,聊天信息2,聊天信息3,......(max=60)})])
		array tmparr;
		if(chatCont&&sizeof(chatCont))
			tmparr = (array)chatCont[tid];
		if(!tmparr){
			//加入每条聊天信息的格式：[发言者id]|发言信息
			//其中id将会在显示的时候屏蔽掉
			string str1 = "频道聊天信息\n"+"~"+msg+"\n";
			array a1 = str1/"~";
			chatCont[tid] = a1;
			flag = 1;
		}
		else{//聊天信息不为空，顺延并删除头信息
			if(sizeof(tmparr)<=15){
				string s1 = "";
				//小于15行，顺延加入聊天信息
				for(int i=0; i<sizeof(tmparr); i++)
					s1 += (string)tmparr[i]+"~";
				s1 += msg + "\n";
				array newarr = s1/"~";
				//更新聊天内存文件
				chatCont[tid] = newarr;
				flag = 1;
			}
			else{
				string s1 = "";
				//大于15行，去掉头信息，再顺延加入聊天信息至尾
				for(int i=1; i<sizeof(tmparr); i++)
					s1 += (string)tmparr[i]+"~";
				s1 += msg + "\n";
				array newarr = s1/"~";
				//更新聊天内存文件
				chatCont[tid] = newarr;
				flag = 1;
			}
		}
	}
	else
		flag = 0;
	return flag;
}
//公聊系统调用接口
string query_chatroom_msg(string cid, string look_id){
	string rst = "";
	/*
	if(chatIndex&&sizeof(chatIndex)){
		if(chatIndex[cid][0]&&sizeof(chatIndex[cid][0]))
			rst += chatIndex[cid][0]+"\n";
	}
	else
		return rst += "该频道已经关闭,请返回。\n";
	*/
	object looker = find_player(look_id);
	if(!looker)
		return "聊天系统出现暂时性问题，请返回重试。\n";
	//mapping(string:array(string)) chatCont = ([]);
	//([聊天频道id,({聊天信息1,聊天信息2,聊天信息3,......(max=60)})])
	if(chatCont&&sizeof(chatCont)){
		array(string) tmp = ({});
		if(chatCont[cid]&&sizeof(chatCont[cid]))
			tmp = (array)chatCont[cid];
		mapping(int:string) chatrever = ([]);
		if(sizeof(tmp)>0 && sizeof(tmp)<=3){
			tmp -= ({});
			int count = 0;
			foreach(tmp,string msg){
				int flag = 1;
				if(msg&&sizeof(msg)){
					//每天聊天信息的格式：[发言者id]|发言信息
					//werror("     msg="+msg+"\n");
					array(string) marr = msg/"|";
					if(marr&&sizeof(marr)){
						marr -= ({});
						//得到该条信息发言者的id
						string defendid = (string)marr[0];
						//werror("    屏蔽者="+defendid+"\n");
						//得到该条发言者应该显示出来的信息
						string contents = (string)marr[1];
						//werror("    屏蔽者发言="+contents+"\n");
						if(looker["/plus/chatblock"]&&sizeof(looker["/plus/chatblock"])){
							//看该信息的发言者id是否在观察者的屏蔽列表中
							foreach(looker["/plus/chatblock"],string who){
								if(who&&who==defendid)
									//如果发言者id在观察者屏蔽id列表中，则不显示该条信息
									flag = 0;
							}
						}
						if(flag){
							chatrever[count] = contents;
							count++;
						}
					}
				}
			}
		}
		else if(sizeof(tmp) >3){
			int end = sizeof(tmp);
			int count = 0;
			for(int i=end-3;i<end;i++){
				string msg = tmp[i];
				if(msg&&sizeof(msg)){
					int flag = 1;
					//每天聊天信息的格式：[发言者id]|发言信息
					//werror("     msg="+msg+"\n");
					array(string) marr = msg/"|";
					if(marr&&sizeof(marr)){
						marr -= ({});
						//得到该条信息发言者的id
						string defendid = (string)marr[0];
						//werror("    屏蔽者="+defendid+"\n");
						//得到该条发言者应该显示出来的信息
						string contents = (string)marr[1];
						//werror("    屏蔽者发言="+contents+"\n");
						if(looker["/plus/chatblock"]&&sizeof(looker["/plus/chatblock"])){
							//看该信息的发言者id是否在观察者的屏蔽列表中
							foreach(looker["/plus/chatblock"],string who){
								if(who&&who==defendid)
									//如果发言者id在观察者屏蔽id列表中，则不显示该条信息
									flag = 0;
							}
						}
						if(flag){
							chatrever[count] = contents;
							count++;
						}
					}
				}
			}
		}
		if(chatrever&&sizeof(chatrever)){
			foreach(reverse(sort(indices(chatrever))), int ind)
				rst += (string)chatrever[ind];	
		}
	}
	else
		rst += "所有频道已经关闭。\n";
	return rst;
}
