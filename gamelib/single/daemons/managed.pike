#include <globals.h>
#include <gamelib/include/gamelib.h>

inherit LOW_DAEMON;

#define SAVE_MANAGER 600 //10���ӻ�д�浵һ��
#define MAX_BANG 5000 //����500000�� 
#define LOGIN_PATH ROOT+"/gamelib/etc/unlogin_id"//�������
#define CHAT_PATH ROOT+"/gamelib/etc/unchat_id"//��ֹ��������
#define MANAGER_PATH ROOT+"/gamelib/etc/mananer_id"//����Աid����

mapping(string:string) manager_mem = ([]);//����Ա�б�([id:Ȩ��]) Ȩ���趨:admin,assist,
mapping(string:array) unlogin_mem = ([]);//����б�([id:({�������������ʼʱ�䣬������ޣ�})])
mapping(string:array) unchat_mem = ([]);//�����б�([id:({��������������ʼʱ�䣬�������ޣ�})])


//��ȡʱ������
string get_log_name(int type){ 
	string s_mon,s_day;
	string s_hour,s_min,s_sec;
	int day,mon,year,hour,min,sec;
	mapping now_time = localtime(time());
	day = now_time["mday"];	
	mon = now_time["mon"]+1;
	year = now_time["year"]+1900;
	hour = now_time["hour"];
	min = now_time["min"];
	sec = now_time["sec"];
	if(mon<10) s_mon = "0"+mon;
	else s_mon = (string)mon;
	if(day<10) s_day = "0"+day;
	else s_day = (string)day;
	if(hour<10) s_hour = "0"+hour;
	else s_hour = (string)hour;
	if(min<10) s_min = "0"+min;
	else s_min = (string)min;
	if(sec<10) s_sec = "0"+sec;
	else s_sec = (string)sec;
	string log_file = ""+year+"-"+s_mon+"-"+s_day;
	string log_time = ""+year+"-"+s_mon+"-"+s_day+" "+s_hour+":"+s_min+":"+s_sec;
	if(type ==1)
		return log_file;//[2010-09-19]
	else
		return log_time;//[2010-09-19 19:29:12]
}

//�ڴ��ļ���д�����ļ�
void rewritefile()
{
	string tmp = "";
	//��д�ڴ��з����ҵ�id���ļ���
	if(unlogin_mem&&sizeof(unlogin_mem))
	{
		foreach(sort(indices(unlogin_mem)),string id)
		{
			array arr1 = (array)unlogin_mem[id];	
			if(arr1&&sizeof(arr1))
			{
				string s1 = "";
				s1 += id + ",";//����û�id
				s1 += arr1[0]+",";//����û�id
				s1 += arr1[1]+",";//����û�������
				s1 += arr1[2]+",";//�����ʼʱ��
				s1 += arr1[3]+",";//�������
				s1 += arr1[4]+",";//�����ʼʱ������
				tmp += s1 + "\n";
			}
		}
		if(tmp&&sizeof(tmp))
			Stdio.write_file(LOGIN_PATH,tmp);
	}
	//��д�ڴ��н�����ҵ�id���ļ���
	string tmp2 = "";
	if(unchat_mem&&sizeof(unchat_mem))
	{
		foreach(sort(indices(unchat_mem)),string id)
		{
			array arr1 = (array)unchat_mem[id];	
			if(arr1&&sizeof(arr1))
			{
				string s1 = "";
				s1 += id + ",";//�����û�id
				s1 += arr1[0]+",";//�����û�id
				s1 += arr1[1]+",";//�����û�������
				s1 += arr1[2]+",";//������ʼʱ��
				s1 += arr1[3]+",";//��������
				s1 += arr1[4]+",";//������ʼʱ������
				tmp2 += s1 + "\n";
			}
		}
		if(tmp&&sizeof(tmp))
			Stdio.write_file(CHAT_PATH,tmp);
	}
	call_out(rewritefile,SAVE_MANAGER);
}
void create()
{
	//��ʼ�����������ҵ���Ϣװ���ڴ��ļ�
	string unlogin_str = Stdio.read_file(LOGIN_PATH);
	//��ʼ�����������ҵ���Ϣװ���ڴ��ļ�
	string unchat_str = Stdio.read_file(CHAT_PATH);
	//��ʼ�����������ҵ���Ϣװ���ڴ��ļ�
	string manager_str = Stdio.read_file(MANAGER_PATH);

	//����������
	if(unlogin_str&&sizeof(unlogin_str)){
		array arrtmp = unlogin_str/"\n";
		if(arrtmp&&sizeof(arrtmp)){
			arrtmp -= ({""});
			foreach(arrtmp,string eachline){
				array splist = eachline/",";//id,��ʼʱ�䣬��������
				splist -= ({""});
				array pt = ({});
				pt += ({splist[1]});//id
				pt += ({splist[2]});//������
				pt += ({splist[3]});//��ʼʱ��
				pt += ({splist[4]});//��������
				pt += ({splist[5]});//��ʼʱ������
				unlogin_mem[(string)splist[0]] = pt;		
			}
		}
	}
	//�����������
	if(unchat_str&&sizeof(unchat_str)){
		array arrtmp = unchat_str/"\n";
		if(arrtmp&&sizeof(arrtmp)){
			arrtmp -= ({""});
			foreach(arrtmp,string eachline){
				array splist = eachline/",";//id,��ʼʱ�䣬��������
				splist -= ({""});
				array pt = ({});
				pt += ({splist[1]});//id
				pt += ({splist[2]});//������
				pt += ({splist[3]});//��ʼʱ��
				pt += ({splist[4]});//��������
				pt += ({splist[5]});//��ʼʱ������
				unchat_mem[(string)splist[0]] = pt;		
			}
		}
	}
	//�������Ա����
	if(manager_str&&sizeof(manager_str)){
		array arrtmp = manager_str/"\n";
		if(arrtmp&&sizeof(arrtmp)){
			arrtmp -= ({""});
			foreach(arrtmp,string eachline){
				array splist = eachline/",";//id,����Ȩ��--admin,assist
				splist -= ({""});
				manager_mem[(string)splist[0]] = (string)splist[1];		
			}
		}
	}
	call_out(rewritefile,SAVE_MANAGER);
}
//��ĳ���û����˺�״̬�������
string free_user_chat(string mid,string userid){
	string s = "";
	if(checkpower(mid)=="admin"){
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string id)
			{
				if(userid==id){
					array arr1 = (array)unchat_mem[id];	
					if(arr1&&sizeof(arr1))
					{
						string s1 = "";
						s1 += id + "|";//����û�id
						s1 += arr1[1]+"|";//����û�������
						s1 += "����ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
						int unlogTime = (int)arr1[3];
						s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
						//���ʣ��ʱ��
						int now_diff = time()-(int)arr1[2];//ʱ���
						int last_time = unlogTime - now_diff; 
						s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
						s1 += "\n-----------------------\n";
						s += s1 + "���ѳɹ��������״̬���뷵��\n";
						m_delete(unchat_mem,id);
						break;
					}
				}
			}
		}
		else{
			s += "δ�ҵ��ý�����ң��뷵��ȷ�ϡ�\n";
		}
	}
	else
	//if(checkpower(userid)=="assist")
		s += "��û����ӦȨ�޽��н�����Բ���\n";
	return s; 
}
//��ĳ���û����˺�״̬������
string free_user_login(string mid,string userid){
	string s = "";
	if(checkpower(mid)=="admin"){
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string id)
			{
				if(userid==id){
					array arr1 = (array)unlogin_mem[id];	
					if(arr1&&sizeof(arr1))
					{
						string s1 = "";
						s1 += id + "|";//����û�id
						s1 += arr1[1]+"|";//����û�������
						s1 += "���ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
						int unlogTime = (int)arr1[3];
						s1 += "������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
						//���ʣ��ʱ��
						int now_diff = time()-(int)arr1[2];//ʱ���
						int last_time = unlogTime - now_diff; 
						s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
						s1 += "\n-----------------------\n";
						s += s1 + "���ѳɹ�������״̬���뷵��\n";
						m_delete(unlogin_mem,id);
						break;
					}
				}
			}
		}
		else{
			s += "δ�ҵ��÷����ң��뷵��ȷ�ϡ�\n";
		}
	}
	else
	//if(checkpower(userid)=="assist")
		s += "��û����ӦȨ�޽��н����Ų���\n";
	return s; 
}
//��ѯ���û�id�Ƿ��ڽ����б��У������ؽ���״̬����
string query_unchat_desc(string userid){
	string rtn = "";
	if(unchat_mem&&sizeof(unchat_mem)){
		foreach(sort(indices(unchat_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "���Ѿ�������Ա����\n";
					s1 += "����ʱ�䣺"+arr1[4]+"\n";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"\n"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					rtn += s1 + "\n";
				}
			}
		}
	}
	return rtn;
}
//��ѯ���û�id�Ƿ��ڷ���б��У������ط��״̬����
string query_unlogin_desc(string userid){
	string rtn = "";
	if(unlogin_mem&&sizeof(unlogin_mem)){
		foreach(sort(indices(unlogin_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "���Ѿ�������Ա���\n";
					s1 += "���ʱ�䣺"+arr1[4]+"\n";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"\n"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					rtn += s1 + "\n";
				}
			}
		}
	}
	return rtn;
}
string query_user_deal_status(string mid,string userid){
	string s = "";
	if(unchat_mem&&sizeof(unchat_mem)){
		foreach(sort(indices(unchat_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//����û�id
					s1 += arr1[1]+"|";//����û�������
					s1 += "����ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					if(checkpower(mid)=="admin")
						s1 += "|[�������:game_deal free_chat "+id+" not not]";
					s += s1 + "\n";
				}
			}
		}
	}
	if(unlogin_mem&&sizeof(unlogin_mem)){
		foreach(sort(indices(unlogin_mem)),string id)
		{
			if(userid==id){
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//����û�id
					s1 += arr1[1]+"|";//����û�������
					s1 += "���ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					if(checkpower(mid)=="admin")
						s1 += "|[������:game_deal free_login "+id+" not not]";
					s += s1 + "\n";
				}
			}
		}
	}
	return s;
}
//������ԱȨ��
//����adminΪȨ����߹���Ա��assistΪ��������Ա��ֻ�����Ӳ��������ܽ��
string checkpower(string userid) 
{
	if(manager_mem&&sizeof(manager_mem))
	{
		foreach(sort(indices(manager_mem)),string id)
		{
			if(userid==id){
				string power = (string)manager_mem[id];	
				if(power&&sizeof(power))
					return power;
			}
		}
	}
	return "nopower";
}
//�г����������б�δ����ҳ����
string list_nochat_user(string userid){
	string s = "";
	if(checkpower(userid)=="admin"){
		//����ԱȨ�ޣ��г��û�ͬʱ���г��������
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string id)
			{
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//����û�id
					s1 += arr1[1]+"|";//����û�������
					s1 += "����ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					s1 += "|[�������:game_deal free_chat "+id+" not not]";
					s += s1 + "\n";
				}
			}
		}
		else{
			s += "���޽�����Ա\n";
		}
	}
	else if(checkpower(userid)=="assist"){
		//��������ԱȨ�ޣ�ֻ�г��û������ܽ��	
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string id)
			{
				array arr1 = (array)unchat_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//����û�id
					s1 += arr1[1]+"|";//����û�������
					s1 += "����ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					s += s1 + "\n";
				}
			}
		}
		else{
			s += "���޽�����Ա\n";
		}
	}
	else
		s += "��û����ӦȨ�޽��в鿴�͹������\n";
	return s; 
}

//���ӽ�����Ա,id,����������������
string add_unchat(string mid,string userid,string usernamecn,int limit_time){
	string rtn = "";
	if(checkpower(mid)=="admin"||checkpower(mid)=="assist"){
		string timedesc = get_log_name(2);//������ʼʱ������
		//�������ڴ棬������£��ޣ������
		if(unchat_mem&&sizeof(unchat_mem)){
			foreach(sort(indices(unchat_mem)),string index){
				if(index&&sizeof(index)){
					if(index==userid){
						rtn += "�ý����û�����ʱ���ѱ��ɹ�����\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unchat_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//����û�id
						s1 += usernamecn+"|";//����û�������
						s1 += "����ʱ�䣺"+timedesc+"|";//�����ʼʱ������
						s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
					else{
						rtn += "�ѳɹ������û������������\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unchat_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//����û�id
						s1 += usernamecn+"|";//����û�������
						s1 += "����ʱ�䣺"+timedesc+"|";//�����ʼʱ������
						s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
				}
			}
		}
		else{
			rtn += "�ѳɹ������û�������λ��������\n";
			array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
			unchat_mem[userid] = tmp;
			string s1 = "";
			s1 +=  userid + "|";//����û�id
			s1 += usernamecn+"|";//����û�������
			s1 += "����ʱ�䣺"+timedesc+"|";//�����ʼʱ������
			s1 += "�������ޣ�"+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
			rtn += s1;
		}
	}
	else{
		rtn += "��û�в���Ȩ�ޣ��뷵��ȷ�ϡ�\n";	
	}
	return rtn;
}

//�г���������б�δ����ҳ����
string list_nologin_user(string userid){
	string tmp = "";
	if(checkpower(userid)=="admin"){
		//����ԱȨ�ޣ��г��û�ͬʱ���г��������
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string id)
			{
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//����û�id
					s1 += arr1[1]+"|";//����û�������
					s1 += "���ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					s1 += "|[������:game_deal free_login "+id+" not not]";
					tmp += s1 + "\n";
				}
			}
		}
		else{
			tmp += "���޷����Ա\n";
		}
	}
	else if(checkpower(userid)=="assist"){
		//��������ԱȨ�ޣ�ֻ�г��û������ܽ��	
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string id)
			{
				array arr1 = (array)unlogin_mem[id];	
				if(arr1&&sizeof(arr1))
				{
					string s1 = "";
					s1 += id + "|";//����û�id
					s1 += arr1[1]+"|";//����û�������
					s1 += "���ʱ�䣺"+arr1[4]+"|";//�����ʼʱ������
					int unlogTime = (int)arr1[3];
					s1 += "������ޣ�"+TIMESD->get_lasttime_desc(unlogTime)+"|"; 
					//���ʣ��ʱ��
					int now_diff = time()-(int)arr1[2];//ʱ���
					int last_time = unlogTime - now_diff; 
					s1 += "ʣ��ʱ�䣺"+TIMESD->get_lasttime_desc(last_time);//�������
					tmp += s1 + "\n";
				}
			}
		}
		else{
			tmp += "���޷����Ա\n";
		}
	}
	else
		tmp += "��û����ӦȨ�޽��в鿴�͹������\n";
	return tmp;
}
//���ӷ����Ա,id,����������������
string add_unlogin(string mid,string userid,string usernamecn,int limit_time){
	string rtn = "";
	if(checkpower(mid)=="admin"||checkpower(mid)=="assist"){
		string timedesc = get_log_name(2);//������ʼʱ������
		//�������ڴ棬������£��ޣ������
		if(unlogin_mem&&sizeof(unlogin_mem)){
			foreach(sort(indices(unlogin_mem)),string index){
				if(index&&sizeof(index)){
					if(index==userid){
						rtn += "�÷���û����ʱ���ѱ��ɹ�����\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unlogin_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//����û�id
						s1 += usernamecn+"|";//����û�������
						s1 += "���ʱ�䣺"+timedesc+"|";//�����ʼʱ������
						s1 += "������ޣ�"+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
					else{
						rtn += "�ѳɹ������û�����������\n";
						array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
						unlogin_mem[userid] = tmp;
						string s1 = "";
						s1 +=  userid + "|";//����û�id
						s1 += usernamecn+"|";//����û�������
						s1 += "���ʱ�䣺"+timedesc+"|";//�����ʼʱ������
						s1 += "������ޣ�"+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
						rtn += s1;
					}
				}
			}
		}
		else{
			rtn += "�ѳɹ������û�������λ�������\n";
			array tmp = ({userid,usernamecn,time(),limit_time,timedesc});	
			unlogin_mem[userid] = tmp;
			string s1 = "";
			s1 +=  userid + "|";//����û�id
			s1 += usernamecn+"|";//����û�������
			s1 += "���ʱ�䣺"+timedesc+"|";//�����ʼʱ������
			s1 += "������ޣ�"+TIMESD->get_lasttime_desc(limit_time)+"\n"; 
			rtn += s1;
		}
	}
	else{
		rtn += "��û�в���Ȩ�ޣ��뷵��ȷ�ϡ�\n";	
	}
	return rtn;
}



