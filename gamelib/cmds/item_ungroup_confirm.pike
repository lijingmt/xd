#include <command.h>
#include <gamelib/include/gamelib.h>
//������Ʒ����
int main(string arg)
{
	object me = this_player();
	string s = "";
	string num_s = "";
	string name = "";
	int count = 0;
	int num = 0;
	//[item_ungroup_confirm linglongyu 0  no=1]
	sscanf(arg,"%s %d %s",name,count,num_s);
	werror("----num_s=["+num_s+"]\n");
	sscanf(num_s,"no=%d",num);
	werror("----num=["+num+"]\n");
	object ob = present(name,me,count);
	if(ob){
		if(num>=1 && num<ob->amount){
			me->remove_combine_item(ob->query_name(),num);
			string file_path = file_name(ob);
			object ob_new = clone((file_path/"#")[0]);
			ob_new->amount = num;
			ob_new->move(me);
			s += "���Ѿ��ɹ�������Ʒ����\n";
		}
		else{
			s += "��������ֲ���ȷ\n";
		}
	}
	else{
		s += "�����û����������Ʒ\n";
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
