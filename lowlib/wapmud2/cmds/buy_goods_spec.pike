#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string s = "";
	object ob,me = this_player();
	//�ж�������Ʒ�Ƿ񳬹�60��
	/*
	if(me->if_over_load()){
		string tmp = "��ı����������޷�ִ�д˲������뷵�ء�\n";       
		tmp+="[����:look]\n";
		write(tmp);
		return 1;
	}
	*/
	if(arg){
		string name;
		int fee;
		sscanf(arg,"%s %d",name, fee);
		ob=clone(ROOT+"/gamelib/clone/item/"+name);
		//ֻ����һ��
		if(!ob){
			s += "��Ҫ�������Ʒ�����ڣ��뷵�ء�\n";	
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}
	
		if(me->if_over_load(ob)){
			s = "��ı����������޷�ִ�д˲������뷵�ء�\n";       
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
			return 1;
		}

		int need_money = fee;
		if(me->pay_money(need_money)==0){
			s += "�����ϵ�Ǯ����֧�����ã��뷵�ء�\n";
			this_player()->write_view(WAP_VIEWD["/emote"],0,0,s);
		}
		else{
			s += "���׳ɹ���\n�㻨��"+MUD_MONEYD->query_store_money_cn(need_money)+"\n";
			s += "�õ�����Ʒ "+ob->query_name_cn()+"��\n";
			if(ob->is("combine_item"))
				ob->move_player(me->query_name());
			else
				ob->move(me);
			
			string now=ctime(time());
			string tmp = now[0..sizeof(now)-2]+":"+me->name_cn+"("+me->name+")\n";
			tmp += s;
			Stdio.append_file(ROOT+"/log/buy.log",tmp+"\n");
			s+="[������Ϸ:look]\n";
			write(s);
		}
	}
	
	return 1;
}


