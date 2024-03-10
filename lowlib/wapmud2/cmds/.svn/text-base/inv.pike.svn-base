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
				s += "对应"+ob->query_color_cn(ob->query_color())+"凹槽\n";
				s += ob->query_content()+"\n";
				s += "[摧毁:drop "+ob->query_name()+" "+count+"]\n";
				s += "[返回:inventory]\n";
				s += "[返回游戏:look]\n";
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
					s+="要求职业："+ob->profe_read_limit+"\n";
				if(ob->level_limit && sizeof(ob->query_peifang_type()) == 0)
					s+="要求等级："+ob->level_limit+"\n";
				if(sizeof(ob->query_peifang_type()) > 0){
					string type = "";
					if(ob->query_peifang_kind() == "liandan")
						type = "炼丹";                                  
					else if(ob->query_peifang_kind() == "caifeng")          
						type = "裁缝";                                  
					else if(ob->query_peifang_kind() == "zhijia")           
						type = "制甲";                                  
					else if(ob->query_peifang_kind() == "duanzao")          
						type = "锻造";
					s+="要求"+type+"熟练度："+ob->viceskill_level+"\n";
				}
				s += ob->query_inventory_links(count)+"\n"; 
				s += "[摧毁:drop "+ob->query_name()+" "+count+"]\n";
				s += "[返回:inventory]\n";
				s += "[返回游戏:look]\n";
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
