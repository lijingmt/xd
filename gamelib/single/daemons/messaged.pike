/*
   ����ϵͳ�����ڹ���Ա����Ϸ�й�����ȹ��ܵ�ʵ��
   
   @author caijie
   2008/07/16

  �����ݽṹ��
   mapping(int:array(string)) all_msg
   ���й��水����ʱ��˳����뵽��ӳ����У���ṹΪ
   index:({					��������������淢��ʱ��(��)����Ҫ��Ϊ�����ױȽϴ�С��
   	    a[0]=1			       ����𡿣�Ŀǰֻ��"����"��һ��ģ�飬Ϊ��չ���Ԥ�����ֶ�
	    a[1]=Fri Jul 18 14:39:31 2008       ���淢��ʱ��
	    a[2]=xd1				��Ϸ��
	    a[3]=caijie				�������ʺ�
	    a[4]=������ͯ			��������������
	    a[5]=7��8�ո��¹���			�������
	    a[6]=��������			��������
	    a[7]=2008-07-18 15:16:34		�޸Ĺ���ʱ��
   })

  ������˵����
   load_msg():���¸��ļ�ʱִ�У���Ҫ�ǰ�Ҫ��ʾ�Ĺ��������У��Է�����Ļ��޸Ĺ������
   write_file():��Ҫ��ҳ������ʾ�Ĺ���д�뵽msg.list�У�ÿ�� WRITE_TIME ִ��һ�Σ����÷�����ִ��ʱmsg.list�ļ�������д
   get_new_msg():��ȡ���¹��棬����ҵ����Ϸ����ʱ�����ø÷���
   get_new_msg():��ȡ��ʷ����
   msg_rewrite():���޸ĺ��µĹ������ݸ���ԭ���Ĺ������ݣ�������������
   msg_del():����id���Ӧ�Ĺ����ӳ���all_msg��ɾ��
   msg_send():��������뵽ӳall_msg�����
   
  ��ʵ���߼���
   all_msg �洢Ҫ��ʾ�Ĺ�����Ϣ�����в�������Ըñ���д���write_file()��¼�ñ����������,�����������°�����д����У��������Ա����������ڴ��еĹ������ݶ�ʧ�����
*/
#include <globals.h>
#include <gamelib/include/gamelib.h>
//#define BC_MSG_FILE_PATH DATA_ROOT "message/"//��־�ļ�Ŀ¼
#define MSG_LIST DATA_ROOT "msg.list"	//�洢��Ҫ��ҳ������ʾ�Ĺ�����Ϣ�ļ�,�洢��ʽ������ʱ��|��Ϸ��|�ʺ�|������|�������|��������
#define MSG_FILE ROOT "/log/msg.log"	//��¼����������Ϣ���޸Ĺ�����Ϣ�����ݰ����������ʺš����֣�����ʱ�䡢������⼰����
//#define WRITE_TIME 3600*24		//���ڴ��е���Ϣ�����ʱ����,�ɸ�������޸�
inherit LOW_DAEMON;
private mapping(int:array(string)) all_msg = ([]);          //�洢������Ϣ


void create()
{
	load_msg();
	write_file();
}


//��Ҫ��ʾ�Ĺ����ȡ���ڴ浱��
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
				msg_tmp += ({"1"});					//msg_tmp[0]���
				//���ļ���ȡ����Ϣ:����ʱ��[1]����Ϸ��[2]���ʺ�[3]��������[4]���������[5]����������[6]
				msg_tmp += columns;
				msg_tmp += ({0});					//msg_tmp[7]�޸�ʱ��
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

//���ڴ��еĹ�����Ϣд�뵽msg.list�ļ���
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
	//call_out(write_file,WRITE_TIME);   //ÿ�� WRITE_TIME �����һ��
}

/*
�������������ڴ��л�ȡ���¹�����Ϣ

����ֵ�����ع�����⼰����
*/
string get_new_msg()
{
	int msg_count = sizeof(all_msg);
	string s = "";
	if(msg_count>0){
		int id = sort(indices(all_msg))[msg_count-1];
		s += all_msg[id][5]+":\n"+all_msg[id][6]+"\n";//��ȡ���������
	}
	//werror("----msg_count="+msg_count+"---head"+all_msg[msg_count][5]+"----text="+all_msg[msg_count][6]+"----\n");
	return s;
}


/*
��������:�鿴��ʷ����,ʱ�����µ�����ǰ��
����:is_admin �ж��Ƿ��ǹ���Ա�����ǹ���Ա�����޸ĺ�ɾ����Ȩ�ޣ�����ֻ���Ķ�Ȩ��
     void �г���ʷ�����������
     id ��ʾ��ȡ�ڼ�������

����ֵ:void ������ʷ�����������
	id  ���ظ�idָ��Ĺ�����������
*/
string get_old_msg(string is_admin,void|int id)
{
	int msg_count = sizeof(all_msg);
	string s = "";

	if(msg_count<=0){
		s += "Ŀǰû����ʷ���档\n";
		return s;
	}
	if(!id){
		array(int) m_id = sort(indices(all_msg));//��������С��������
		//��Ϣ������ʱ�併������
		for(int j=msg_count-1;j>=0;j--){
			int i = m_id[j];
			array(string) tmp = all_msg[i];
			if(is_admin=="admin"){
				s += "["+tmp[5]+":msg_read "+i+"] [�޸�:msg_write_entry "+i+"] [ɾ��:msg_del "+i+"]\n";
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
�����������޸Ĺ���ӿڣ������汻�޸ĺ�mapping���ж�Ӧ�þɹ���ᱻ�¹��渲��
������msg ���޸ĵĹ�����Ϣ�ṹΪ msg[0]:��Ϸ����
                                 msg[1]:����Ա�ʺ�
                                 msg[2]:����Ա��������
                         	 msg[3]:�������
			         msg[4]:��������
      id ԭ������mapping���еĴ��id
����ֵ��2 ���治����
	1 �޸ĳɹ�
	0 �޸�ʧ��
*/
int msg_rewrite(array msg,int id)
{
	string s_log = "";
	if(all_msg[id] && sizeof(all_msg[id])){
		if(sizeof(msg)==5){
			array(string) msg_tmp = ({});
			int msg_count = sizeof(all_msg);
			msg_tmp += ({"1"});					//msg_tmp[0]���
			msg_tmp += ({all_msg[id][1]});	//msg_tmp[1]����ʱ��
			msg_tmp += msg;			//��Ϸ���ţ������������ʺţ���������������������������⼰��������
			msg_tmp += ({MUD_TIMESD->get_mysql_timedesc()});	//msg_tmp[7]�޸�ʱ��
			if(sizeof(msg_tmp)==8){
				all_msg[id] = msg_tmp;
				s_log += msg[0]+"|"+msg[1]+"|"+msg[2]+"|"+"�޸�"+ctime((int)msg_tmp[1])+"�����Ĺ���Ϊ��| ���⣺"+msg[3]+"| ����:"+msg[4]+"\n";
				Stdio.append_file(MSG_FILE,MUD_TIMESD->get_mysql_timedesc()+":"+s_log);//����Ϣд����־��
				return 1;
			}
		}
		return 0;
	}
	return 2;
}

/*
����������ɾ������ӿ�
������id �ù����ڱ��еĴ洢λ��
����ֵ��1 ɾ���ɹ�
	0 �ù��治����
*/
int msg_del(int id)
{
	object me = this_player();
	string s_log = "";
	if(all_msg[id] && sizeof(all_msg[id])){
		string title = all_msg[id][5];//������⣬���ڴ�log
		int time = (int)all_msg[id][1];//����ʱ�䣬���ڴ�log
		m_delete(all_msg,id);
		s_log = "("+me->query_name()+")"+me->query_name_cn()+"ɾ��"+ctime(time)+"�����Ĺ��棬�����Ϊ:"+title+"\n";
		Stdio.append_file(MSG_FILE,MUD_TIMESD->get_mysql_timedesc()+":"+s_log);//����Ϣд����־��
		return 1;
	}
	return 0;
}

/*
���������������¹�����뵽ӳ�����
������msg ��Ҫ��ʾ����Ϣ,�ṹΪ msg[0]:��Ϸ����
                                msg[1]:����Ա�ʺ�
				msg[2]:����Ա��������
				msg[3]:�������
				msg[4]:��������
����ֵ��0 ����ʧ��  
	1 ����ɹ�
*/

int msg_send(array(string) msg)
{
	string s_log = "";
	if(sizeof(msg)==5){
		array(string) msg_tmp = ({});
		int msg_count = sizeof(all_msg);
		msg_tmp += ({"1"});					//msg_tmp[0]���
		msg_tmp += ({time()});	//msg_tmp[1]����ʱ��
		msg_tmp += msg;
		msg_tmp += ({0});
		if(sizeof(msg_tmp)==8){
			all_msg[time()] = msg_tmp;
			//all_msg[msg_count+1] = msg_tmp;
			s_log += msg[0]+"|"+msg[1]+"|"+msg[2]+"|"+"�����Ĺ��棺| ���⣺"+msg[3]+"| ����:"+msg[4]+"\n";
			Stdio.append_file(MSG_FILE,MUD_TIMESD->get_mysql_timedesc()+":"+s_log);//����Ϣд����־��
			return 1;
		}
	}
	else 
		return 0;
}

