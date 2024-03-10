#include <command.h>
#include <wapmud2/include/wapmud2.h>
int main(string arg)
{
	string name=arg;
	string s = "";
	int count;
	sscanf(arg,"%s %d",name,count);
	object ob=present(name,this_player(),count);
	if(ob){
		if(ob->is("equip")){
			if(ob->query_item_type()=="baoshi"){
				s += ob->query_short()+"\n";
				s += ob->query_picture_url()+"\n";
				s += "��Ӧ"+ob->query_color_cn(ob->query_color())+"����\n";
				s += ob->query_content()+"\n";
				s += "[�ݻ�:drop "+ob->query_name()+" "+count+"]\n";
				s += "[����:inventory]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else 
				this_player()->write_view(WAP_VIEWD["/inv_equip"],ob,this_player(),count);
		}
		else{
			if(ob->query_item_type()=="book"){
				s += ob->query_short()+"\n";
				s += ob->query_picture_url()+"\n"; 
				s += ob->query_desc()+"\n"; 
				if(sizeof(ob->profe_read_limit)>0)
					s+="Ҫ��ְҵ��"+ob->profe_read_limit+"\n";
				if(ob->level_limit && sizeof(ob->query_peifang_type()) == 0)
					s+="Ҫ��ȼ���"+ob->level_limit+"\n";
				if(sizeof(ob->query_peifang_type()) > 0){
					string type = "";
					if(ob->query_peifang_kind() == "liandan")
						type = "����";                                  
					else if(ob->query_peifang_kind() == "caifeng")          
						type = "�÷�";                                  
					else if(ob->query_peifang_kind() == "zhijia")           
						type = "�Ƽ�";                                  
					else if(ob->query_peifang_kind() == "duanzao")          
						type = "����";
					s+="Ҫ��"+type+"�����ȣ�"+ob->viceskill_level+"\n";
				}
				s += ob->query_inventory_links(count)+"\n"; 
				s += "[�ݻ�:drop "+ob->query_name()+" "+count+"]\n";
				s += "[����:inventory]\n";
				s += "[������Ϸ:look]\n";
				write(s);
				return 1;
			}
			else
				this_player()->write_view(WAP_VIEWD["/inv"],ob,this_player(),count);
		}
	}
	else{
		this_player()->write_view(WAP_VIEWD["/inv_notfound"],ob);
	}
	return 1;
}
