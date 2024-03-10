#include <command.h>
#include <gamelib/include/gamelib.h>
//arg = name flag 
//      name ΪĿ�����id
//      flag=0 ֻ�ǲ쿴��=1ʱҪ��ʾ��������Ϣ��=2ʱҪ��ʾ��������Ϣ��=3ʱҪ��ʾ��������Ϣ
int main(string arg)
{
	object me = this_player();
	string s = "";
	string target_name = "";
	int flag = 0;
	int level = 0;
	sscanf(arg,"%s %d",target_name,flag);
	if(!me->bangid){
		s = "��δ�����κΰ���\n";
	}
	else{
		string bang_name = BANGD->query_bang_name(me->bangid);
		s += "<"+bang_name+">:";
		s += BANGD->query_level_cn(me->query_name(),me->bangid)+"\n";
		level = BANGD->query_level(me->query_name(),me->bangid);
		s += BANGD->query_nums(me->bangid,"online")+"����/"+BANGD->query_nums(me->bangid,"all")+"��\n";
		//����
		if(flag == 1){
			int rmflag = 0;
			string target_namecn = "";
			object target = find_player(target_name);
			if(target)
				target_namecn = target->query_name_cn();
			else{
				target = me->load_player(target_name);
				if(target){
					target_namecn = target->query_name_cn();
					rmflag = 1;
				}
			}
			int update = BANGD->update_level(me,target_name,me->bangid);
			//update_level()�ķ���ֵ=0:�����������Է��ȼ�
			//                      =1:�����ɹ�
			//                      =2:û�б������ĳ�Ա
			//                      =3:������Щ����
			if(update == 0)
				tell_object(me,"���Ѳ����������Է��ȼ�\n");
			else if(update == 1){
				string tell_s = me->query_name_cn()+"��"+target_namecn+"����Ϊ��"+BANGD->query_level_cn(target_name,me->bangid)+"\n";
				BANGD->bang_notice(me->bangid,tell_s);
			}
			else if(update == 2){
				tell_object(me,"�Է��Ѿ����ڰ�������\n");
				if(target->bangid == me->bangid)
					target->bangid = 0;
			}
			else if(update == 3){
				tell_object(me,"��ȷ�������ڵİ��ɻ�����\n");
				me->bangid=0;	
				target->bangid=0;
			}
			if(rmflag)
				target->remove();
		}
		//����
		else if(flag == 2){
			int rmflag = 0;
			string target_namecn = "";
			object target = find_player(target_name);
			if(target)
				target_namecn = target->query_name_cn();
			else{
				target = me->load_player(target_name);
				if(target){
					target_namecn = target->query_name_cn();
					rmflag = 1;
				}
			}
			int down = BANGD->down_level(me,target_name,me->bangid);
			//down_level()�ķ���ֵ  =0:�Ѳ����ٽ��ͶԷ��ȼ�
			//                      =1:�����ɹ�
			//                      =2:û�б������ĳ�Ա
			//                      =3:������Щ����
			if(down == 0)
				tell_object(me,"Ȩ�޲������㲻�ܽ��ͶԷ��ȼ�\n");
			else if(down == 1){
				string tell_s = me->query_name_cn()+"��"+target_namecn+"����Ϊ��"+BANGD->query_level_cn(target_name,me->bangid)+"\n";
				BANGD->bang_notice(me->bangid,tell_s);
			}
			else if(down == 2){
				tell_object(me,"�Է��Ѿ����ڰ�������\n");
				if(target->bangid == me->bangid)
					target->bangid = 0;
			}
			else if(down == 3){
				tell_object(me,"��ȷ�������ڵİ��ɻ�����\n");
				me->bangid=0;	
				target->bangid=0;
			}
			if(rmflag)
				target->remove();
		}
		//����
		else if(flag == 3){
			string target_namecn = "";
			object target = find_player(target_name);
			int removeflag = 0;
			if(target)
				target_namecn = target->query_name_cn();
			else{
				target = me->load_player(target_name);
				if(target){
					target_namecn = target->query_name_cn();
					removeflag = 1;
				}
			}
			int fire = BANGD->fire_member(me,target_name,me->bangid);
			//fire_member()�ķ���ֵ =0:Ȩ�޲������޷�����
			//                      =1:�ɹ�����
			//                      =2:û�������Ա
			//                      =3:������Щ����
			if(fire == 0)
				tell_object(me,"Ȩ�޲������㲻�ܿ����Է�\n");
			else if(fire == 1){
				string tell_s = me->query_name_cn()+"��"+target_namecn+"�������˰���\n";
				tell_object(target,"�㱻�������˰���\n");
				target->bangid = 0;
				BANGD->bang_notice(me->bangid,tell_s);
			}
			else if(fire == 2){
				tell_object(me,"�Է��Ѿ����ڰ�������\n");
				if(target->bangid == me->bangid)
					target->bangid = 0;
			}
			else if(fire == 3){
				tell_object(me,"��ȷ�������ڵİ��ɻ�����\n");
				me->bangid=0;	
				target->bangid=0;
			}
			if(removeflag)
				target->remove();
		}
		s += BANGD->query_bang_members(me,me->bangid,level)+"\n"; 
	}
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	//s += "[����:my_bang]\n";
	//s += "[������Ϸ:look]\n";
	//write(s);
	return 1;
}
