#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		if(me->query_term()==""||me->query_term()=="noterm"){
			s += "��û�����κζ����У��޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else if(!TERMD->query_termId((string)me->query_term())){
			s += "�����ڵĶ����Ѿ���ɢ���޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else{
			s += "[ˢ��:term_chat flush]\n[term_chat ...]\n";
			s += TERMD->query_termChat(me->query_term());	
		}
		s+="[����:my_term]\n";
		s+="[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	else if(arg=="flush"){
		if(me->query_term()==""||me->query_term()=="noterm"){
			s += "��û�����κζ����У��޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else if(!TERMD->query_termId((string)me->query_term())){
			s += "�����ڵĶ����Ѿ���ɢ���޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else{
			//����������Ϣ	
			s += "[ˢ��:term_chat flush]\n[term_chat ...]\n";
			s += TERMD->query_termChat(me->query_term());	
		}
		s+="[����:my_term]\n";
		s+="[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	if(arg&&arg!=""){
        	arg = TIPSD->check_words(arg);
		arg = filter_msg(arg);
		for(int i=0;i<sizeof(arg);i++){
			if(arg[i]>=0&&arg[i]<=127){
				if(arg[i]>='a'&&arg[i]<='z'||arg[i]>='A'&&arg[i]<='Z'||arg[i]>='0'&&arg[i]<='9')
					;
				else
					arg=0;
			}
		}
 		if(!arg){
			if(me->query_term()==""||me->query_term()=="noterm"){
				s += "��û�����κζ����У��޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else if(!TERMD->query_termId((string)me->query_term())){
				s += "�����ڵĶ����Ѿ���ɢ���޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else{
      			s += "��ʹ�����ġ�Ӣ����ĸ�������֡�\n";
				s += "[ˢ��:term_chat flush]\n[term_chat ...]\n";
				s += TERMD->query_termChat(me->query_term());	
			}
			s+="[����:my_term]\n";
			s+="[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else if(sizeof(arg)>=140||sizeof(arg)<=0){
			if(me->query_term()==""||me->query_term()=="noterm"){
				s += "��û�����κζ����У��޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else if(!TERMD->query_termId((string)me->query_term())){
				s += "�����ڵĶ����Ѿ���ɢ���޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else{
   				s += "������Ϣ���Ȳ���С��1���ַ����߳���70���ַ���\n";
				s += "[ˢ��:term_chat flush]\n[term_chat ...]\n";
				s += TERMD->query_termChat(me->query_term());	
			}
			s+="[����:my_term]\n";
			s+="[������Ϸ:look]\n";
			write(s);
			return 1;
		}
		else{
			if(me->query_term()==""||me->query_term()=="noterm"){
				s += "��û�����κζ����У��޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else if(!TERMD->query_termId((string)me->query_term())){
				s += "�����ڵĶ����Ѿ���ɢ���޷�ʹ�ö������칦�ܣ��뷵�ء�\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			mapping now_time = localtime(time());
			int month = now_time["mon"]+1;
			int day = now_time["mday"];
			int hour = now_time["hour"];
			int minute = now_time["min"];
			arg =me->query_name_cn()+"��"+arg;
			if(TERMD->add_termChat(me->query_term(),arg)){
				s += "[ˢ��:term_chat flush]\n[term_chat ...]\n";
				s += TERMD->query_termChat(me->query_term());	
				string now=ctime(time());
				Stdio.append_file(ROOT+"/log/term_msg.log",now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+"):"+arg+"\n");
			}
			else{
				s += "��Ϣ����ʧ�ܣ��뷵�����ԣ�\n";
				s += "[ˢ��:term_chat flush]\n[term_chat ...]\n";
				s += TERMD->query_termChat(me->query_term());	
			}
		}
	}
	s+="[����:my_term]\n";
	s+="[������Ϸ:look]\n";
	write(s);
	return 1;
}
string filter_msg(string arg)
{
	if(!arg)
		return "";
	arg=replace(arg,"'","��");
	arg=replace(arg,",","��");
	arg=replace(arg,".","��");
	arg=replace(arg,"@","��");
	arg=replace(arg,"#","��");
	arg=replace(arg,"%","��");
	arg=replace(arg,"~","��");
	arg=replace(arg,"^","��");
	arg=replace(arg,"$","��");
	arg=replace(arg,"+","��");
	arg=replace(arg,"|","��");
	arg=replace(arg,"&","��");
	arg=replace(arg,"=","��");
	arg=replace(arg,"(","��");
	arg=replace(arg,")","��");
	arg=replace(arg,"-","��");
	arg=replace(arg,"_","��");
	arg=replace(arg,"*","��");
	arg=replace(arg,"?","��");
	arg=replace(arg,"!","��");
	arg=replace(arg,"<","��");
	arg=replace(arg,">","��");
	arg=replace(arg,"\/","��");
	arg=replace(arg,"\"","��");
	arg=replace(arg,"\\","��");
	arg=replace(arg,"\r\n","");
	arg=replace(arg,":","��");
	arg=replace(arg,";","��");
	arg=replace(arg,"\{","��");
	arg=replace(arg,"\}","��");
	arg=replace(arg,"[","��");
	arg=replace(arg,"]","��");
	arg=replace(arg,"%20","��");	
	return arg;
}
