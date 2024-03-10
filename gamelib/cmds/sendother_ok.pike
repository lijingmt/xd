#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string s = "";
	string user_name;
	int user_count;
	string goods_id;
	string type;
	object player=this_player();
	object goods;
	if(sscanf(arg,"%s %d %s %s",user_name,user_count,goods_id,type)==4){
		object ob=present(user_name,environment(player));
		if(!ob)
	    		ob=find_player(user_name);
		if(!ob){
			s += "Ҫ������Ʒ�������Ŀǰ�����ߣ��뷵�ء�\n";
			s += "[����:look]\n";
			write(s);
			return 1;
		}
		else{
			//goods=present(goods_id,ob,user_count); 
			//�������������nameͬ���ķǻ�Ա��Ʒ added by caijie 080815
			array(object) all_ob = all_inventory(ob);
			foreach(all_ob,object each_ob){
				if(each_ob->query_name()==goods_id&&(!each_ob->query_toVip())){
					goods = each_ob;
					break;
				}
			}
			//add end
			int item_totalnum_now = inventory_item_num(goods_id,ob);
			if(goods){
				int is_send = is_send(goods_id,ob);
				if(goods->equiped){
					s += "����Ʒ����װ�����޷����ͣ��뷵��ȷ�ϡ�\n";
					s += "[������Ϸ:look]\n";
					write(s);
					return 1;
				}
				else if(!is_send)
				{
					s += "�Է�û�з��͸���Ʒ���㣬�뷵�ء�\n";
					s += "[������Ϸ:look]\n";
					write(s);
					return 1;
				}
				else{
					if(type=="yes"){
						//�ж�������Ʒ�Ƿ񳬹�60��
						if(this_player()->if_over_load(goods)){
							string tmp = "��ı�����װ�����޷�ִ�д˲������뷵�ء�\n";       
							tmp+="[����:look]\n";
							write(tmp);
							return 1;
						}
						tell_object(player,"�ɹ�������Ʒ"+goods->name_cn+"\n");
						tell_object(ob,"��Ʒ"+goods->name_cn+"�Ѿ��ɹ����͸�"+player->name_cn+"\n");
						string now=ctime(time());
						object env = environment(player);
						int goods_num=1;
						if(goods->is("combine_item"))
							goods_num = goods->amount;
						Stdio.append_file(ROOT+"/log/send.log",now[0..sizeof(now)-2]+":"+ob->name_cn+"("+ob->name+") ��"+env->query_name_cn()+" send ("+goods_num+")"+goods->name_cn+"("+goods->name+") to "+player->name_cn+"("+player->name+")\n");
						if(goods->is("combine_item"))
							goods->move_player(player->query_name());
						else
							goods->move(player);
						s += "[������Ϸ:look]\n";
						write(s);
						return 1;
					}
					else{
						tell_object(player,"��ܾ���"+ob->name_cn+"���͸������Ʒ"+goods->name_cn+"\n");
						tell_object(ob,player->name_cn+"�ܾ�������Ʒ"+goods->name_cn+"\n");
						s += "[������Ϸ:look]\n";
						write(s);
						return 1;
					}
				}
			}
			else
				s += "����Ʒ�����ڣ��뷵��ȷ�ϡ�\n";
		}
	}
	s += "[������Ϸ:look]\n";
	write(s);
	return 1;
}
int inventory_item_num(string item_name,void|object looker)
{
	int num =0;
	if(!looker)
		looker=this_player();
	array(object) a = all_inventory(looker);                                                                              
	foreach(a,object tmp)
	{
		if(tmp&&tmp->query_name()==item_name)
			num++;
	}
	return num;
}
//��ѯ�������Ƿ�����ĳ����Ʒ����ǰ���
//�ڲ�ѯ��Ϻ�ɾ�����ͱ�ʶ
//���ز���  0:û�з�������
//          >0: �з�������
int is_send(string item_name,object sender)
{
	object me = this_player();
	if(!sender["/plus/sendrecd"])	
		return 0;
	if(!sender["/plus/sendrecd"][me->name])
		return 0;
	if(!sender["/plus/sendrecd"][me->name][item_name])
	{
		m_delete(sender["/plus/sendrecd"][me->name],item_name);		
		return 0;
	}
	else
	{
		int retInt = sender["/plus/sendrecd"][me->name][item_name];	
		sender["/plus/sendrecd"][me->name][item_name]--;	
		if(!sender["/plus/sendrecd"][me->name][item_name])
			m_delete(sender["/plus/sendrecd"][me->name],item_name);		
		return retInt;
	}
}
