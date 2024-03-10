#include <wapmud2/include/wapmud2.h>
#define PRE_LIST_SIZE 5        //ҳ������ʾ"������xx��xx��xxx����Ʒ"ʱ��"��"ǰ�����Ʒ��Ŀ
//int ite_count;                 //�û�������Ʒ������Ŀ
/*
	���ļ�����Ҫ���������¼��෽����
	��һ���԰���������жϣ����෽������:
	         if_over_easy_load()           //�ж���Ұ�������Ʒ��Ŀ�Ƿ��Ѿ��ﵽ����
		 if_over_load(object ob)       //�ж��ڷ���ob����Ұ�������Ʒ��Ŀ�Ƿ�ᳬ������
                 query_beibao_size()           //��ѯ�û�����������
		 query_cangku_size()           //��ѯ�û��ֿ������
	������չʾ������npc/��Ʒ/��� ����ϸ��Ϣ�����෽���� "view_"Ϊǰ׺������
		 view_items()                  //չʾ ��Ʒ �Ľӿ�
		 view_chars()                  //չʾ ���+npc �Ľӿ�
		 view_chars_npc()              //չʾ npc �Ľӿ�
		 view_chars_player()           //չʾ ��� �Ľӿ�
		 view_something_charact()      //���ķ���һ�������Һ�npc��չʾ
		 view_something_items()        //���ķ������������Ʒ��չʾ
	������չʾ�����е�npc/��Ʒ/��ң����෽���� "have_"Ϊǰ׺��������
	         have_chracter()  //ͬʱչʾnpc����ҵĽӿ�
		 have_npc()       //չʾnpc�Ľӿ�
		 have_player()    //չʾ��ҵĽӿ�
		 have_item()      //չʾ��Ʒ�Ľӿ�
		 have_something   //���ķ�����ʵ�����������з�������Ҫ�Ĺ���
  	���ģ���Ҳ鿴�Լ���Ʒ�ķ��������෽��������
	         
*/



/* 
string view_npc_action(){
	array(object) items=filter(all_inventory(this_object(),this_player()),lambda(object ob){return ob->is("character")&&ob->is("npc");})-({this_player()});
	if(sizeof(items)==0)
		return "";
	object ob=items[random(sizeof(items))];
	if(random(100)>50)
		return ob->query_npc_action();
	return "";
}*/

////////////////////// ================        ���԰���������жϡ�   Start  ===================///////////////////

//�ж����ϼ���Ʒ(һ����ָ������Ʒ)��Ŀ�Ƿ�ﵽ����
int if_over_easy_load(){
	int rst=0;
	array(object) items=all_inventory(this_object());
	if(items&&sizeof(items)){
		int count = sizeof(items);
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
		if(count>=count_max)
			rst = 1;
	}
	return rst;
}

//�жϼ��ϲ����е�ob֮����Ʒ��Ŀ�Ƿ�ﵽ����
int if_over_load(object ob){
	int rst=0;
	array(object) items=all_inventory(this_object());
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(ob->is("combine_item")){
		int count = sizeof(items);
		if(count>=count_max){
			foreach(items, object tmp){
				if(ob->query_name()==tmp->query_name()){
					if((ob->amount+tmp->amount)>ob->max_count){
						rst = 1;
						continue;
					}
					else{
						rst = 0;
						break;
					}
				}
				else
					rst = 1;
			}
		}
	}
	else{
		if(items&&sizeof(items)){
			int count = sizeof(items);
			if(count>=count_max)
				rst = 1;
		}
	}
	return rst;
}
//��ѯ�û����������� added by caijie 08/10/08
int query_beibao_size()
{
	object me = this_object();
	int pac_size = 60;//�����κ�����֮ǰ�������������Ϊ60
	if(!me->package_expand||!me->package_expand["beibao"]){
		return pac_size;
	}
	else if(me->package_expand["beibao"]){
		mapping tmp = me->package_expand["beibao"];
		int pac_num = sizeof(tmp);//��ѯ����������
		if(pac_num){
		//�����䱳��
			array pac_type = indices(tmp);
			for(int i=0;i<pac_num;i++){
				pac_size += pac_type[i]*tmp[pac_type[i]];//����Ϊ���������磺5��10�񣬶�Ӧ��Ԫ��Ϊӵ�иñ����ĸ���
			}
		}
	}
	return pac_size;
}
//��ѯ�û��ر�������� added by caijie 08/10/08 
int query_cangku_size()
{
	object me = this_object();
	int pac_size = me->packageLevel;//�ر���ĳ�ʼ����
	if(!me->package_expand||!me->package_expand["cangku"]){
		return pac_size;
	}
	else if(me->package_expand["cangku"]){
		array tmp = me->package_expand["cangku"];
		int pac_num = sizeof(tmp);//��ѯ����������
		if(pac_num){
		//�����䱳��
			array pac_type = indices(tmp);
			for(int i=0;i<pac_num;i++){
				pac_size += pac_type[i]*tmp[pac_type[i]];//����Ϊ���������磺5��10�񣬶�Ӧ��Ԫ��Ϊӵ�иñ����ĸ���
			}
		}
	}
	return pac_size;
}
////////////////////// ================        ���԰���������жϡ�   End  ===================///////////////////


////////////////////// =========     ��������չʾ������npc/��Ʒ/��� ��ϸ��Ϣ�� Start  =========///////////////////
static private string view_something_items(function filter_func,string list,string arg)
{
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	if(items&&sizeof(items)){
		for(int i=0;i<sizeof(items);i++){
			if(items[i]->query_links()=="")
				out+="["+items[i]->query_short()+":"+arg+" "+items[i]->name+" "+name_count[items[i]->name]+"]\n";
			else
				out+="["+items[i]->query_short()+":"+arg+" "+items[i]->name+" "+name_count[items[i]->name]+"]\n";
			name_count[items[i]->query_name()]++;
		}
	}
	return out;
}
string view_items(){
	string s=view_something_items(lambda(object ob){return ob->is("item");},"item","checkitem");
	if(s=="")
		s="����û���κζ�����\n";
	return s;
}
string view_chars(){
	string s;
	if(this_object()->is("noninteractive"))
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	else
		s=view_something_charact(lambda(object ob){return ob->is("character");},"char");
	if(s=="")
		s="��������û���κ��ˡ�\n";
	return s;
}
string view_chars_npc(){
	string s;
	if(this_object()->is("noninteractive"))
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	else
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	if(s=="")
		s="��������û���κι�\n";
	return s;
}
string view_chars_player(){
	string s;
	if(this_object()->is("noninteractive"))
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc");
	else
		s=view_something_charact(lambda(object ob){return ob->is("character")&&ob->is("player");},"char");
	if(s=="")
		s="��������û���κ��ˡ�\n";
	return s;
}
//�鿴 �ˣ���ҡ�NPC��
static private string view_something_charact(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	if(items&&sizeof(items)){
		out+="(������"+sizeof(items)+" ��)\n"; 
		for(int i=0;i<sizeof(items);i++){
			if(items[i] && items[i]->hind == 0){
					string honerdesc = "";
					string bangname = "";
					if(!items[i]->is("npc")){
						string tmp = WAP_HONERD->query_honer_level_desc(items[i]->honerlv,items[i]->query_raceId());
						if(tmp&&sizeof(tmp))
							honerdesc += "��"+tmp+"��";	
						if(items[i]->bangid)
							bangname += "<"+BANGD->query_bang_name(items[i]->bangid)+">*"+BANGD->query_level_cn(items[i]->query_name(),items[i]->bangid);
					}
					if(items[i]->is("npc"))
						out+=items[i]->query_mini_picture_url()+"["+items[i]->query_short()+":char_npc "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					else
						out+=items[i]->query_mini_user_picture_url()+"["+honerdesc+items[i]->query_short()+bangname+":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
			}
		}
	}
	else
		out+="(������0 ��)\n"; 
	return out;
}
////////////////////// ================        ��չʾ������npc/��Ʒ/��� ��ϸ��Ϣ��   End  ===================///////////////////


////////////////////// ================     (��)��չʾ�����е�npc/��Ʒ/��ҡ�   Start  ===================///////////////////
//չʾ�����е� npc\���\��Ʒ
static private string have_something(function filter_func,string look,string list,string verb_name,string target_name){
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	if(items&&sizeof(items)){
		if(sizeof(items)==1){
			if(items[0]->is("npc"))
				return items[0]->query_mini_picture_url()+verb_name+"["+items[0]->query_short()+":char_npc "+items[0]->query_name()+"]\n";
			else{
				if(items[0]->hind == 0)//��ʱ��������20070523
					return verb_name+items[0]->query_mini_user_picture_url()+"["+items[0]->query_short()+":"+look+" "+items[0]->query_name()+"]\n";
				else 
					return "";
			}
		}
		else{
			string s;
			string pic;
			array(string) a=({});
			for(int i=0;i<sizeof(items)&&i<PRE_LIST_SIZE;i++){
				if(items[i]->hind == 0){
					if(items[i]->is("npc")){
						pic = items[i]->query_mini_picture_url();
					}
					else {
						pic = items[i]->query_mini_user_picture_url();
					}
					//a+=({(pic+"["+items[i]->query_name_cn()+":"+list+"]")});
					a+=({(pic+"["+items[i]->query_short()+":"+list+"]")});
				}
			}
			if(sizeof(items)>PRE_LIST_SIZE)
				s=a*"��"+"��"+target_name;
			else{
				if(sizeof(a)>=2)
					s=a[0..sizeof(a)-2]*"��"+"��"+a[sizeof(a)-1];
				else
					s = a[0];
			}
			return verb_name + s +"\n";
		}
	}
	return "";
}

string have_item(){
	return have_something(lambda(object ob){return ob->is("item");},"item","items","������","��Ʒ");
}
string have_character(){
	return have_npc()+"\n"+have_player();
}
string have_npc(){
	return have_something(lambda(object ob){return ob->is("character")&&ob->is("npc");},"char_npc","chars npc","������","");
}
string have_player(){
	return have_something(lambda(object ob){return ob->is("character")&&ob->is("player");},"char","chars player","��������","���");
}
////////////////////// ================     ��չʾ�����е�npc/��Ʒ/��ҡ�   Start  ===================///////////////////



////////////////////// ================     (��) ����Ҳ鿴�Լ���Ʒ��   Start  ===================///////////////////
// 1���鿴������Ʒ
//�鿴������Ʒ-װ��
string view_inventory_zhuangbei(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="inv";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	if(notShowMoney){
		s=view_something_zhuangbei(lambda(object ob){return ob->is("item");},cmd,showPrice);
	}
	else
		s+=view_something_zhuangbei(objectp,cmd,showPrice);
	if(s=="")
		return "������ʲô����Ҳû�С�\n";
	return  mymoney + myyushi + s;
}
//�鿴������Ʒ-����
string view_inventory_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="inv";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	if(notShowMoney)
		s=view_something_daoju(lambda(object ob){return ob->is("item");},cmd,showPrice);
	else
		s+=view_something_daoju(objectp,cmd,showPrice);
	if(s=="")
		return "������ʲô����Ҳû�С�\n";
	return  mymoney + myyushi + s;
}
//�鿴װ��
static private string view_something_zhuangbei(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;	
					if(items[i]["equiped"]){
						strlist+="��";
						strlist+="["+items[i]->query_short();
						if(showPrice)
							strlist+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							strlist+="("+items[i]->query_item_canLevel()+"��)";
						strlist+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
					else{
						out_no_equip+="["+items[i]->query_short();
						if(showPrice)
							out_no_equip += "("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							out_no_equip += "("+items[i]->query_item_canLevel()+"��)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[װ��("+inv_count+"):inventory]";
		else
			howitem += "װ��("+inv_count+")";
		if(daoju_count)
			howdaoju += "[����("+daoju_count+"):inventory_daoju]";
		else
			howdaoju += "����("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(��Ʒ��0/"+count_max+")\n"; 
	return out+out_no_equip;
}
//�鿴����
static private string view_something_daoju(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		//out+="[װ��:inventory] [����:inventory_daoju]\n";
		for(int i=0;i<sizeof(items);i++){
			if(items[i]){
				//����-װ����Ʒ��������
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//����-��ʳ����Ʒ
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->level_limit*50/4)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				else if(items[i]->query_item_type()=="book"){
					out_no_equip+="["+items[i]->query_short();
					if(items[i]->query_peifang_kind()!="")
					{
						switch(items[i]->query_peifang_kind()){
							case "caifeng":
								out_no_equip+="(�÷�"+items[i]->query_viceskill_level()+")";
							break;
							case "duanzao":
								out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
							break;
							case "liandan":
								out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
							break;
							case "zhijia":
								out_no_equip+="(�Ƽ�"+items[i]->query_viceskill_level()+")";
							break;
							default:
							break;
						}
					}
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//����-һ����Ʒ��������Ʒ��������Ʒ��,�޼۸���ʾ
				else{
					out_no_equip+="["+items[i]->query_short();
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[װ��("+inv_count+"):inventory]";
		else
			howitem += "װ��("+inv_count+")";
		if(daoju_count)
			howdaoju += "[����("+daoju_count+"):inventory_daoju]";
		else
			howdaoju += "����("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n";	
	}
	else
		out+="(��Ʒ��0/"+count_max+")\n";
	return out+out_no_equip;
}




//2������/�洢/���� ��Ʒ�б�
string view_inventory_zhuangbei_sell(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_zhuangbei_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice);
	if(s=="")
		return "������ûʲô�����ɳ��۵ġ�\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
string view_inventory_daoju_sell(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_daoju_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice);
	if(s=="")
		return "������ûʲô�����ɳ��۵ġ�\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
string view_inventory_zhuangbei_package(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="user_package";
	string s="";
	s += view_something_zhuangbei_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice);
	if(s=="")
		return "û�пɴ洢����Ʒ��\n";
	return  s;
}
string view_inventory_daoju_package(void|string cmd,void|int notShowMoney,void|int showPrice){
	if(cmd==0)
		cmd="user_package";
	string s="";
	s += view_something_daoju_sell(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice);
	if(s=="")
		return "û�пɴ洢����Ʒ��\n";
	return  s;
}
static private string view_something_zhuangbei_sell(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;	
					if(items[i]["equiped"]){
						/*
						strlist+="��";
						strlist+="["+items[i]->query_short();
						if(showPrice)
							strlist+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						strlist+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						*/
						name_count[items[i]->query_name()]++;
					}
					else
					{
						out_no_equip+="["+items[i]->query_short();
						if(showPrice)
							out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							out_no_equip+="("+items[i]->query_item_canLevel()+"��)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else if(!items[i]->query_item_task())
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="sell"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):inventory_sell]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):inventory_daoju_sell]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		else if(list=="vendue"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):inventory_vendue]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):inventory_daoju_vendue]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		else if(list=="user_package"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):inventory_package]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):inventory_daoju_package]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	return out+out_no_equip;
}
static private string view_something_daoju_sell(function filter_func,string list,void|int showPrice){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				//����-װ����Ʒ��������
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//����-��ʳ����Ʒ
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn((items[i]->level_limit*50/4)*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//��Ϊ���죬����ԭ���ϵ���Ʒ����,�۸�=value*amount
				else if(items[i]->is("combine_item") && items[i]->query_for_material() != ""){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_value()*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				else if(items[i]->query_item_type()=="book"){
					out_no_equip+="["+items[i]->query_short();
					if(items[i]->query_peifang_kind()!="")
					{
						switch(items[i]->query_peifang_kind()){
							case "caifeng":
								out_no_equip+="(�÷�"+items[i]->query_viceskill_level()+")";
							break;
							case "duanzao":
								out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
							break;
							case "liandan":
								out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
							break;
							case "zhijia":
								out_no_equip+="(�Ƽ�"+items[i]->query_viceskill_level()+")";
							break;
							default:
							break;
						}
					}
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//����-һ����Ʒ��������Ʒ��������Ʒ��,�޼۸���ʾ
				else{
					//���������ģ�������ʾ,���������ģ����ݲ߻�����۸�ؼ������������õ��۸�
					if(!items[i]->query_item_task()){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="sell"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):inventory_sell]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):inventory_daoju_sell]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		else if(list=="vendue"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):inventory_vendue]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):inventory_daoju_vendue]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		else if(list=="user_package"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):inventory_package]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):inventory_daoju_package]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		out += howitem + " " + howdaoju+"\n";	
	}
	return out+out_no_equip;
}

// 3����԰�е�"С��"
string view_inventory_home_shop(void|string cmd,void|int notShowMoney,void|int showPrice,void|int shopId){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_home_shop(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,shopId);
	if(s=="")
		return "������ûʲô�����ɳ��۵ġ�\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
string view_inventory_home_shop_daoju(void|string cmd,void|int notShowMoney,void|int showPrice,void|int shopId){
	if(cmd==0)
		cmd="sell";
	string s="";
	string mymoney = this_player()->query_money_cn()+"\n";
	string myyushi = this_player()->query_yushi_cn()+"\n"; 
	s += view_something_home_shop_daoju(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,shopId);
	if(s=="")
		return "������ûʲô�����ɳ��۵ġ�\n";
	else
		s = mymoney + myyushi + s;
	return  s;
}
static private string view_something_home_shop(function filter_func,string list,void|int showPrice,void|int shopId){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())&&items[i]->query_item_type()=="yushi"){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;	
					if(items[i]["equiped"]){
						name_count[items[i]->query_name()]++;
					}
					else
					{
						out_no_equip+="["+items[i]->query_short();
						if(showPrice)
							out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_item_canLevel()*50/4)+")";
						else if(items[i]->query_item_canLevel())
							out_no_equip+="("+items[i]->query_item_canLevel()+"��)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else if(!items[i]->query_item_task())
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="home_shop"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):home_add_shopItem]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):home_add_daoju_shopItem]";
			else
				howdaoju += "����("+daoju_count+")";
		}
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	return out+out_no_equip;
}
static private string view_something_home_shop_daoju(function filter_func,string list,void|int showPrice,void|int shopId){
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())&&items[i]->query_item_type()=="yushi"){
				//����-װ����Ʒ��������
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
				inv_count++;
				//����-��ʳ����Ʒ
				else if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn((items[i]->level_limit*50/4)*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//��Ϊ���죬����ԭ���ϵ���Ʒ����,�۸�=value*amount
				else if(items[i]->is("combine_item") && items[i]->query_for_material() != ""){
					out_no_equip+="["+items[i]->query_short();
					if(showPrice)
						out_no_equip+="("+MUD_MONEYD->query_store_money_cn(items[i]->query_value()*items[i]->amount)+")";
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				else if(items[i]->query_item_type()=="book"){
					out_no_equip+="["+items[i]->query_short();
					if(items[i]->query_peifang_kind()!="")
					{
						switch(items[i]->query_peifang_kind()){
							case "caifeng":
								out_no_equip+="(�÷�"+items[i]->query_viceskill_level()+")";
							break;
							case "duanzao":
								out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
							break;
							case "liandan":
								out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
							break;
							case "zhijia":
								out_no_equip+="(�Ƽ�"+items[i]->query_viceskill_level()+")";
							break;
							default:
							break;
						}
					}
					out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
					name_count[items[i]->query_name()]++;
					daoju_count++;
				}
				//����-һ����Ʒ��������Ʒ��������Ʒ��,�޼۸���ʾ
				else{
					//���������ģ�������ʾ,���������ģ����ݲ߻�����۸�ؼ������������õ��۸�
					if(!items[i]->query_item_task()){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+" "+shopId+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(list=="home_shop"){
			if(inv_count)
				howitem += "[װ��("+inv_count+"):home_add_shopItem]";
			else
				howitem += "װ��("+inv_count+")";
			if(daoju_count)
				howdaoju += "[����("+daoju_count+"):home_add_daoju_shopItem]";
			else
				howdaoju += "����("+daoju_count+")";
		}
			out += howitem + " " + howdaoju+"\n";	
	}
	return out+out_no_equip;
}

// 4������/���� ��Ʒ
//��ӽ���ר����ͼ����Ϊ�и�����Ʒ
string view_inventory_trade_zhuangbei(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_zhuangbei(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"trade");
	return  s;
}
string view_inventory_trade_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_daoju(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"trade");
	return  s;
}
//�������ר����ͼ����Ϊ�и�����Ʒ
string view_inventory_send_zhuangbei(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_zhuangbei(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"sendother");
	return  s;
}
string view_inventory_send_daoju(void|string cmd,void|int notShowMoney,void|int showPrice){
	string s="";
	s += this_player()->query_money_cn()+"\n";
	s += this_player()->query_yushi_cn()+"\n"; 
	s += view_something_trade_daoju(lambda(object ob){return ob->is("item")&&ob->query_item_canTrade();},cmd,showPrice,"sendother");
	return  s;
}
static private string view_something_trade_daoju(function filter_func,string list,void|int showPrice,string cmd)
{
	//��װ�����׵ĶԷ�nameȡ��
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
					inv_count++;
				else{
					//����-��ʳ����Ʒ
					if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
					else{
						if(items[i]->query_item_canTrade()){
							if(items[i]->query_item_type()=="book"){
								out_no_equip+="["+items[i]->query_short();
								if(items[i]->query_peifang_kind()!="")
								{
									switch(items[i]->query_peifang_kind()){
										case "caifeng":
											out_no_equip+="(�÷�"+items[i]->query_viceskill_level()+")";
										break;
										case "duanzao":
											out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
										break;
										case "liandan":
											out_no_equip+="(����"+items[i]->query_viceskill_level()+")";
										break;
										case "zhijia":
											out_no_equip+="(�Ƽ�"+items[i]->query_viceskill_level()+")";
										break;
										default:
										break;
									}
								}
								out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
								name_count[items[i]->query_name()]++;
								daoju_count++;
							}
							else{
								out_no_equip+="["+items[i]->query_short();
								out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
								name_count[items[i]->query_name()]++;
								daoju_count++;
							}
						}
						else{
							out_no_equip+=items[i]->query_short()+"\n";
							name_count[items[i]->query_name()]++;
							daoju_count++;
						}
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[װ��("+inv_count+"):"+cmd+" "+user_name+"]";
		else
			howitem += "װ��("+inv_count+")";
		if(daoju_count)
			howdaoju += "[����("+daoju_count+"):"+cmd+"_daoju "+user_name+"]";
		else
			howdaoju += "����("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(��Ʒ��0/"+count_max+")\n"; 
	return out+out_no_equip;
}
static private string view_something_trade_zhuangbei(function filter_func,string list,void|int showPrice,string cmd)
{
	//��װ�����׵ĶԷ�nameȡ��
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	/////////////////////////////////////////////////////	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;
					if(items[i]["equiped"]){
						/*
						strlist+="��";
						strlist+=items[i]->query_short()+"\n";
						name_count[items[i]->query_name()]++;
						*/
						name_count[items[i]->query_name()]++;
					}
					else{
						out_no_equip+="["+items[i]->query_short();
						if(items[i]->query_item_canLevel())
							out_no_equip+="("+items[i]->query_item_canLevel()+"��)";
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[װ��("+inv_count+"):"+cmd+" "+user_name+"]";
		else
			howitem += "װ��("+inv_count+")";
		if(daoju_count)
			howdaoju += "[����("+daoju_count+"):"+cmd+"_daoju "+user_name+"]";
		else
			howdaoju += "����("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(��Ʒ��0/"+count_max+")\n"; 
	return out+out_no_equip;
}
/*5��������Ʒ
static private string view_something_send_daoju(function filter_func,string list,void|int showPrice)
{
	//��װ�����׵ĶԷ�nameȡ��
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry")
					inv_count++;
				else{
					//����-��ʳ����Ʒ
					if(items[i]->query_item_type()=="food"||items[i]->query_item_type()=="water"){
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
						daoju_count++;
					}
					else{
						if(items[i]->query_item_canTrade()){
							out_no_equip+="["+items[i]->query_short();
							out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
							name_count[items[i]->query_name()]++;
							daoju_count++;
						}
						else{
							out_no_equip+=items[i]->query_short()+"\n";
							name_count[items[i]->query_name()]++;
							daoju_count++;
						}
					}
				}
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[װ��("+inv_count+"):sendother "+user_name+"]";
		else
			howitem += "װ��("+inv_count+")";
		if(daoju_count)
			howdaoju += "[����("+daoju_count+"):sendother_daoju "+user_name+"]";
		else
			howdaoju += "����("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(��Ʒ��0/"+count_max+")\n"; 
	return out+out_no_equip;
}
static private string view_something_send_item(function filter_func,string list,void|int showPrice)
{
	//��װ�����׵ĶԷ�nameȡ��
	string cmdtype,user_name;
	array(string) usr_content=list/" ";
	cmdtype = usr_content[0];	
	user_name = usr_content[1];	
	/////////////////////////////////////////////////////	
	mapping(string:int) name_count=([]);
	array(object) items=filter(all_inventory(this_object(),this_player()),filter_func)-({this_player()});
	string out="";
	string out_no_equip="";
	int count_max = query_beibao_size();//�û�������ʵ�����������������ģ�
	if(items&&sizeof(items)){
		out+="(��Ʒ��"+sizeof(items)+"/"+count_max+")\n"; 
		string strlist = "";
		int inv_count = 0;
		int daoju_count = 0;
		for(int i=0;i<sizeof(items);i++){
			if(items[i]&&(!items[i]->query_toVip())){
				if(items[i]->query_item_type()=="weapon"||items[i]->query_item_type()=="single_weapon"||items[i]->query_item_type()=="double_weapon"||items[i]->query_item_type()=="armor"||items[i]->query_item_type()=="decorate"||items[i]->query_item_type()=="jewelry"){
					inv_count++;
					if(items[i]["equiped"]){
						strlist+="��";
						strlist+=items[i]->query_short()+"\n";
						name_count[items[i]->query_name()]++;
						name_count[items[i]->query_name()]++;
					}
					else{
						out_no_equip+="["+items[i]->query_short();
						out_no_equip+=":"+list+" "+items[i]->query_name()+" "+name_count[items[i]->query_name()]+"]\n";
						name_count[items[i]->query_name()]++;
					}
				}
				else
					daoju_count++;
			}
		}
		string howitem = "";
		string howdaoju = "";
		if(inv_count)
			howitem += "[װ��("+inv_count+"):sendother "+user_name+"]";
		else
			howitem += "װ��("+inv_count+")";
		if(daoju_count)
			howdaoju += "[����("+daoju_count+"):sendother_daoju "+user_name+"]";
		else
			howdaoju += "����("+daoju_count+")";
		out += howitem + " " + howdaoju+"\n" + strlist;	
	}
	else
		out+="(��Ʒ��0/"+count_max+")\n"; 
	return out+out_no_equip;
}*/
