#include <command.h>
#include <gamelib/include/gamelib.h>  
//��ָ�������ȡ��Ϸ�ֱ�����͵���Ʒ��
int main(string arg)
{
	string s = "";
	string s_log = "";
	object me=this_player();
	if(arg){
		if(me->get_gift){
			s += "��ȡʧ�ܣ��������Ѿ���ȡ����\n";
		}
		else{
			string gift_name = "";
			array(string) arr = arg/"/";
			if(sizeof(arr)==2)
				gift_name = arr[1];
			else
				gift_name = arg;
			array(object) all_obj = all_inventory(me);
			int have_flg = 0;
			foreach(all_obj,object ob){
				if(ob->query_name()==gift_name){
					have_flg = 1;
					break;
				}
			}
			if(have_flg){
				s += "��ȡʧ�ܣ����������д���Ʒ\n";
			}
			else{
				if(me->if_over_easy_load())
					s += "��ȡʧ�ܣ���������Ʒ����\n";
				else{
					object gift;
					mixed err = catch{
						gift = clone(ITEM_PATH+arg);
					};
					if(gift && !err){
						string now=ctime(time());
						gift->amount = 1;
						s += "��ȡ�ɹ���������"+gift->query_short()+"\n";
						s_log += me->query_name_cn()+"("+me->query_name()+") get "+gift->query_short()+"\n";
						Stdio.append_file(ROOT+"/log/get_gift.log",now[0..sizeof(now)-2]+":"+s_log);
						gift->move_player(me->query_name());
						me->get_gift = 1;
					}
					else
						s += "��Ʒ�����⣬��ͣ��ȡ\n";
				}
			}
		}
	}
	else
		s += "����\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "\n[������Ϸ:look]\n";
	//write(s);
	return 1;
}
