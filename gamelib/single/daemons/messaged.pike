/*
   公告系统，用于管理员在游戏中管理公告等功能的实现
   
   @author caijie
   2008/07/16

  【数据结构】
   mapping(int:array(string)) all_msg
   所有公告按发布时间顺序插入到该映射表中，其结构为
   index:({					表的索引（即公告发布时间(秒)，主要是为了容易比较大小）
   	    a[0]=1			       【类别】：目前只有"公告"这一个模块，为扩展起见预留该字段
	    a[1]=Fri Jul 18 14:39:31 2008       公告发布时间
	    a[2]=xd1				游戏区
	    a[3]=caijie				发布人帐号
	    a[4]=无名道童			发布人中文名字
	    a[5]=7月8日更新公告			公告标题
	    a[6]=公告正文			公告内容
	    a[7]=2008-07-18 15:16:34		修改公告时间
   })

  【方法说明】
   load_msg():更新该文件时执行，主要是把要显示的公告插入表中，以方便查阅或修改公告操作
   write_file():将要在页面上显示的公告写入到msg.list中，每个 WRITE_TIME 执行一次，当该方法被执行时msg.list文件将被重写
   get_new_msg():读取最新公告，当玩家点击游戏公告时将调用该方法
   get_new_msg():读取历史公告
   msg_rewrite():把修改后新的公告内容覆盖原来的公告内容，但是索引不变
   msg_del():把与id相对应的公告从映射表all_msg中删除
   msg_send():将公告插入到映all_msg射表中
   
  【实现逻辑】
   all_msg 存储要显示的公告信息，所有操作都会对该表进行处理，write_file()记录该表的最新内容,当重启后重新把内容写入表中，这样可以避免重启后内存中的公共内容丢失的情况
*/
#include <globals.h>
#include <gamelib/include/gamelib.h>
//#define BC_MSG_FILE_PATH DATA_ROOT "message/"//日志文件目录
#define MSG_LIST DATA_ROOT "msg.list"	//存储将要在页面上显示的公告信息文件,存储格式：发布时间|游戏区|帐号|中文名|公告标题|公告内容
#define MSG_FILE ROOT "/log/msg.log"	//记录发布公告信息及修改公告休息，内容包括发布人帐号、名字，发布时间、公告标题及内容
//#define WRITE_TIME 3600*24		//把内存中的信息保存的时间间隔,可根据情况修改
inherit LOW_DAEMON;
private mapping(int:array(string)) all_msg = ([]);          //存储公告信息


void create()
{
	load_msg();
	write_file();
}


//把要显示的公告读取到内存当中
void load_msg()
{
	all_msg = ([]);
	string msgData = Stdio.read_file(MSG_LIST);
	array(string) lines = msgData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array(string) columns = eachline/"|";
			array(string) msg_tmp = ({});
			if(sizeof(columns)==6){
				msg_tmp += ({"1"});					//msg_tmp[0]类别
				//从文件读取的信息:发布时间[1]、游戏区[2]、帐号[3]、中文名[4]、公告标题[5]、公告内容[6]
				msg_tmp += columns;
				msg_tmp += ({0});					//msg_tmp[7]修改时间
				if(all_msg[(int)columns[0]]==0){
					all_msg[(int)columns[0]] = msg_tmp;
				}
			}
			else 
				werror("------size of columns wrong in load_msg() of messaged.pike------\n");
		}
	}
	else 
		 werror("------read file wrong in load_msg() of messaged.pike------\n");
}

//把内存中的公告信息写入到msg.list文件中
void write_file()
{
	string s = "";
	if(all_msg && sizeof(all_msg)){
		int count = sizeof(all_msg);
		if(count){
			array(int) tmp = sort(indices(all_msg));
			for(int j=0;j<count;j++){
				int i = tmp[j];
				array(string) msg = all_msg[i];
				s += msg[1]+"|"+msg[2]+"|"+msg[3]+"|"+msg[4]+"|"+msg[5]+"|"+msg[6]+"\r\n";
			}
		}
	}
	Stdio.write_file(MSG_LIST,s);
	//call_out(write_file,WRITE_TIME);   //每隔 WRITE_TIME 秒调用一次
}

/*
方法描述：从内存中获取最新公告信息

返回值：返回公告标题及内容
*/
string get_new_msg()
{
	int msg_count = sizeof(all_msg);
	string s = "";
	if(msg_count>0){
		int id = sort(indices(all_msg))[msg_count-1];
		s += all_msg[id][5]+":\n"+all_msg[id][6]+"\n";//读取标题和内容
	}
	//werror("----msg_count="+msg_count+"---head"+all_msg[msg_count][5]+"----text="+all_msg[msg_count][6]+"----\n");
	return s;
}


/*
方法描述:查看历史公告,时间最新的排在前面
变量:is_admin 判断是否是管理员，若是管理员则有修改和删除的权限，否则只有阅读权限
     void 列出历史公告标题链接
     id 表示读取第几条公告

返回值:void 返回历史公告标题链接
	id  返回该id指向的公告标题和内容
*/
string get_old_msg(string is_admin,void|int id)
{
	int msg_count = sizeof(all_msg);
	string s = "";

	if(msg_count<=0){
		s += "目前没有历史公告。\n";
		return s;
	}
	if(!id){
		array(int) m_id = sort(indices(all_msg));//按索引从小到大排列
		//信息按发布时间降序排列
		for(int j=msg_count-1;j>=0;j--){
			int i = m_id[j];
			array(string) tmp = all_msg[i];
			if(is_admin=="admin"){
				s += "["+tmp[5]+":msg_read "+i+"] [修改:msg_write_entry "+i+"] [删除:msg_del "+i+"]\n";
			}
			else{
				s += "["+tmp[5]+":msg_read "+i+"]\n";
			}
		}
	}
	else {
		s += all_msg[id][5]+":\n"+all_msg[id][6]+"\n";
	}
	return s;
}

/*
方法描述：修改公告接口，当公告被修改后mapping表中对应该旧公告会被新公告覆盖
变量：msg 新修改的公告信息结构为 msg[0]:游戏区号
                                 msg[1]:管理员帐号
                                 msg[2]:管理员中文姓名
                         	 msg[3]:公告标题
			         msg[4]:公告内容
      id 原公告在mapping表中的存放id
返回值：2 公告不存在
	1 修改成功
	0 修改失败
*/
int msg_rewrite(array msg,int id)
{
	string s_log = "";
	if(all_msg[id] && sizeof(all_msg[id])){
		if(sizeof(msg)==5){
			array(string) msg_tmp = ({});
			int msg_count = sizeof(all_msg);
			msg_tmp += ({"1"});					//msg_tmp[0]类别
			msg_tmp += ({all_msg[id][1]});	//msg_tmp[1]发布时间
			msg_tmp += msg;			//游戏区号，发布公告人帐号，发布公告人中文姓名，公告标题及公告内容
			msg_tmp += ({MUD_TIMESD->get_mysql_timedesc()});	//msg_tmp[7]修改时间
			if(sizeof(msg_tmp)==8){
				all_msg[id] = msg_tmp;
				s_log += msg[0]+"|"+msg[1]+"|"+msg[2]+"|"+"修改"+ctime((int)msg_tmp[1])+"发布的公告为：| 标题："+msg[3]+"| 内容:"+msg[4]+"\n";
				Stdio.append_file(MSG_FILE,MUD_TIMESD->get_mysql_timedesc()+":"+s_log);//将信息写入日志。
				return 1;
			}
		}
		return 0;
	}
	return 2;
}

/*
方法描述：删除公告接口
变量：id 该公告在表中的存储位置
返回值：1 删除成功
	0 该公告不存在
*/
int msg_del(int id)
{
	object me = this_player();
	string s_log = "";
	if(all_msg[id] && sizeof(all_msg[id])){
		string title = all_msg[id][5];//公告标题，用于打log
		int time = (int)all_msg[id][1];//发布时间，用于打log
		m_delete(all_msg,id);
		s_log = "("+me->query_name()+")"+me->query_name_cn()+"删除"+ctime(time)+"发布的公告，其标题为:"+title+"\n";
		Stdio.append_file(MSG_FILE,MUD_TIMESD->get_mysql_timedesc()+":"+s_log);//将信息写入日志。
		return 1;
	}
	return 0;
}

/*
方法描述：将最新公告插入到映射表中
变量：msg 需要显示的信息,结构为 msg[0]:游戏区号
                                msg[1]:管理员帐号
				msg[2]:管理员中文姓名
				msg[3]:公告标题
				msg[4]:公告内容
返回值：0 插入失败  
	1 插入成功
*/

int msg_send(array(string) msg)
{
	string s_log = "";
	if(sizeof(msg)==5){
		array(string) msg_tmp = ({});
		int msg_count = sizeof(all_msg);
		msg_tmp += ({"1"});					//msg_tmp[0]类别
		msg_tmp += ({time()});	//msg_tmp[1]发布时间
		msg_tmp += msg;
		msg_tmp += ({0});
		if(sizeof(msg_tmp)==8){
			all_msg[time()] = msg_tmp;
			//all_msg[msg_count+1] = msg_tmp;
			s_log += msg[0]+"|"+msg[1]+"|"+msg[2]+"|"+"发布的公告：| 标题："+msg[3]+"| 内容:"+msg[4]+"\n";
			Stdio.append_file(MSG_FILE,MUD_TIMESD->get_mysql_timedesc()+":"+s_log);//将信息写入日志。
			return 1;
		}
	}
	else 
		return 0;
}

