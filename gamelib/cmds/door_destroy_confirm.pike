#include <command.h>
#include <gamelib/include/gamelib.h>

//����

int main(string arg)
{
	object me = this_player();
	object room = environment(me);
	string s = "";
	string s_log = "";//��־
	array(mixed) a = room->query_door()/",";//��
	string dr_name = a[1];//��
	string hm_name = arg;//����
	//sscanf(arg,"%s %s",dr_name,hm_name);
	object dr_ob = (object)(ITEM_PATH+dr_name);
	//object hm_ob = (object)(ITEM_PATH+hm_name);
	//object hammer = present(hm_ob->query_name(),me,0);
	object hammer = present(hm_name,me,0);
	if(!hammer){
		s += "- -!������û�����ִ���\n";
		s += "\n[����:door_destroy_entry]\n";
		//s += "\n[����:door_destroy_entry "+dr_name+"]\n";
		s += "[������Ϸ:look]\n";
	}
	else if(!dr_ob){
		s += "��Ҳ�����������\n";
		s += "\n[����:popview]\n";
		s += "[������Ϸ:look]\n";
	}
	else {
		s += "���ó�һ��"+hammer->query_name_cn()+"һ�����...\n\n";
		int dr_sol = dr_ob->value;//�ŵļ�̶�
		int hm_sol = hammer->value;//���ӵļ�̶�
		int range = 0;
		if(dr_sol>0)
			range = (int)hm_sol*10000/(dr_sol*2);//���Ÿ��ʷ�Χ
		int ran = random(10000);
		if(ran<range){
			s += "��Ĵ��ӻ���!\n�����ſ���!\n";
			s += "\n";
			s += "[��������,͵͵����:home_enter main]\n";
			s += "[�Ͻ��뿪:home_leave "+ room->query_slotName()+" "+room->query_flatName() +"]\n";
			me->home_rights[2]=room->query_masterId();
			string time = (string)time();
			HOMED->save_door("2,"+time+","+me->query_name());
			HOMED->give_master_msg(room,me,"��ҵĴ��ű�"+me->query_name_cn()+"�ҿ��ˣ�����ȥץǿ����\n");
		}
		else {
			s += "���Ĵ��ӻ��ˣ�����û���ҿ���������ҵ��źܼ�̰�~\n";
			s += "\n";
			s += "[��������:door_destroy_detail]\n";
			s += "[�Ͻ��뿪:look]\n";
		}
		me->remove_combine_item(hm_name,1);
	}
	write(s);
	return 1;
}
