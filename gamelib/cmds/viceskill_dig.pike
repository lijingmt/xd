#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM_PATH_KUANG ITEM_PATH+"material/"
//arg = name count
int main(string arg)
{
	string s = "";
	object me=this_player();
	string name = "";
	int count = 0;
	string now=ctime(time());
	sscanf(arg,"%s %d",name,count);
	if(me->vice_skills["caikuang"] == 0)
		s += "�㲻��ɿ���\n";
	else{
		object env = environment(this_player());
		object ob=present(name,env,count);
		//�ɿ��ʹӰ����ʧ
		if(me->hind == 1)
			me->hind = 0;
		if(me->query_buff("spec",0) == "hind"){
			me->clean_buff("spec");
			m_delete(me["/danyao"],"spec");
		}
		if(ob){
			if(me->if_over_load(ob)){
				s += "��������Ʒ�������޷��ٴ�Ÿ���Ķ���\n\n";
			}
			else{
				array(int) skill = me->vice_skills["caikuang"];
				int need_lev = KUANGD->query_need_level(name);
				if(need_lev < 0)
					s += "�˿���Ӱ��Χ�ƣ��ƺ������ھ�\n";
				else{
					int now_lev = (int)skill[0];
					//int now_count = (int)skill[1];
					if(now_lev < need_lev){
						s += "ʧ�ܣ�\n";
						s += "��Ҫ�ɿ���������"+need_lev+"�����ھ�"+ob->query_name_cn()+"\n";
					}
					else{
						string for_log = "";
						mapping(string:int) get_m = KUANGD->query_get_m(name);
						if(sizeof(get_m) > 0){
							foreach(indices(get_m),string get_name){
								int prob = get_m[get_name];
								if(prob == 100){
									object get_ob = clone(ITEM_PATH_KUANG+get_name);
									if(get_ob){
										int num = random(3)+1;
										s += "������"+num+"��"+get_ob->query_name_cn()+"\n";
										for_log += "�����"+num+"��"+get_ob->query_name_cn();
										get_ob->amount = num;
										get_ob->move_player(me->query_name());
									}
									else
										s += "��ʯͻȻ��ʧ��һƬ������......\n";
								}
								else{
									if((random(100)+1)<prob){
										object get_ob = clone(ITEM_PATH_KUANG+get_name);
										if(get_ob){
											s += "������һ��"+get_ob->query_name_cn()+"\n";
											for_log += "��һ��"+get_ob->query_name_cn();
											get_ob->amount = 1;
											get_ob->move_player(me->query_name());
										}
										else
											s += "��ʯͻȻ��ʧ��һƬ������......\n";
									}
								}
							}
							if(for_log != "")
								Stdio.append_file(ROOT+"/log/caikuang.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")��"+for_log+"\n");
							ob->remove();
							//������Ҫˢ�´˿������
							string room = ROOMLEVELD->query_room_quick(env->query_name());
							KUANGD->set_flush_num(name,room);
							//����������Ƿ�����
							if(now_lev < skill[2]){
								int update_need = (int)(now_lev/5);
								skill[1]++;
								if(skill[1]>=update_need){
									skill[0]++;
									skill[1]=0;
									s += "��Ĳɿ���������ߵ���"+(now_lev+1)+"��\n";
								}
							}
						}
					}
				}
			}
		}
		else
			s += "�ÿ��ѱ���������!\n";
	}
	s += "\n[����:look]\n";
	write(s);
	return 1;
}
