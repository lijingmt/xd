#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	if(!this_player()->is("npc")){
		object me = this_player();
		int entry_flag = 0;
		//attack/use_perform��¼����300���������ж��������
		if(me["/tmp/wg_times"]>=100) entry_flag = 1;
		else entry_flag = 0;
		//��Ա����������me->all_fee += fee;//��¼��ҵľ�������
		if(me->all_fee>=1) entry_flag = 0;
		//10�����²�����������Թ�
		if(me->query_level()<=10) entry_flag = 0;
	
		werror("---player["+me->name+"]------ kill call tmp-wg_times=["+me["/tmp/wg_times"]+"]\n");
		
		if(entry_flag==1){
			int ts_num = 0;//!!!!!!!!!!!!!! �������ݣ���ʽ������Ϊ0����
			int add = 0;
			if(random(1000)<1000+ts_num+add){
				if(me["/plus/random_award"]>0){
					//���ܴ�����leave���ⲻ����Ϊ���ȵ���ֹͣս������leave
					if(!me->in_combat){
						if(random(100)<100){
							//1.�����������д��浵�����������ߣ�����leaveʱ��Ҳ�ᴥ��
							me["/plus/random_rcd"] = 1;//��������Ϊ1����ȷ����ˣ���Ϊ0�����������ص�¼Ҳ�ᴥ����֤ǿ�ƽ���
							int t1 = random(10) + 1;
							int t2 = random(10) + 1;
							if(random(100)<30) t1 = random(100)+1;
							if(random(100)<5) t2 = random(100)+1;
							int t3 = t1*t2;
							int c1 = random(10) + 1;
							int c2 = random(10) + 1;
							int d1 = random(10) + 1;
							int d2 = random(10) + 1;
							array tmp1 = ({ 
									"<font style=\"color:red\">"+t1+"</font>"+c1+d1,
									""+c1+"<font style=\"color:red\">"+t1+"</font>"+d1,
									""+c1+""+d1+"<font style=\"color:red\">"+t1+"</font>"
									});
							array tmp2 = ({ 
									"<font style=\"color:red\">"+t2+"</font>"+c2+d2,
									""+c2+"<font style=\"color:red\">"+t2+"</font>"+d2,
									""+c2+""+d2+"<font style=\"color:red\">"+t2+"</font>"
									});
							string s1 = tmp1[random(sizeof(tmp1))]; 
							string s2 = tmp2[random(sizeof(tmp2))];
							me["/tmp/rd_tmp1"] = s1;
							me["/tmp/rd_tmp2"] = s2;
							me["/tmp/rd_tmp3"] = t3;
							tell_object(me,"<font style=\"color:red; font-size:x-large;\">������������ɫ��ͬ������˵Ľ��</font>\n");	
							werror("kill call /tmp/rd_tmp1=["+me["/tmp/rd_tmp1"]+"]\n");
							werror("kill call /tmp/rd_tmp2=["+me["/tmp/rd_tmp2"]+"]\n");
							werror("kill call /tmp/rd_tmp3=["+me["/tmp/rd_tmp3"]+"]\n");
							//////////////////////////////////////////////
							string now=ctime(time());
							string record_s = now[0..sizeof(now)-2]+"|"+me->name+"|"+me->name_cn+"|yanzheng award! left count= ["+me["/plus/random_award"]+"]\n";	
							Stdio.append_file(ROOT+"/log/random_award.log",record_s);
							//////////////////////////////////////////////
							me->reset_view(WAP_VIEWD["/modal_award"]);//����ͼ�����������齱���棬�����������random_award��֤
							me->write_view();
							return 1;
						}
					}
				}
			}
		}
	}
	
	string name=arg;
	int count;
	int flag = 0;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count,this_player());
	if(!ob){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"�㹥����Ŀ�겻���ڣ�\n");
		return 1;
	}
	if(environment(this_player())->is("peaceful")){
		this_player()->write_view(WAP_VIEWD["/fight_peaceful"]);
		return 1;
	}
	//�������޲����ܸ߼���ҵ�ɱ¾����liaocheng��08/01/26���
	if(ob->query_picture()=="nianshou"){
		if(this_player()->query_level() > ob->query_level()+20){
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,"���޿ɲ����ûʤ��ļ�~\n");
			return 1;                                                                                 
		}
	}
	else if(ob&&ob->query_raceId()==this_player()->query_raceId()){
		//��սɱ¾����liaocheng��08/08/30���
		if(ob->bangid && this_player()->bangid && BANGZHAND->is_in_bangzhan(ob->bangid,this_player()->bangid)) 
			flag = 1;
		else{
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,"�㲻�ܹ����Ǹ�Ŀ�꣡\n");
			return 1;
		}
	}
	////////////////////////////////////////////	
	//��Ӫ���ƣ����ܹ����жԵ�ͼ�е����
	object env = environment(ob);
	string map_race = env->room_race;
	//��������Ӫ
	string a_raceid = this_player()->query_raceId();
	//����������Ӫ
	string e_raceid = ob->query_raceId();
	if(a_raceid !=e_raceid &&!ob->is("npc")){
		//�ж��Ƿ�ж���Ӫ��ͼ
		if(map_race!="third" && a_raceid!=map_race){
			if(env->query_room_type() == "city" && ob->red_flag)
				flag = 1;
			else{
				//���಻���ڵж���Ӫ������������
				this_player()->write_view(WAP_VIEWD["/emote"],0,0,"�㲻���ڵж���Ӫ�����Ǹ�Ŀ�꣡\n");
				return 1;
			}
		}
		else{
			if(env->query_room_type() == "city")
				this_player()->red_flag = 1;
			flag = 1;
		}
	}
	if(ob->query_buff("mianzhan",0) != "none"&&env->query_room_type() != "city"){
		this_player()->write_view(WAP_VIEWD["/emote"],0,0,"��ս����ڴˣ������������\n");
		return 1;
	}
	if(ob->is("npc"))
		flag = 1;
	///////////////////////////////////////////////////
	if(flag){
		this_player()->kill(name,count);
		this_player()->reset_view(WAP_VIEWD["/fight"]);
		this_player()->write_view();
		return 1;
	}
	this_player()->write_view(WAP_VIEWD["/emote"],0,0,"��Ҫ�����ĸ�Ŀ�ꣿ\n");
	return 1;
}
