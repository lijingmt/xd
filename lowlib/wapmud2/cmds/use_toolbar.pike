#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	int num = (int)arg;
	int have = 0;
	object me = this_player();

	if(random(100)<90){
		if(!me["/tmp/atk_ctime"])
			me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
		else{
			if( ((System.Time()->usec_full)/1000 - me["/tmp/atk_ctime"]) <= 1500 ){
				//werror("-------- player["+me->name+"] use_toolbar difftime<=1000 --------\n");
				if(!me["/tmp/wg_times"]) me["/tmp/wg_times"] = 1;
				else me["/tmp/wg_times"]++;
			}
			else{
				me["/tmp/atk_ctime"] = (System.Time()->usec_full)/1000;
			}
		}
	}

	
	
	mapping(string:int) tmp = me->query_toolbar(num);	
	string tmp_name = "";
	foreach(indices(tmp),string key){
		tmp_name = key;
		break;
	}
	if(tmp_name == "none" || tmp_name == "" )
		tell_object(me,"�㲢δ���ÿ�ݼ�"+(num+1)+"\n");
	else{
		if(me->in_combat){
			if(tmp[tmp_name]==1){
				//�����õ��Ǽ���
				me->perform(tmp_name);
				me->reset_view(WAP_VIEWD["/fight"]);
				me->write_view();
				return 1;
			}
			else if(tmp[tmp_name]==2){
				if(me->eat_timeCold == 0){
					//�����õ���ʳ��
					array(object) items=all_inventory(me); 
					if(items&&sizeof(items)){
						foreach(items,object item){
							if(tmp_name == item->query_name()){
								string item_name = item->query_name_cn();
								int drk = item->eat();
								switch(drk){
									case 0:
										tell_object(me,"��ĵȼ�����������ʳ�� "+item_name+" ��\n");	
										break;
									case 1:
										tell_object(me,"��ʳ���� "+item_name+" ��\n");
										me->eat_timeCold = 20;
										have = 1;
										break;
									case 2:
										tell_object(me,"���ְҵ����ʳ�ø���Ʒ��\n");
										break;
									case 3:
										tell_object(me,"�����Ӫ����ʳ�ø���Ʒ��\n");
										break;
									case 4:
										tell_object(me,"��Ҫʳ��ʲô��Ʒ��\n");
										break;
									case 5:
										tell_object(me,"�����ڵ�״̬����ʳ�ø���Ʒ��\n");
										break;
									case 11:
										tell_object(me,"���Ѿ������������ޣ�����ʳ�ø���Ʒ��\n");
										break;
									case 22:
										tell_object(me,"���Ѿ����﷨�����ޣ��������ø���Ʒ��\n");
										break;
								}
								break;
							}
						}
					}
					if(!have)
						tell_object(me,"���Ѿ������˴���Ʒ\n");
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 2;
				}
				else{
					tell_object(me,"����"+me->eat_timeCold+"�����ʳ��\n");	
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 0;
				}
			}
			else if(tmp[tmp_name]==3){
				//�����õ���ˮ
				if(me->eat_timeCold == 0){
					array(object) items=all_inventory(me); 
					if(items&&sizeof(items)){
						foreach(items,object item){
							if(tmp_name == item->query_name()){
								string item_name = item->query_name_cn();
								int drk = item->drink();
								switch(drk){
									case 0:
										tell_object(me,"��ĵȼ��������������� "+item_name+" ��\n");	
										break;
									case 1:
										tell_object(me,"�������� "+item_name+" ��\n");
										me->eat_timeCold = 20;
										have = 1;
										break;
									case 2:
										tell_object(me,"���ְҵ�������ø���Ʒ��\n");
										break;
									case 3:
										tell_object(me,"�����Ӫ�������ø���Ʒ��\n");
										break;
									case 4:
										tell_object(me,"��Ҫ����ʲô��Ʒ��\n");
										break;
									case 5:
										tell_object(me,"�����ڵ�״̬�������ø���Ʒ��\n");
										break;
									case 11:
										tell_object(me,"���Ѿ������������ޣ�����ʳ�ø���Ʒ��\n");
										break;
									case 22:
										tell_object(me,"���Ѿ����﷨�����ޣ��������ø���Ʒ��\n");
										break;
								}
								break;
							}
						}
					}
					if(!have)
						tell_object(me,"���Ѿ������˴���Ʒ\n");
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 3;
				}
				else{
					tell_object(me,"����"+me->eat_timeCold+"���������\n");	
					me->reset_view(WAP_VIEWD["/fight"]);
					me->write_view();
					return 0;
				}
			}
		}
		else{
			me->reset_view(WAP_VIEWD["/look"]);
			me->write_view();
			return 0;
		}
	}
	return 0;
}
