#include <globals.h>

int main(string arg)
{
	string path,user_name,lgpswd,userip;
	string title = "";
	title += "=��ҵ�¼=\n";
	if(arg&&(sscanf(arg,"%s %s %s %s",path,user_name,lgpswd,userip)==4)){
		if(!path || !user_name || !lgpswd || !userip){
			title += "��¼����\n";
			title += "��������û��������벻���Ϲ淶���뷵�����ԡ�\n";
			title += "[url ����:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		else if( sizeof(user_name)<2 || sizeof(lgpswd)<2 ){
			title += "��¼����\n";
			title += "��������û��������벻���Ϲ淶���뷵�����ԡ�\n";
			title += "[url ����:http://"+INDEX_URL+"]\n";
			write(title);
			return 1;
		}
		object me = find_player(user_name);
		if(!me){
			//�������û�������״̬,��һ������Ҫȥ�����������������е�����
			string user=Stdio.read_file(DATA_ROOT+"u/"+user_name[sizeof(user_name)-2..]+"/"+user_name+".o");
			if(user&&sizeof(user))
				;
			else{
				werror("----"+user_name+"----\n");
				title += "��¼����\n";
				title += "��������û��������ڣ��뷵�����ԡ�\n";
				title += "[url ����:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
			//������Ҫ�ҵ����û������е������ֶβ��Ա�lgpswd
			string pswd;
			string userSid;	
			array(string) usr_content=user/"\n";
			foreach(usr_content,string strCompare){
				if( (strCompare/" ")[0]=="password" ){
					if( (strCompare/" ")[1] ){
						string pswdTmp = (strCompare/" ")[1];
						pswd =(pswdTmp/"\"")[1];
					}
				}
				//jsessionid ����ԭ�����Ǹ��˺ţ��������µ�½
				if( (strCompare/" ")[0]=="userip" ){
					if( (strCompare/" ")[1] ){
						string Tmp = (strCompare/" ")[1];
						userSid =(Tmp/"\"")[1];
					}
				}
			}
			if(!pswd||!userSid){
				title += "��¼����\n";
				title += "��ȫ��֤ʧ�ܣ��뷵�����ԡ�\n";
				title += "[url ����:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
			else if( (pswd && lgpswd==pswd) && (userSid && userip==userSid) ){
				program u;
				object m;
				catch{
					m=(object)(ROOT+"/"+path+"/master.pike");
				};
				if(m){
					u=m->connect();
				}
				if(!u)
					u=(program)(ROOT+"/"+path+"/clone/user.pike");
				me=u();

				me->set_name(user_name);
				me->set_project(path);
				if(me->setup(pswd)){
					
					//дd/init����û�ã���Ϊ�Ѿ����浽viewd��ͼ�У�rd_tmpֵ����0
					if(me["/plus/random_rcd"]==1){ //�齱ǿ���ʴ�δ������ߣ����ߺ�����tmp1��tmp2��tmp3 
						int t1 = random(100) + 1;
						int t2 = random(100) + 1;
						int t3 = t1*t2;
						me["/tmp/rd_tmp1"] = t1;
						me["/tmp/rd_tmp2"] = t2;
						me["/tmp/rd_tmp3"] = t3;
						//werror("login.pike call rd_tmp1=["+me["/tmp/rd_tmp1"]+"]\n");
						//werror("login.pike call rd_tmp2=["+me["/tmp/rd_tmp2"]+"]\n");
						//werror("login.pike call rd_tmp3=["+me["/tmp/rd_tmp3"]+"]\n");
					}

					exec(me,previous_object());
					if(environment(me)==0)
						me->move(LOW_VOID_OB);
					destruct(previous_object());
				}
			}
			else{
				title += "��¼����\n";
				title += "��ȫ��֤ʧ�ܣ��뷵�����ԡ�\n";
				title += "[url ����:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
		}
		else{//�������û��ղ����߲���project·����ȷ,�͵���reconnect
			string pswd = me->password;
			string userSID = me->query_userip();
			//�������ͬһ���ֻ���½��jsessionid��ͬ�����߳�ȥ
			if( (pswd && lgpswd==pswd) && (userSID && userip==userSID) ){
				if(me->project==path&&me["reconnect"]&&me->reconnect(lgpswd)){
					exec(me,previous_object());
					destruct(previous_object());
				}
			}
			else{
				title += "��¼����\n";
				title += "��ȫ��֤ʧ�ܣ��뷵�����ԡ�\n";
				title += "[url ����:http://"+INDEX_URL+"]\n";
				write(title);
				return 1;
			}
		}
	}
	else{
		title += "��¼����\n";
		title += "���ĵ�½�Ѿ����ڣ��뷵�����µ�½��\n";
		title += "[url ����:http://"+INDEX_URL+"]\n";
		write(title);
		return 1;
	}
	return 1;
}
