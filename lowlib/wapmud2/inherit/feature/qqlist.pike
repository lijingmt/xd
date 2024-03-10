#include <wapmud2/include/wapmud2.h>
array(array) qqlist=({});//({name,name_cn,group})ÿ�����ѵ���Ϣ��id,����,����
mapping(string:string) groupList=([]);//���з�����Ϣ
#define NAME 0
#define NAME_CN 1
#define GROUP 2
string view_user_list(){
	string data="";
	array list;
	int j;
	int count = sizeof(users());
	//data+="�����û� "+count+" \n";
	for (list = users(1), j = 0; j < sizeof(list); j++) {
		catch{
			string gender=list[j]->query_gender();
			string idle="";
			if(list[j]->query_idle()/60>3)
				idle="<����"+list[j]->query_idle()/60+"����>";
			string postions="";
			object env = environment(list[j]);
			postions = (string)env->query_name_cn();
			if(list[j]->query_raceId()==this_object()->query_raceId())
				data+=(string)list[j]->query_name_cn()+"("+list[j]->query_profe_cn(list[j]->query_profeId())+")"+" "+gender+" "+idle+" *"+postions+" [��Ϊ����:qqlist "+(string)list[j]->query_name()+"] [����Ϣ:tell "+(string)list[j]->query_name()+"]\n";
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
			//�������г��ֹ�����û�
			if(ob){
				if(qqlist[i][GROUP]&&sizeof(qqlist[i][GROUP]))
					;
				else{
					qqlist[i][NAME_CN]=ob->name_cn;
					online_data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"]  [ɾ��:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
				}
			}
			else{
				if(qqlist[i][GROUP]&&sizeof(qqlist[i][GROUP]))
					;
				else
					data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"](����)  [ɾ��:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
			}
		}
	}
	string tmp = online_data+data;
	if(tmp != ""){
		tmp +=  "\n[ɾ���������к���:qqlist_delete_other_user]\n";
	}
	else {
		tmp = "���������޷������";
	}
	return tmp;
}
//�����û�ת�Ƶ�һ��������
string qqlist_group_insert(string name,string group)
{
	if(groupList==0)
		groupList=([]);
	if(qqlist==0)
		qqlist=({});
	if(!group||group=="")
		return "��������Ϊ�գ��뷵�����裡";
	if(qqlist&&sizeof(qqlist)){
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][NAME]==name){
				foreach(indices(groupList),string index){
					if(group==index){
						qqlist[i][GROUP]=group;
						return "���óɹ����뷵�أ�";
					}
				}
			}
		}
	}
	return "δ�ҵ��÷��飬����ʧ�ܣ��뷵�����ԣ�";
}
string view_qqlist_groups()
{
	//������ĸ����г�����
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
					online_data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"]  [ɾ��:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
				}
				else{
					data+="["+qqlist[i][NAME_CN]+":qqlist_user "+qqlist[i][NAME]+"](����)  [ɾ��:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
				}
			}
		}
	}
	string tmp = online_data+data;
	if(tmp != ""){
		tmp +=  "\n[ɾ���������к���:qqlist_delete_group_user "+group+"]\n";
	}
	else {
		tmp = "���������޷������";
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
			return "���޿ɷ���ѡ�����ȴ���һ������\n[��������:qqlist_group_create]\n";
	}
	return "���޿ɷ���ѡ�����ȴ���һ������\n[��������:qqlist_group_create]\n";
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
				data+="[ɾ������:qqlist_group_delete "+index+"]\n";
		}
		data = "[��������:qqlist_group_create]\n" + data;
		if(data&&sizeof(data)){
			return data;
		}
		else{
			return data+="���޿ɷ���ѡ�����ȴ���һ������\n";
		}
	}
	else{
		if(groupList[arg]==0)
			return "�������޿ɹ�ѡ��ĺ��ѣ��뷵�ز�ѡ����ӻ�ת�ƺ��ѵ����顣\n";
		for(int i=0;i<sizeof(qqlist);i++){
			if(qqlist[i][GROUP]==arg){
				object ob=find_player(qqlist[i][NAME]);
				if(ob)
					qqlist[i][NAME_CN]=ob->name_cn;
				data+="["+qqlist[i][NAME_CN]+":qqlist_admin "+qqlist[i][NAME]+"] [ɾ������:qqlist_delete_user "+qqlist[i][NAME]+"]\n";
			}
		}
		if(data&&sizeof(data)){
			return data;
		}
		else{
			data += "�������޿ɹ�ѡ��ĺ��ѣ��뷵�ز�ѡ����ӻ�ת�ƺ��ѵ����顣\n";
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
		return 0;//��������Ϊ�Ƿ��ַ�
	}
	if(gname){
		foreach(indices(groupList),string index){
			if(groupList[index]&&sizeof(groupList[index])){
				if(groupList[index]==gname)
					flag = 0;//����������ظ�
			}
		}
		if(flag){
			//����һ������
			string tmp = "";
			tmp += sizeof(groupList)+1;
			groupList[tmp] = gname;
		}
		else
			return 2;//��������������Ѿ�����
	}
	return 1;//�ɹ���������
}
int qqlist_update(string name,string group)
{
	if(groupList==0)
		groupList=([]);
	int flag=1;
	if(!group||group==""){
		return 0;//��������Ϊ�Ƿ��ַ�
	}
	if(group){
		foreach(indices(groupList),string index){
			if(groupList[index]&&sizeof(groupList[index])){
				if(groupList[index]==group)
					flag = 0;//����������ظ�
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
			return 2;//��������������Ѿ�����
	}
	return 1;//�ɹ���������
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
		qqlist[-1][NAME_CN]=ob->name_cn;//����Ϊʲô�����
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
					//ɾ��������ڸ�����û��ֶ��ÿ�
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
					//ɾ��������ڸ�����û��ֶ��ÿ�
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
		//ɾ��δ������ĺ���
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
