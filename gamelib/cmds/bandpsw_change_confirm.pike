#include <command.h>
#include <gamelib/include/gamelib.h>
//ȷ�����ð�ȫ��ָ��

int main(string arg)
{
	object me = this_player();
	string s = "";
	string regmb = ""; //���ֻ�
	string psw0 = "";  //ԭ���İ�ȫ��
	string psw1 = "";  //��һ��������°�ȫ��
	string psw2 = "";  //�ڶ���������°�ȫ��
	string mobile = "";
	string p0 = "";
	string p1 = "";
	string p2 = "";
	werror("-------arg="+arg+"-------");
	if(sscanf(arg,"%s %s %s %s",p2,p0,p1,mobile)==4){
		sscanf(mobile,"mb=%s",regmb);
		sscanf(p0,"op=%s",psw0);
		sscanf(p1,"np=%s",psw1);
		sscanf(p2,"rp=%s",psw2);
		if(!me->mobile){
			s += "����δ�����ֻ��󶨣�Ϊ�������ʺŵİ�ȫ��������ֻ��󶨲������ٽ��а�ȫ������\n";
			s += "[�ֻ���:tieToMobile]\n";
		}
		else if(!regmb || regmb!=me->mobile){
			s += "������д���ֻ������������󶨵��ֻ����벻һ��\n";
			s += "[������д:bandpsw_change]\n";
		}
		else if(psw0!=me->bandpswd){
			s += "������д�ľɰ�ȫ�����\n";
			s += "[������д:bandpsw_change]\n";
		}
		else if(!psw1 || !psw2 || sizeof(psw1)<2 || sizeof(psw1)>11||(!NAMESD->is_psw(psw1))){
			s += "��ȫ�������2-11λ֮�䣬����ֻ�������ֺ���ĸ\n";
			s += "[������д:bandpsw_change]\n";
		}
		else if (psw1!=psw2){
			s += "������д��������ȫ�����ݲ�һ��\n";
			s += "[������д:bandpsw_change]\n";
		}
		else {
			me->bandpswd = psw1;
			s += "��ϲ�����óɹ���\n";
			s += "���İ�ȫ��Ϊ��"+psw1+"\n";
			s += "���μ����İ�ȫ�룬�Ա����ʺų��ְ�ȫ�����ʱ�����ʺ�\n";
			string now=ctime(time());
			string log = me->query_name()+"("+me->query_name_cn()+")�ɹ��޸İ�ȫ��Ϊ��"+psw1+",ԭ��ȫ��Ϊ"+psw0+"\n";
			Stdio.append_file(ROOT+"/log/bandpswd.log",now[0..sizeof(now)-2]+":"+log);
		}
		s += "[���ع��ڰ�ȫ��:bandpsw_readme]\n";
		s += "[������Ϸ:look]\n";
		write(s);
		return 1;
	}
	s += "���벻��ȷ.���ֻ��Ͱ�ȫ�붼����Ϊ��\n";
	s += "[����:bandpsw_change]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
