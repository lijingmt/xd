#include <command.h>
#include <gamelib/include/gamelib.h>
#define HONER ROOT "/gamelib/clone/item/honer/"
//arg = type name flag
// typeΪ"duanzao" or "liandan" ;nameΪ�䷽�ļ�; flagΪ0��ʾ�쿴��Ϊ1��ʾ����
int main(string arg)
{
	string s = "������������������\n";
	object me=this_player();
	string filename = "";
	string need_name = "";//�һ���Ҫ��Ʒ������
	int need_num = 0;//�һ���Ҫ��Ʒ������
	string type = "";
	int flag = 0;
	string producer_info = "";
	sscanf(arg,"%s %s %s %d %d",type,filename,need_name,need_num,flag);
	object ob;
	ob = clone(HONER+filename);
	object need_ob = clone(ITEM_PATH+"bossdrop/"+need_name);
	if(ob){
		int need_honer = ob->query_need_honer();
		string race;
		if(flag == 0){
			s += ob->query_name_cn()+"\n";
			s += ob->query_picture_url()+"\n"+ob->query_desc()+"\n"+ob->query_content()+"\n";
			if(me->query_raceId() == "human")
				race = "����";
			else if(me->query_raceId() == "monst")
				race = "����";
			s += "��Ҫ"+race+"��"+need_honer+"\n";
			if(need_num>0){
				s += "��Ҫ"+need_ob->query_name_cn()+":"+need_num+"��\n";
			}
			s +="--------\n";
			s += "[��ȡ:honer_buy "+type+" "+filename+" "+need_name+" "+need_num+" 1]\n";
		}
		else if(flag == 1){
			if(me->honerpt<need_honer)
				s += "�������ֵ����\n";
			else{
				if(need_num>0){
					array(object) all_ob =all_inventory(me);
					int have_duihuan_item = 0;
					foreach(all_ob,object ob){
						if(ob->is_combine_item()&&ob->query_name()==need_name){
							have_duihuan_item += ob->amount;
						}
					}
					if(have_duihuan_item<need_num){
						s += "��û���㹻��"+need_ob->query_name_cn()+"\n";
						s += "\n[����:honer_equip_view "+type+"]\n";
						s += "[������Ϸ:look]\n";
						write(s);
						return 1;
					}
					else{
						me->remove_combine_item(need_name,need_num);
					}
				}
				me->honerpt -= need_honer;
				s += "������"+ob->query_name_cn()+"\n";
				ob->move(me);
			}
		}
	}
	else 
		s += "û����������Ʒ\n";
	//me->write_view(WAP_VIEWD["/emote"],0,0,s);
	s += "\n[����:honer_equip_view "+type+"]\n";
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
