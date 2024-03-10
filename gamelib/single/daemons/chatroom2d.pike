/*gamelib/single/daemons/chatroomd.pike
 * ���������ݼ�Ƶ��������
 ********************************************************************** 
 * ������ϵͳ�ػ�����
 ��ϵͳ��Ҫ������������ҵĽ������״̬����ȵ�
 * .������ģ�齫���ڴ��д�����������ڴ棬ר�Ÿ���������������Ƶ����
   ���ݺͽӿ�,���ݹ���ʽΪ�û��Լ�����������������,�Թ�������Ƶ��.

   ��չ(��δʵ��):
		����Ȩ���û����Ե�����״̬ʱ,�Լ�����һ������Ƶ��
 * @author calvin 
 * $Date: 2007/04/16 13:13 $
 ***********************************************************************/
#include <globals.h>
#include <wapmud2/include/wapmud2.h>
inherit LOW_DAEMON;
/**********************************************************************
����Ƶ����̬�����ڴ棺

��ʼ��һ��mapping��Ӱ����Ϸ����������Ƶ��
���������ļ����������γɶ�����û��۲���õĽӿڣ������ļ�
���Զ�̬��ӣ�Ȼ������ⲿָ���������ڲ����½ӿ���update�ִ�����Ƶ��
(�����ļ�:ROOT/gamelib/data/chat/chatindex)
private static mapping(string:array) chatIndex = ([]);
([����Ƶ��id:({����Ƶ������,����(���������ʱ����ʱ���ע��),��������(ϵͳ�����Խ�),����(����ʱ��ȵ�)})]);
m**********************************************************************/
#define CHATROOM_LIMITTIME 7200 //����Դ�����Ĵ���ʱ������,Ĭ������Сʱ
private static mapping(string:array) chatIndex=([]);

/**********************************************************************
����Ƶ����Ӧ�����ڴ棺

mapping(string:array(string)) chatCont = ([]);
�ܼ򵥣�һ��mappingӰ�䣬([����Ƶ��id,({������Ϣ1,������Ϣ2,������Ϣ3,......(max=20)})])
ÿ��������Ϣ�ĸ�ʽ��[������id]|������Ϣ
ע�⣺ÿһҳ��������Ϣ����20�������60�������¼����ҳΪ3ҳ
***********************************************************************/
#define CHATLINE_MAX 60
private static mapping(string:array(string)) chatCont=([]);

/**********************************************************************
����Ƶ�������ܣ�

������Թ����������й�����ҿ�������ĳ�������û�
�ķ�����Ϣ����������Ϣ�б�ĸ÷����û��Ա߻���һ�� ���� �����ӣ����ʵ��
�������ε��ʺŴ���ڸ��û����ϣ�ÿ�ε�¼��ռ���(gamelib/d/initʵ��)���ֶ�����
 if(me["/plus/chatblock"])
	me["/plus/chatblock"] = 0;
�����Ǹ�array�ַ������飬������ε�����
***********************************************************************/
//["/plus/chatblock"] �û��ڴ��ֶ�

/**********************************************************************
	�ӿ����
	
	�ܼ�,���ػ����̾���ʵ��һ����̬�����췿��,���Ը��������ļ�������
	д�õĸ�������Ƶ��,���ṩ���û�����,ѡ���½�Ǹ�����Ƶ��,���ڸ�Ƶ��
	����ͻ����û��������Ϣ(���Լ��Ϸ�ҳ,���3ҳ)
	1.create():
		��ʼ���ӿڣ����������ļ�����������Ƶ�������ڴ�ȵ�
	2.query_chatroom_list():
		�������ڿ���Ƶ���б��γ����ӷ��ظ��û�
	3.query_chat_msg(string chatid, string look_id):
		ȡ��ĳƵ�����������ݣ����ز���ҳ����,������Ҫע�����,���ݲ쿴
		�ߴ�����id�õ��쿴�����ϵ�����id�б����ε�����id�ķ�����Ϣ��
		������������.
	4.add_chat_msg(string chatid, string msg, string uid):
		����һ��������Ϣ��ĳƵ�������Ժ���Ҫ�ڸ���Ϣ�ϸ��Ӹ÷����û�
		�����ӣ����������û�����󣬿��Կ��� ����Ϣ�ͼ�Ϊ���� ��������
	5.reload_chatroom():
		���¶��������ļ����������������Ϣ
	6.add_chatroom(string uid):
		���һ������Ȩ�޵����(�����Ա)�Դ�������Ƶ��,����chatIndex�ڴ�,�������
		����Ƶ����������.
	7.del_chatroom(string chatid):
		ɾ��ĳ��Ƶ��,�������������.
	8.pagnition(string allmsg):
		��ҳ����ӿ�,��ù̶���60��������Ϣ,ʵ�ַ�ҳ����.
	9.flush_all_room():
		��ʱ��������Ƶ��״̬��������ڵ��û��Խ�����Ƶ��
***********************************************************************/

#define FILE_PATH "/gamelib/data/chat/chatindex"

void create(){
	//����Ƶ���������ڴ�
	if(chatIndex==0)
		chatIndex=([]);
	//����Ƶ�����������ڴ�
	if(chatCont==0)
		chatCont=([]);
	//��������Ƶ�������ļ����ڴ��
	reload_chatroom();
}
private void reload_chatroom(){
	//����Ƶ���������ڴ�
	chatIndex=([]);
	//����Ƶ�����������ڴ�
	chatCont=([]);
	string strlists = "";
	strlists = Stdio.read_file(ROOT+FILE_PATH); 
	if(strlists&&sizeof(strlists)){
		array rooms = strlists/"\n";
		if(rooms&&sizeof(rooms)){
			foreach(rooms,string cont){
			//([����Ƶ��id:({����Ƶ������,����(���������ʱ����ʱ���ע��),��������(ϵͳ�����Խ�),����(����ʱ��ȵ�)})]);
			//example:  pub_channel|����Ƶ��|Ѱ������������У�����Ƶ���������ԣ�|system|0
				if(cont&&sizeof(cont)){
					string r_index = (cont/"|")[0];
					string r_title = (cont/"|")[1];
					string r_desc = (cont/"|")[2];
					string r_type = (cont/"|")[3];
					string r_createtime = (cont/"|")[4];
					chatIndex[r_index]=({"","","",""});//����Ƶ��id�����磺pub_channel�ǹ���Ƶ��
					chatIndex[r_index][0]=r_title;//����Ƶ��title:���繫��Ƶ��
					chatIndex[r_index][1]=r_desc;//����Ƶ��desc:����Ƶ������
					chatIndex[r_index][2]=r_type;//����Ƶ��type:����Ƶ������ ��systemΪϵͳƵ��
					chatIndex[r_index][3]=r_createtime;//����Ƶ������ʱ�䣺ֻ���Խ�����Ƶ�����д�ѡ��
					//��ʼ��������Ƶ���������ڴ�
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
//��������Ƶ���б�
string query_chatroom_list(){
	string rst = "";
	rst += "��ǰ����Ƶ���б�\n";
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
		rst+="��������Ƶ�����š�\n";
	return rst;	
}
//����ĳ��Ƶ��,ĳ���˿�����������Ϣ
string query_chat_msg(string cid, string look_id){
	string rst = "";
	if(chatIndex&&sizeof(chatIndex)){
		if(chatIndex[cid][0]&&sizeof(chatIndex[cid][0]))
			rst += chatIndex[cid][0]+"\n";
	}
	else
		return rst += "��Ƶ���Ѿ��ر�,�뷵�ء�\n";
	object looker = find_player(look_id);
	if(!looker)
		return "����ϵͳ������ʱ�����⣬�뷵�����ԡ�\n";
	//mapping(string:array(string)) chatCont = ([]);
	//([����Ƶ��id,({������Ϣ1,������Ϣ2,������Ϣ3,......(max=60)})])
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
					//ÿ��������Ϣ�ĸ�ʽ��[������id]|������Ϣ
					//werror("     msg="+msg+"\n");
					array(string) marr = msg/"|";
					if(marr&&sizeof(marr)){
						marr -= ({});
						//�õ�������Ϣ�����ߵ�id
						string defendid = (string)marr[0];
						//werror("    ������="+defendid+"\n");
						//�õ�����������Ӧ����ʾ��������Ϣ
						string contents = (string)marr[1];
						//werror("    �����߷���="+contents+"\n");
						if(looker["/plus/chatblock"]&&sizeof(looker["/plus/chatblock"])){
							//������Ϣ�ķ�����id�Ƿ��ڹ۲��ߵ������б���
							foreach(looker["/plus/chatblock"],string who){
								if(who&&who==defendid)
									//���������id�ڹ۲�������id�б��У�����ʾ������Ϣ
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
				rst += "��ʱû���˷�����Ϣ��\n";
		}
	}
	else
		rst += "����Ƶ���Ѿ��رա�\n";
	return rst;
}
//����Ƶ��������Ϣ���ɹ�����1
int add_chat_msg(string tid, string msg){
	int flag = 1;
	if(tid&&sizeof(tid)&&msg&&sizeof(msg)){
		//mapping(string:array(string)) chatCont = ([]);
		//([����Ƶ��id,({������Ϣ1,������Ϣ2,������Ϣ3,......(max=60)})])
		array tmparr;
		if(chatCont&&sizeof(chatCont))
			tmparr = (array)chatCont[tid];
		if(!tmparr){
			//����ÿ��������Ϣ�ĸ�ʽ��[������id]|������Ϣ
			//����id��������ʾ��ʱ�����ε�
			string str1 = "Ƶ��������Ϣ\n"+"~"+msg+"\n";
			array a1 = str1/"~";
			chatCont[tid] = a1;
			flag = 1;
		}
		else{//������Ϣ��Ϊ�գ�˳�Ӳ�ɾ��ͷ��Ϣ
			if(sizeof(tmparr)<=15){
				string s1 = "";
				//С��15�У�˳�Ӽ���������Ϣ
				for(int i=0; i<sizeof(tmparr); i++)
					s1 += (string)tmparr[i]+"~";
				s1 += msg + "\n";
				array newarr = s1/"~";
				//���������ڴ��ļ�
				chatCont[tid] = newarr;
				flag = 1;
			}
			else{
				string s1 = "";
				//����15�У�ȥ��ͷ��Ϣ����˳�Ӽ���������Ϣ��β
				for(int i=1; i<sizeof(tmparr); i++)
					s1 += (string)tmparr[i]+"~";
				s1 += msg + "\n";
				array newarr = s1/"~";
				//���������ڴ��ļ�
				chatCont[tid] = newarr;
				flag = 1;
			}
		}
	}
	else
		flag = 0;
	return flag;
}
//����ϵͳ���ýӿ�
string query_chatroom_msg(string cid, string look_id){
	string rst = "";
	/*
	if(chatIndex&&sizeof(chatIndex)){
		if(chatIndex[cid][0]&&sizeof(chatIndex[cid][0]))
			rst += chatIndex[cid][0]+"\n";
	}
	else
		return rst += "��Ƶ���Ѿ��ر�,�뷵�ء�\n";
	*/
	object looker = find_player(look_id);
	if(!looker)
		return "����ϵͳ������ʱ�����⣬�뷵�����ԡ�\n";
	//mapping(string:array(string)) chatCont = ([]);
	//([����Ƶ��id,({������Ϣ1,������Ϣ2,������Ϣ3,......(max=60)})])
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
					//ÿ��������Ϣ�ĸ�ʽ��[������id]|������Ϣ
					//werror("     msg="+msg+"\n");
					array(string) marr = msg/"|";
					if(marr&&sizeof(marr)){
						marr -= ({});
						//�õ�������Ϣ�����ߵ�id
						string defendid = (string)marr[0];
						//werror("    ������="+defendid+"\n");
						//�õ�����������Ӧ����ʾ��������Ϣ
						string contents = (string)marr[1];
						//werror("    �����߷���="+contents+"\n");
						if(looker["/plus/chatblock"]&&sizeof(looker["/plus/chatblock"])){
							//������Ϣ�ķ�����id�Ƿ��ڹ۲��ߵ������б���
							foreach(looker["/plus/chatblock"],string who){
								if(who&&who==defendid)
									//���������id�ڹ۲�������id�б��У�����ʾ������Ϣ
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
					//ÿ��������Ϣ�ĸ�ʽ��[������id]|������Ϣ
					//werror("     msg="+msg+"\n");
					array(string) marr = msg/"|";
					if(marr&&sizeof(marr)){
						marr -= ({});
						//�õ�������Ϣ�����ߵ�id
						string defendid = (string)marr[0];
						//werror("    ������="+defendid+"\n");
						//�õ�����������Ӧ����ʾ��������Ϣ
						string contents = (string)marr[1];
						//werror("    �����߷���="+contents+"\n");
						if(looker["/plus/chatblock"]&&sizeof(looker["/plus/chatblock"])){
							//������Ϣ�ķ�����id�Ƿ��ڹ۲��ߵ������б���
							foreach(looker["/plus/chatblock"],string who){
								if(who&&who==defendid)
									//���������id�ڹ۲�������id�б��У�����ʾ������Ϣ
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
		rst += "����Ƶ���Ѿ��رա�\n";
	return rst;
}
