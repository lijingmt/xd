#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	object me = this_player();
	int pac_size = me->query_cangku_size();
	string s=me->name_cn+"�Ĳر���"+me->state_packaged(pac_size)+"\n";
	string name=arg;
	int count=0;
	object env=environment(me);
	if(env){
		if(!arg){//�޲�������
			s += "��ѡ��Ҫ�������Ʒ\n";
			s += me->view_inventory_zhuangbei_package("user_package",1,0);
			//s += "[����:look]\n";
			//write(s);
			me->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
		sscanf(arg,"%s %d",name,count);
		//object ob=present(name,this_player(),count);
		array(object) all_ob = all_inventory(me);
		object ob;
		//�������������nameͬ���ķǻ�Ա��Ʒ added by caijie 080815
		foreach(all_ob,object each_ob){
			if(each_ob->query_name()==name&&(!each_ob->query_toVip())){
				ob = each_ob;
				break;
			}
		}
		//add end
		if(!ob)
			s += "�����ϲ�û�������ķǻ�Ա��Ʒ��\n";
		else if(ob->equiped)
			s += "��������װ������Ʒ���ܴ���ر��䡣\n";
		else if(ob->query_item_canStorage() == 0)
			s += "�������͵���Ʒ���ܴ���ر��䡣\n";	
		else{
			int err = this_player()->packaged(ob,pac_size);
			if(err)
				s += "��Ĳر�������ֻ�ܴ�� "+pac_size+" ��������\n";
			else{
				s += "���ڲر����д���һ��"+ob->name_cn+"\n";
				ob->remove();
			}
		}
		s+="[����:user_package]\n";
	}
	else
		s += "��������ʱ���ܽ��иò������뷵�ء�\n";
	s+="[������Ϸ:look]\n";
	write(s);
	return 1;
}
