#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	string s = "";
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	if(ob){
		if(ob->eat_flag==1){
			string obname = ob->query_name_cn();
			int tmp = ob->drink();
			switch(tmp){
				case 0:
					s += "��ĵȼ��������������� "+obname+" ��\n";	
				break;
				case 1:
					s += "�������� "+obname+" ��\n";	
				break;
				case 2:
					s += "���ְҵ�������ø���Ʒ��\n";
				break;
				case 3:
					s += "�����Ӫ�������ø���Ʒ��\n";
				break;
				case 4:
					s += "��Ҫ����ʲô��Ʒ��\n";
				break;
				case 5:
					s += "�����ڵ�״̬�������ø���Ʒ��\n";
				break;
				case 11:
					s += "���Ѿ������������ޣ��������ø���Ʒ��\n";
				break;
				case 22:
					s += "���Ѿ����﷨�����ޣ��������ø���Ʒ��\n";
				break;
			}
		}
		else if(ob&&ob->eat_flag==0){
			s += "����Ʒ�Ѿ����ù��ˡ�\n";
		}
	}
	else{
		s += "û����Ʒ�������á�\n";
	}
	write(s);
	write("[����:inventory]\n");
	write("[������Ϸ:look]\n");
	return 1;
}
