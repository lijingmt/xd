//���û���д�Ƽ��˵�ָ��
#include <command.h>
#include <gamelib/include/gamelib.h>
#define log_file ROOT "/log/presenter.log"
int main(string arg)
{
	object me = this_player();
	string s = "";
	if(!arg){
		if(me->sid == "5dwap")
			s += "��Ŀǰ�������û����޷���д�Ƽ��ˣ���ӭע����ʽ�ʺ��������ɵ�����\n";
		else if(me->query_name_cn() == "��������" || me->query_name_cn() == "������ͯ")
			s += "����Ϊ�Լ�ȡ������\n";
		else if(me->set_presenter == "" || me->set_presenter != "can_set")
			s += "��������д�Ƽ��ˣ���������ע���û������Ѿ���д����\n";
		else if(me->set_presenter == "can_set"){
			s += "�Ƽ����˺ţ�[string na:...]\n";
			s += "�Ƽ���ԭ������Ϸ����\n[submit ԭ����:present_set 0 xd2 ...]\n[submit ԭ����:present_set 0 xd3 ...]\n[submit ����:present_set 0 xdX ...]\n";
		}
	}
	else{
		string p_name = "";
		int flag = 0;
		string area ="";
		sscanf(arg,"%d %s na=%s",flag,area,p_name);
		p_name = filter_msg(p_name);
		if(sizeof(p_name)<2 || sizeof(p_name)>11)
			s += "��������Ƽ����ʺ�������ȷ�Ϻ���������\n";
		else if(check_name(p_name) == 0)
			s += "��������ʺ�������ȷ�Ϻ���������\n";
		else if(area+p_name == me->query_name())
			s += "��������д�Լ�Ϊ�Ƽ���\n";
		else if(me->set_presenter == "" || me->set_presenter != "can_set")
			s += "��������д�Ƽ��ˣ���������ע���û������Ѿ���д����\n";
		else{
			string new_name = area+p_name;//������������±仯
			int load_flg = 0;
			object presenter = find_player(new_name);
			if(!presenter){
				mixed err = catch{
					presenter = me->load_player(new_name);
					load_flg = 1;
				};
				if(err || !presenter){
					s += "û�������ң���ȷ�Ϻ���������\n";
					s += "[����:look]\n";
					write(s);
					return 1;
				}
			}
			if(presenter->query_name_cn() == "��������" || presenter->query_name_cn() == "������ͯ"){
				s += "����ʧ�ܣ�����д���Ƽ��߻�û���Լ�������\n";
				s += "[��Ҫ������д:present_set]\n";
				s += "[����:look]\n";
				write(s);
				return 1;
			}
			if(flag == 0){
				s += "����д���Ƽ����� "+presenter->query_name_cn()+"\n";
				s += "[�ԣ���������:present_set 1 "+area+" na="+p_name+"]\n";
				s += "[������Ҫ������д:present_set]\n";
				s += "[����:look]\n";
				write(s);
				return 1;
			}
			else{
				if(MUD_PRESENTD->set_my_presenter(me->query_name(),me->query_name_cn(),me->all_mark,presenter->query_name(),presenter->query_name_cn())){
					me->set_presenter = presenter->query_name();
					//presenter->cur_mark += 10;
					//presenter->all_mark += 10;
					//MUD_PRESENTD->flush_all_mark(presenter->query_name(),presenter->all_mark);
					s += "��ɣ������Ƽ����� "+presenter->query_name_cn()+"\n";
					if(load_flg)
						presenter->remove();
				}
				else 
					s += "��д������ȷ�Ϻ��������룬�����޷���ɣ�����ϵ����Ա\n";
			}
		}
	}
	s += "[����:look]\n";
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
int check_name(string user_name){
	for(int i=0;i<sizeof(user_name);i++){
		if( user_name[i]>='a'&&user_name[i]<='z'||user_name[i]>='A'&&user_name[i]<='Z'||user_name[i]>='0'&&user_name[i]<='9')
			;
		else{
			return 0;
		}
	}
	return 1;
}
