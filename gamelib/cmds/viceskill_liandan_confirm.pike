#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = p_id ������������ 
//��ָ��������������׶Σ������Ƴ���Ʒ
int main(string arg)
{
	string s = "";
	object me=this_player();
	//int p_id = (int)arg;
	int p_id = 0;
	int num = 0;
	string s_num = "";
	sscanf(arg,"%d %s",p_id,s_num);
	sscanf(s_num,"no=%d",num);
	int can_make_num = LIANDAND->can_make_num(me,p_id);
	//ɾ�����ϸ�����Ʒ�Ľӿ�Ϊremove_combine_item(string name,int count),��gamelib/clone/user.pike��
	if(num <= 0 || num > 20){
		s += "���������������ȷ�����������������0С��20\n";
		s += "\n[��������:viceskill_liandan_pf normal]\n";       
        	s += "[������Ϸ:look]\n";
	        write(s);
		 return 1;
	}
	if(sizeof(me->material_m) == 0)
		s += "�㲻�ܽ��������Ĳ�����\n";
	else if(can_make_num == 0 || num > can_make_num)
		s += "��û���㹻�Ĳ��ϣ�\n";
	else{
		//�Ȼ��������Ʒ���ļ���
		string get_name = LIANDAND->query_liandan_item(p_id);
		object get_item = clone(ITEM_PATH+get_name);
		get_item->amount = num;
		if(get_item){
			if(me->if_over_load(get_item))
				s += "��������Ʒ�������޷��ٴ�Ÿ���Ķ���\n\n";
			else{
				//Ȼ���ò��ϸ��������������ɾ������Ҫ�Ĳ���
				mapping(string:array) tmp_m = LIANDAND->query_get_m(p_id);
				foreach(indices(tmp_m),string material_name){
					array tmp_arr = tmp_m[material_name];
					int m_num = tmp_arr[1]*num;//��num��������Ҫ�Ĳ�������
					me->remove_combine_item(material_name,m_num);
				}
				string now=ctime(time());
				array(int) skill = me->vice_skills["liandan"];
				s += "���Ƴɹ�!\n";
				string s_file = file_name(get_item);
				s += "������"+num+"��["+get_item->query_name_cn()+":inv_other "+s_file+"]\n";
				//����������Ƿ�����
				int flag = 0;//��־�����������Ƿ����
				int now_lev = skill[0];
		    	    for(int i=0;i<num;i++){
				if(skill[0]<skill[2]){
					int update_need = (int)(skill[0]/5);
					skill[1]++;
					if(skill[1]>=update_need){
						skill[0] ++;
						skill[1] = 0;
						flag = 1;
					}
				}
			    }	
			    if(flag){
				s += "���������������ߵ���"+(skill[0])+"��\n";
			    }
				me->material_m = ([]);
				Stdio.append_file(ROOT+"/log/liandan.log",now[0..sizeof(now)-2]+":"+me->query_name_cn()+"("+me->query_name()+")��������� "+num+"��"+get_item->query_name_cn()+"\n");
				get_item->move_player(me->query_name());	
			}
		}
		else
			s += "����ʧ��\n";
	}
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[��������:viceskill_liandan_pf normal]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
