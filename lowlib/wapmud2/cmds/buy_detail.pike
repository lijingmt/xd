#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	if(!name)
	{
		string s = "";
		s+= "û�������Ʒ\n";
		s+="[����:list]\n";
		s+="[������Ϸ:look]\n";
		write(s);
	}
	object ob=clone(ROOT+"/gamelib/clone/item/"+name);
	if(ob){
		string s=ob->query_name_cn()+"\n";
		s+=ob->query_picture_url()+"\n";
		if(ob->query_item_type()!="book")
			s+=ob->query_content();
		s+=ob->query_desc();
		s+="[ȷ������:buy_goods "+name+"]\n";
		//s+="��������һ�ι���"+ob->query_name_cn()+"����Ŀ����Χһ����ʮ��[int:buy_lots_goods "+name+" ...]\n";
		s+="[����:list]\n";
		s+="[������Ϸ:look]\n";
		write(s);
	}
	else{
		string s = "";
		s+= "û�������Ʒ\n";
		s+="[����:items]\n";
		s+="[������Ϸ:look]\n";
		write(s);
	}
	return 1;
}
