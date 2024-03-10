/**
 * �ṩ�����б���
 * ָ���ʽ blacklist <usrname> -<arg> <flag>
 * blacklist���Ӳ��������г���ǰ���������趨�������б�
 * argΪaddʱ��ʾ��ӣ�addΪdelʱ��ʾɾ��
 * flagΪ0ʱ��ʾ��ӵ���ʱ�����б�Ϊ1ʱ��ʾ��ӵ����������б�
 * ��ʱ�����б����߾���գ�����ֻ�����������죬���������б���������ͷ��ţ����������õ�
 */
#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name,flag,s,tmp;
	int sig;
	array list;
	object me = this_player();
	object ob;
	if(arg){
		if(sscanf(arg,"%s -%s %d",name,flag,sig)==3){
			if(!name){
				write("��Ҫ���ε��˲����ڡ�\n[������Ϸ:look]\n");
				return 1;
			}
			ob = find_player(name);
			if(ob){
				if(flag == "add"){
					if(!sig){
						if(!me["/tmp/blacklist/"+name])
							me["/tmp/blacklist/"+name]=ob->name_cn;
						s = ob->name_cn+"��������ʱ�����б��Է������ܸ��㷢��Ϣ����Ҫʱ���Ե������б�����������Ρ�\n";
					}
					else{
						if(!me["/plus/blacklist/"+name])
							me["/plus/blacklist/"+name]=ob->name_cn;
						s = ob->name_cn+"�������������б��������ò��ܷ���Ϣ(�������ʼ�)���㣬��Ҫʱ���Ե������б��б�����������Ρ�\n";
					}
				}
				if(flag == "del"){
					if(!sig){
						me->_m_delete("/tmp/blacklist/"+name);
						s = ob->name_cn+"�Ѿ�����ʱ�����б�ɾ�������Զ��������Ϣ��ͨ��\n";
					}
					else{
						me->_m_delete("/plus/blacklist/"+name);
						s = ob->name_cn+"�Ѿ������������б�ɾ�������Զ��������Ϣ��ͨ��\n";
					}
				}
			}
			else
				s = "�Է������ߣ����´���ִ�д˲�����\n";
		}
		if(sscanf(arg,"%d",sig)){
			if(sig){
				s = "���������б�\n";
				s+=query_forever_list(me)==""?"����������Ա\n":query_forever_list(me);
			}
			else{
				s = "��ʱ�����б�\n";
				s+=query_temp_list(me)==""?"����������Ա\n":query_temp_list(me);
			}
		}
	}
	else		
		s = "[��ʱ�����б�:blacklist 0]\n[���������б�:blacklist 1]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}

string query_temp_list(object me)
{
	string tmp,s="";
	array list;
	if(me["/tmp/blacklist"]){
		list = indices(me["/tmp/blacklist"]);		
		foreach(list,tmp){
			if(me["/tmp/blacklist/"+tmp])
				s +=me["/tmp/blacklist/"+tmp]+"[�����ʱ����:blacklist "+tmp+" -del 0] [�������������б�:blacklist "+tmp+" -add 1]\n";
		}
	}
	return s;	
}
string query_forever_list(object me)
{
	string tmp,s="";
	array list;
	if(me["/plus/blacklist"]){
		list = indices(me["/plus/blacklist"]);		
		foreach(list,tmp){
			if(me["/plus/blacklist/"+tmp])
				s +=me["/plus/blacklist/"+tmp]+"[�����������:blacklist "+tmp+" -del 1]\n";
		}
	}
	return s;
} 
