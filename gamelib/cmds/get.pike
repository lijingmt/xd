#include <command.h>
#include <gamelib/include/gamelib.h>
int main(string arg)
{
	string name=arg;
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,environment(this_player()),count);
	//�ж�������Ʒ�Ƿ񳬹�60��
	if(ob&&this_player()->if_over_load(ob)){
		string tmp = "��ı����������޷�ִ�д˲������뷵�ء�\n";       
		tmp+="[����:look]\n";
		write(tmp);
		return 1;
	}
	int flag = 0;//ʰȡ״̬��־
	//�Ŷӵ����ʾ��Ʒ״̬ add by calvin 0320
	if(ob&&ob->item_whoCanGet==this_player()->query_term())
		flag = 1;	
	else if(ob&&ob->item_whoCanGet!=this_player()->query_term()){
		if( (time()-ob->item_TimewhoCanGet)>=120 )
			//�Ǵ���װ����ʰȡ���������˱���ʱ�䣬����ʰȡ
			flag = 1;
		else
			flag = 2;//�Ŷӱ�����ʾ
	}
	//�Ŷӵ����ʾ��Ʒ״̬ add by calvin 0320
	
	//���˵�����Ʒ��ʾ�ж�
	if(ob&&ob->item_whoCanGet==this_player()->query_name())
		flag = 1;//�Ǵ���װ�����Լ�ʰȡ��״̬Ϊ1
	else if(ob&&ob->item_whoCanGet!=this_player()->query_name()){
		if( (time()-ob->item_TimewhoCanGet)>=120 )
			//�Ǵ���װ����ʰȡ���������˱���ʱ�䣬����ʰȡ
			flag = 1;
	}
	//����Ǳ���������Ʒ��ֱ�ӿ���ʰȡ
	if(ob&&ob->item_whoCanGet=="1")
		flag = 1;
	//����ֱ��ʰȡ��״̬
	if( ob && !ob->is("npc") && flag==1){
		if(ob->query_item_canGet()==1)
		{
			if(this_player()->query_term()!=""&&this_player()->query_term()!="noterm")
				if(TERMD->query_termId((string)this_player()->query_term()))
					//�Ŷӹ���˭�����ʲô��Ʒ
					TERMD->term_tell(this_player()->query_term(),"\n"+this_player()->query_name_cn()+" ����� "+ob->query_short()+"\n");
			this_player()->write_view_tmp(WAP_VIEWD["/get"],ob);
			string now=ctime(time());
			Stdio.append_file(ROOT+"/log/get.log",now[0..sizeof(now)-2]+":"+this_player()->query_name_cn()+"("+this_player()->query_name()+"):"+ob->name_cn+"("+ob->name+")\n");
			remove_call_out(ob->remove);
			//��ʰȡ�󣬽��ж��ֶ���λ1
			ob->item_whoCanGet="1";
			ob->item_TimewhoCanGet=1;
			if(ob->is("combine_item"))
				ob->move_player(this_player()->query_name());
			else
				ob->move(this_player());
		}
		else
			this_player()->write_view(WAP_VIEWD["/get_inmoveable"],ob);
	}
	else if( ob && !ob->is("npc") && flag==0){
		this_player()->write_view(WAP_VIEWD["/get_protect"],ob);
	}
	else if( ob && !ob->is("npc") && flag==2){
		this_player()->write_view(WAP_VIEWD["/get_term"],ob);
	}
	else
		this_player()->write_view(WAP_VIEWD["/get_notfound"],ob);
	return 1;
}
