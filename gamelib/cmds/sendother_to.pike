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
	if(sscanf(arg,"%s %s %d",user_name,goods_id,user_count)==3){
		object ob=present(user_name,environment(player));
		if(!ob)
	    		ob=find_player(user_name);
		if(!ob){
			s += "��Ҫ������Ʒ���˲�������뷵�ء�\n";	
			s += "[����:look]\n";
			write(s);
			return 1;
		}
		else{
			//goods=present(goods_id,player,user_count); //[sb] is seller
			//�������������nameͬ���ķǻ�Ա��Ʒ added by caijie 080815
			array(object) all_ob = all_inventory(player);
			foreach(all_ob,object each_ob){
				if(each_ob->query_name()==goods_id&&(!each_ob->query_toVip())){
					goods = each_ob;
					break;
				}
			}
			//add end
			if(goods&&goods->query_item_canSend()==0){
				s += "����Ʒ�������ͣ��뷵�ء�\n";
				s += "[����:look]\n";
				write(s);
				return 1;
			}
			else if(goods&&!goods->equiped){
				//sendother 
				tell_object(ob,player->name_cn+"�����͸���"+goods->query_short()+"\n[����:sendother_ok "+player->name+" "+user_count+" " +goods->name+" yes]\n[�ܾ�:sendother_ok "+player->name+" "+user_count+" "+goods->name+" no]\n");
				if(!player["/plus/sendrecd"])
					player["/plus/sendrecd"]= ([]);
				if(!player["/plus/sendrecd"][ob->name])
					player["/plus/sendrecd"][ob->name] = ([]);
				player["/plus/sendrecd"][ob->name][goods->name]++;
				s += "���������Ѿ���������ȴ��Է�ȷ�Ͻ��ܡ�\n";
			}
			else{
				s += "�����ϲ�û��Ҫ���͵���Ʒ�����߸���Ʒ����װ�����޷����ͣ��뷵��ȷ�ϡ�\n";
			}
			s += "[����:look]\n";
			write(s);
			return 1;
		}
	}
	s += "��Ҫ����ʲô�������Է���\n";
	s += "[����:look]\n";
	write(s);
	return 1;
}
