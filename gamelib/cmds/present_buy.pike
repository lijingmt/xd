//��Ϊ�û��ֹ�����Ʒ��ָ��
#include <command.h>
#include <gamelib/include/gamelib.h>
#define ITEM ROOT "/gamelib/clone/item/"
#define log_file ROOT "/log/presenter.log" 
//arg = type name mark_need money num flag
//nameΪ�ļ�; flagΪ0��ʾ�쿴��Ϊ1��ʾ����
int main(string arg)
{
	string s = "�������\n";
	object me=this_player();
	string filename = "";
	string type = "";
	int mark_need = 0;
	int money = 0;
	int num = 0;
	int flag = 0;
	string producer_info = "";
	sscanf(arg,"%s %s %d %d %d %d",type,filename,mark_need,money,num,flag);
	object ob;
	mixed err=catch{
		ob = clone(ITEM+filename);
	};
	if(!err && ob){
		if(flag == 0){
			s += ob->query_name_cn()+"\n";
			s += ob->query_picture_url()+"\n"+ob->query_desc()+"\n"/*+ob->query_content()+"\n"*/;
			s += "��Ҫ���֣�"+mark_need+"��\n";
			if(money){
				string m_s = MUD_MONEYD->query_other_money_cn(money); 
				s += "��Ҫ��Ǯ��"+m_s+"\n";
			}
			s +="--------\n";
			s += "[�һ�:present_buy "+type+" "+filename+" "+mark_need+" "+money+" "+num+" 1]\n";
		}
		else if(flag == 1){
			if(me->cur_mark<mark_need)
				s += "����ǰ�Ļ��ֲ���\n";
			else if(me->query_account()<money)
				s += "����ǰ��Ǯ����\n";
			else if(me->if_over_load(ob))
				s += "�����ϵİ����������޷���Я������\n";
			else{
				string ob_name = ob->query_name_cn();
				me->cur_mark -= mark_need;
				if(money)
					me->del_account(money);
				if(ob->is_combine_item()){
					ob->amount = num;
					ob->move_player(me->query_name());
				}
				else
					ob->move(me);
				s += "������"+ob_name+"x"+num+"\n";
				string now=ctime(time());
				string log_s = me->query_name_cn()+"("+me->query_name()+")���ĵ�"+mark_need+"����֣���Ϊ�һ���"+ob_name+"x"+num+"\n";
				Stdio.append_file(log_file,now[0..sizeof(now)-2]+":"+log_s);
			}
		}
	}
	else 
		s += "û����������Ʒ\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[����:present_equip_view "+type+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
