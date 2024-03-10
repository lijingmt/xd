#include <wapmud2/include/wapmud2.h>
array(array) qqlist=({});//({name,name_cn,group})每个好友的信息：id,名字,组名
mapping(string:string) groupList=([]);//所有分组信息
#define NAME 0
#define NAME_CN 1
#define GROUP 2
string view_user_list(){
	string data="";
	array list;
	int j;
	int count = sizeof(users());
	//data+="在线用户 "+count+" \n";
	for (list = users(1), j = 0; j < sizeof(list); j++) {
		catch{
			string gender=list[j]->query_gender();
			string idle="";
			if(list[j]->query_idle()/60>3)
				idle="<发呆"+list[j]->query_idle()/60+"分钟>";
			string postions="";
			object env = environment(list[j]);
			postions = (string)env->query_name_cn();
			if(list[j]->query_raceId()==this_object()->query_raceId())
				data+=(string)list[j]->query_name_cn()+"("+list[j]->query_profe_cn(list[j]->query_profeId())+")"+" "+gender+" "+idle+" *"+postions+" [加为好友:qqlist "+(string)list[j]->query_name()+"] [发消息:tell "+(string)list[j]->query_name()+"]\n";
		};
	}
	return data;
}
string view_qqlist()
{
	string data="";
	string online_data="";
	if(qqlist==0)
		qqlist=({});
	if(qqlist&&sizeof(qqlist)){
		for(int i=0;i<sizeof(qqlist);i++){
			object ob=find_player(qqlist[i][NAME]);
			//将不会列出分过组的用户
			if(ob){
				if(qqlist[i][GROUP]&&sizeof(qqlist[i][GROUP]))
					;
				else{
					qqlist[i][NAME_CN]=ob->name_cn;
					online_data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"]  [删除:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
				}
			}
			else{
				if(qqlist[i][GROUP]&&sizeof(qqlist[i][GROUP]))
					;
				else
					data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"](离线)  [删除:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
			}
		}
	}
	string tmp = online_data+data;
	if(tmp != ""){
		tmp +=  "\n[删除改组所有好友:qqlist_delete_other_user]\n";
	}
	else {
		tmp = "该组内暂无分配好友";
	}
	return tmp;
}
//将该用户转移到一个分组中
string qqlist_group_insert(string name,string group)
{
	if(groupList==0)
		groupList=([]);
	if(qqlist==0)
		qqlist=({});
	if(!group||group=="")
		return "组名不能为空，请返回重设！";
	if(qqlist&&sizeof(qqlist)){
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][NAME]==name){
				foreach(indices(groupList),string index){
					if(group==index){
						qqlist[i][GROUP]=group;
						return "设置成功，请返回！";
					}
				}
			}
		}
	}
	return "未找到该分组，设置失败，请返回重试！";
}
string view_qqlist_groups()
{
	//按照组的个数列出连接
	string data="";
	if(groupList==0)
		groupList=([]);
	foreach(indices(groupList),string index){
		if(index&&groupList[index]){
			data+="["+groupList[index]+":qqlist_group "+index+"]\n";
		}
	}
	return data;
}
string view_qqlist_group(string group)
{
	string data="";
	string online_data="";
	if(qqlist){
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][GROUP]==group){
				object ob=find_player(qqlist[i][NAME]);
				if(ob){
					qqlist[i][NAME_CN]=ob->name_cn;
					online_data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"]  [删除:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
				}
				else{
					data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"](离线)  [删除:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
				}
			}
		}
	}
	string tmp = online_data+data;
	if(tmp != ""){
		tmp +=  "\n[删除该组所有好友:qqlist_delete_group_user "+group+"]\n";
	}
	else {
		tmp = "该组内暂无分配好友";
	}
	return tmp;
}
string view_qqlist_move(string user)
{
	if(groupList==0)
		groupList=([]);
	string data="";
	if(qqlist&&sizeof(qqlist)){
		foreach(indices(groupList),string index){
			if(groupList[index]!=0)
				data+="["+groupList[index]+":qqlist_move "+user+" "+index+"]\n";
		}
		if(data&&sizeof(data))
			return data;
		else
			return "暂无可分组选择，请先创建一个新组\n[创建新组:qqlist_group_create]\n";
	}
	return "暂无可分组选择，请先创建一个新组\n[创建新组:qqlist_group_create]\n";
}
string view_qqlist_admin_groups(string arg)
{
	if(groupList==0)
		groupList=([]);
	string data="";
	if(arg==0){
		foreach(indices(groupList),string index){
			if(groupList[index]!=0)
				data+="["+groupList[index]+":qqlist_admin_groups "+index+"] ";
				data+="[删除该组:qqlist_group_delete "+index+"]\n";
		}
		data = "[创建新组:qqlist_group_create]\n" + data;
		if(data&&sizeof(data)){
			return data;
		}
		else{
			return data+="暂无可分组选择，请先创建一个新组\n";
		}
	}
	else{
		if(groupList[arg]==0)
			return "本组暂无可供选择的好友，请返回并选择添加或转移好友到该组。\n";
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][GROUP]==arg){
				object ob=find_player(qqlist[i][NAME]);
				if(ob)
					qqlist[i][NAME_CN]=ob->name_cn;
				data+="["+qqlist[i][NAME_CN]+":qqlist_admin "+qqlist[i][NAME]+"] [删除好友:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
			}
		}
		if(data&&sizeof(data)){
			return data;
		}
		else{
			data += "本组暂无可供选择的好友，请返回并选择添加或转移好友到该组。\n";
			return data;
		}
	}
}
int qqlist_group_create(string gname)
{
	if(groupList==0)
		groupList=([]);
	int flag=1;
	if(!gname||gname==""){
		return 0;//输入组名为非法字符
	}
	if(gname){
		foreach(indices(groupList),string index){
			if(groupList[index]&&sizeof(groupList[index])){
				if(groupList[index]==gname)
					flag = 0;//输入的组名重复
			}
		}
		if(flag){
			//增加一个新组
			string tmp = "";
			tmp += sizeof(groupList)+1;
			groupList[tmp] = gname;
		}
		else
			return 2;//创建新组的组名已经存在
	}
	return 1;//成功创建新组
}
int qqlist_update(string name,string group)
{
	if(groupList==0)
		groupList=([]);
	int flag=1;
	if(!group||group==""){
		return 0;//输入组名为非法字符
	}
	if(group){
		foreach(indices(groupList),string index){
			if(groupList[index]&&sizeof(groupList[index])){
				if(groupList[index]==group)
					flag = 0;//输入的组名重复
			}
		}
		if(flag){
			string tmp = "";
			tmp += sizeof(groupList)+1;
			groupList[tmp] = group;
			for(int i=0;i<sizeof(qqlist);i++){
				if(qqlist[i][NAME]==name)	
					qqlist[i][GROUP] = group;
			}
		}
		else
			return 2;//创建新组的组名已经存在
	}
	return 1;//成功创建新组
}
void qqlist_insert(string name,string group)
{
	if(qqlist==0)
		qqlist=({});
	for(int i=0;i<sizeof(qqlist);i++){
		if(qqlist[i][NAME]==name){
			object ob=find_player(name);
			if(ob){
				qqlist[i][NAME_CN]=ob->name_cn;
			}
			if(group)
				qqlist[i][GROUP]=group;
			return;
		}
	}
	qqlist+=({({name,0,group})});
	object ob=find_player(name);
	if(ob){
		qqlist[-1][NAME_CN]=ob->name_cn;//这里为什么？奇怪
	}
}
void qqlist_delete(string name)
{
	if(qqlist==0)
		qqlist=({});
	array temp=({});
	for(int i=0;i<sizeof(qqlist);i++){
		if(qqlist[i][NAME]==name){
			continue;
		}
		temp+=({qqlist[i]});
	}
	qqlist=temp;
}
int qqlist_group_delete(string gname)
{
	if(qqlist==0)
		qqlist=({});
	if(groupList==0)
		groupList=([]);
	if(gname){
		foreach(indices(groupList),string index){
			if(index&&groupList[index]){
				if(gname==index){
					//删除组后，属于该组的用户字段置空
					for(int i=0;i<sizeof(qqlist);i++){
						if(qqlist[i][GROUP]==gname){
							qqlist[i][GROUP] = 0;
						}
					}
					m_delete(groupList,gname);
					return 1;
				}
			}
		}
	}
	return 0;
}
int qqlist_delete_group_user(string gname)
{
	if(qqlist==0)
		qqlist=({});
	if(groupList==0)
		groupList=([]);
	if(gname){
		foreach(indices(groupList),string index){
			if(index&&groupList[index]){
				if(gname==index){
					//删除组后，属于该组的用户字段置空
					for(int i=0;i<sizeof(qqlist);i++){
						if(qqlist[i][GROUP]==gname){
							qqlist -= ({qqlist[i]});
						}
					}
					return 1;
				}
			}
		}
	}
	return 0;
}
int qqlist_delete_other_user()
{
	if(qqlist==0)
		qqlist=({});
	else{
		array temp = ({});
		//删除未分组里的好友
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][GROUP]&&sizeof(qqlist[i][GROUP])){
				temp += ({qqlist[i]});
			}
		}
		qqlist = temp;
		return 1;
	}
	return 0;
}
