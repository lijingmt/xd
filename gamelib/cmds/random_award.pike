#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg){
	object me=this_player();
	string s = "";
	int num;
	sscanf(arg,"%d",num);
	if(arg==0){
		me->reset_view(WAP_VIEWD["/modal_award"]);
		me->write_view();
		return 1;
	}
	else{
		//����Ǻ��˹����Ĳ��������أ�����ˢ
		if(me["/plus/random_rcd"]==1){
			if((int)me["/tmp/rd_tmp3"]==num){
				//�������������ȷ�ˣ�������....ò��ҵ���߼����ԣ�ȡ��������ֻҪ�������10�����������ߣ������ô���������������ߵ�����
				me["/tmp/wrong_rd"] = 1; //���ô��� //1.����10���Ӻ������� 2.�ش���ȷ 3.���η�
				me["/plus/random_rcd"] = 0;//��ȷ����ˣ���Ϊ0
				me["/plus/random_award"]--;
				me["/tmp/wg_times"]=0;//attack/use_perform����״̬����
				if(me["/plus/random_award"]<=0) me["/plus/random_award"] = 0;//�����������--��ֱ��Ϊ0���ٳ���
				s += "������Ĵ� "+ arg +" ��ȫ��ȷ����ñ��εĽ������£�\n";
				s += get_random_award(me);
				me["/tmp/random_ctime"] = (System.Time()->usec_full)/1000000;//�Թ�/��������Ĵ���ʱ��������
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else{
				//�����������������󳬹�10�Σ�֤���������ٷ��ƽ⣬���Լ����ʶ�����߹������
				if(!me["/tmp/wrong_rd"]) me["/tmp/wrong_rd"] = 1;
				else me["/tmp/wrong_rd"]++;
				//���ӵ�һ��ֵʱ����һ�����ʽ������Ρ�
				if(me["/tmp/wrong_rd"]<=1)
				{
					tell_object(me,"<font style=\"color:red; font-size:x-large;\">����г���һ�������Ц��������</font>\n");
					werror("!! warning 1 !!! random_award --> wrong_rd player=["+me->name+"] wrong times=["+me["/tmp/wrong_rd"]+"]\n");
				}
				else if(me["/tmp/wrong_rd"]<=2){
					tell_object(me,"<font style=\"color:red; font-size:x-large;\">��Χ�𽥿�ʼ��úڰ�������һ�������ĵͺ������˷�Χ�˹���������</font>\n");
					werror("!! warning 2 !!! random_award --> wrong_rd player=["+me->name+"] wrong times=["+me["/tmp/wrong_rd"]+"]\n");
				}
				else{
					tell_object(me,"<font style=\"color:red; font-size:x-large;\">������һ�ڣ����˹�ȥ������</font>\n");
					me["/tmp/wrong_rd"] = 1; //���ô��� //�����������10���Ӻ�������
					me["/plus/random_rcd"] = 0;//����ˣ���Ϊ0
					me->unconscious();//��Ϊ�ε�һ��ʱ��
					me["/tmp/wg_times"]=50+random(50);//����������������̣�����״̬��Ϊ60�����û��ٴδ���
					//me->jailTime=10;//61�����䣬1/300������������ڣ�Ȼ��jailTime--��ֱ��<=0���ܿ�������                                                                      
					//me->move(ROOT+"gamenv/d/chtianlao/chtianlao1");                                           
					//me->command("look");
					werror("!! done!! random_award --> wrong yanzheng num player=["+me->name+"] wg_times=["+me["/tmp/wg_times"]+"] call unconscious()...\n");
					return 1;
				}
				tell_object(me,"������Ĵ𰸴���������������ȷ��\n\n");
				me->reset_view(WAP_VIEWD["/modal_award"]);
				me->write_view();
				return 1;
			}
		}
		else{
			s += "���ո��Ѿ���ȡ�������ˣ��뷵��\n";
			s += "[������Ϸ:look]\n";
			write(s);
			return 1;
		}
	}
	return 1;
}
string get_random_award(object me){
	string rtn = "";
	//object item = ITEMD->get_worlddrop_item(dh_year);
	object item = ITEMSD->get_item(me->query_level(), me->query_level(), me->query_lunck());
	if(item){
		string iname = item->name;
		item->move(me);	
		rtn += "������ "+item->name_cn+" !!!\n";
		//log��¼
		string record_s = "";
		string now=ctime(time());
		record_s += now[0..sizeof(now)-2]+"|";
		record_s += "uid:"+me->name+"|name:"+me->name_cn+"|type: award|";
		record_s += "get item:"+iname+"|";
		record_s += "\n";
		Stdio.append_file(ROOT+"/log/random_award.log",record_s);
	}
	else{
		int m_low = me->query_level()*10-(int)(me->query_level());
		int m_high = me->query_level()*10+(int)(me->query_level());
		int g_m = m_low + random(m_high-m_low+1);
		g_m = g_m/2;
		if(g_m<=0) g_m = 1;
		me->add_account(g_m);
		rtn += "������ "+MUD_MONEYD->query_other_money_cn(g_m)+" !!!\n";
		//log��¼
		string record_s2 = "";
		string now2=ctime(time());
		record_s2 += now2[0..sizeof(now2)-2]+"|";
		record_s2 += "uid:"+me->name+"|name:"+me->name_cn+"|type: award";
		record_s2 += " money:"+g_m+"|";
		record_s2 += "\n";
		Stdio.append_file(ROOT+"/log/random_award.log",record_s2);
	}
	return rtn;
}
