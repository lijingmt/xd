#include <globals.h>
//��Ҫ���洢�ģ�ȥ��private�ֶ�,���Խ׶ο��Ժúÿ���
//�������attack_power��Ȼľ���Ĺ�����,������Ϸ����
//������Ȼľ�����ɵ�object������������ԣ�û��Ҫ�洢����
//�������ڸ���Ʒװ��״̬�����������ǻ�仯��������Ҫ�洢������ĥ��̶ȵ�
private int attack_power=0;//�����˺�����ֵ
int query_attack_power(){ return attack_power;}
void set_attack_power(int a){ attack_power=a;}

private int attack_power_limit=0;//�����˺�����ֵ
int query_attack_power_limit(){ return attack_power_limit;}
void set_attack_power_limit(int a){ attack_power_limit=a;}

private int speed_power=0;//���������ٶ�,���ܻ�仯����Ҫ�洢
int query_speed_power(){ return speed_power;}
void set_speed_power(int a){ speed_power=a;}

private int equip_defend=0;//���ߵķ�����
int query_equip_defend(){ return equip_defend+(query_defend_add()==0?0:query_defend_add());}
void set_equip_defend(int a){ equip_defend=a;}

private int str_add=0;//��Ʒ����������������
int query_str_add(){ return str_add;}
void set_str_add(int a){ str_add=a;}

private int dex_add=0;//��Ʒ����������������
int query_dex_add(){ return dex_add;}
void set_dex_add(int a){ dex_add=a;}

private int think_add=0;//��Ʒ����������������
int query_think_add(){ return think_add;}
void set_think_add(int a){ think_add=a;}

private int life_add=0;//��������
int query_life_add(){ return life_add*10;}
void set_life_add(int a){ life_add=a;}

private int mofa_add=0;//��������
int query_mofa_add(){ return mofa_add*10;}
void set_mofa_add(int a){ mofa_add=a;}

private int lunck_add=0;//���˸���
int query_lunck_add(){ return lunck_add;}
void set_lunck_add(int a){ lunck_add=a;}

private int appear_add=0;//��ò����
int query_appear_add(){ return appear_add;}
void set_appear_add(int a){ appear_add=a;}

//���ӹ��������������ܣ����У���������
private int attack_add=0;//���ӹ���
int query_attack_add(){ return attack_add;}
void set_attack_add(int a){ attack_add=a;}

private int defend_add=0;//���ӷ���
int query_defend_add(){ return defend_add*10;}
void set_defend_add(int a){ defend_add=a;}

private int dodge_add=0;//��������
int query_dodge_add(){ return dodge_add;}
void set_dodge_add(int a){ dodge_add=a;}

private int hitte_add=0;//��������
int query_hitte_add(){ return hitte_add;}
void set_hitte_add(int a){ hitte_add=a;}

private int doub_add=0;//���ӱ���
int query_doub_add(){ return doub_add;}
void set_doub_add(int a){ doub_add=a;}

//������0121//////////////////////////////////
private int all_add=0;//��Ʒ����ȫ����
int query_all_add(){ return all_add;}
void set_all_add(int a){ all_add=a;}

private int recive_add=0;//��Ʒ���������˺�
int query_recive_add(){ return recive_add;}
void set_recive_add(int a){ recive_add=a;}

private int back_add=0;//��Ʒ���ӷ����˺�
int query_back_add(){ return back_add;}
void set_back_add(int a){ back_add=a;}

private int weapon_attack_add=0;//��Ʒ�����������������Ӱٷֱ�
int query_weapon_attack_add(){ return weapon_attack_add;}
void set_weapon_attack_add(int a){ weapon_attack_add=a;}

private int dura_add=0;//��Ʒ�����;ö�
int query_dura_add(){ return dura_add*10;}
void set_dura_add(int a){ dura_add=a;}

private int rase_life_add=0;//��Ʒ���������ָ�����
int query_rase_life_add(){ return rase_life_add;}
void set_rase_life_add(int a){ rase_life_add=a;}

private int rase_mofa_add=0;//��Ʒ���ӷ����ָ�����
int query_rase_mofa_add(){ return rase_mofa_add;}
void set_rase_mofa_add(int a){ rase_mofa_add=a;}

private int huo_mofa_attack_add=0;//��Ʒ���ӻ�ϵ�����˺�
int query_huo_mofa_attack_add(){ return huo_mofa_attack_add;}
void set_huo_mofa_attack_add(int a){ huo_mofa_attack_add=a;}

private int bing_mofa_attack_add=0;//��Ʒ���ӱ�ϵ�����˺�
int query_bing_mofa_attack_add(){ return bing_mofa_attack_add;}
void set_bing_mofa_attack_add(int a){ bing_mofa_attack_add=a;}

private int feng_mofa_attack_add=0;//��Ʒ���ӷ�ϵ�����˺�
int query_feng_mofa_attack_add(){ return feng_mofa_attack_add;}
void set_feng_mofa_attack_add(int a){ feng_mofa_attack_add=a;}

private int du_mofa_attack_add=0;//��Ʒ���Ӷ�ϵ�����˺�
int query_du_mofa_attack_add(){ return du_mofa_attack_add;}
void set_du_mofa_attack_add(int a){ du_mofa_attack_add=a;}

private int spec_mofa_attack_add=0;//��Ʒ�������ⷨ���˺�
int query_spec_mofa_attack_add(){ return spec_mofa_attack_add;}
void set_spec_mofa_attack_add(int a){ spec_mofa_attack_add=a;}

private int mofa_all_add=0;//��Ʒ����ȫϵ�����˺�
int query_mofa_all_add(){ return mofa_all_add;}
void set_mofa_all_add(int a){ mofa_all_add=a;}

private int attack_huoyan_add=0;//��Ʒ���ӻ��湥����
int query_attack_huoyan_add(){ return attack_huoyan_add;}
void set_attack_huoyan_add(int a){ attack_huoyan_add=a;}

private int attack_bingshuang_add=0;//��Ʒ���ӱ�˪������
int query_attack_bingshuang_add(){ return attack_bingshuang_add;}
void set_attack_bingshuang_add(int a){ attack_bingshuang_add=a;}

private int attack_fengren_add=0;//��Ʒ���ӷ��й�����
int query_attack_fengren_add(){ return attack_fengren_add;}
void set_attack_fengren_add(int a){ attack_fengren_add=a;}

private int attack_dusu_add=0;//��Ʒ���Ӷ��ع�����
int query_attack_dusu_add(){ return attack_dusu_add;}
void set_attack_dusu_add(int a){ attack_dusu_add=a;}

private int attack_spec_add=0;//��Ʒ�������⹥����
int query_attack_spec_add(){ return attack_spec_add;}
void set_attack_spec_add(int a){ attack_spec_add=a;}

private int attack_all_add=0;//��Ʒ����ȫϵ�����˺�
int query_attack_all_add(){ return attack_all_add;}
void set_attack_all_add(int a){ attack_all_add=a;}

private int huoyan_defend_add=0;//��Ʒ���ӻ��濹��
int query_huoyan_defend_add(){ return huoyan_defend_add;}
void set_huoyan_defend_add(int a){ huoyan_defend_add=a;}

private int bingshuang_defend_add=0;//��Ʒ���ӱ�˪����
int query_bingshuang_defend_add(){ return bingshuang_defend_add;}
void set_bingshuang_defend_add(int a){ bingshuang_defend_add=a;}

private int fengren_defend_add=0;//��Ʒ���ӷ��п���
int query_fengren_defend_add(){ return fengren_defend_add;}
void set_fengren_defend_add(int a){ fengren_defend_add=a;}

private int dusu_defend_add=0;//��Ʒ���Ӷ��ؿ���
int query_dusu_defend_add(){ return dusu_defend_add;}
void set_dusu_defend_add(int a){ dusu_defend_add=a;}

private int all_mofa_defend_add=0;//��Ʒ����ȫ��������
int query_all_mofa_defend_add(){ return all_mofa_defend_add;}
void set_all_mofa_defend_add(int a){ all_mofa_defend_add=a;}

//������0121//////////////////////////////////
int equiped;//�Ƿ�װ���˸���Ʒ

private int renxing = 0;//����
void set_renxing(int num){ renxing = num;}
int query_renxing(){ return renxing;}

private array(string) item_profeLimit=({});//��Ʒװ����ְҵ���ƣ��ض�ְҵ����װ������Ʒ
void set_item_profeLimit(string s){
	//array(string) arr = s/":";	
	//if(arr&&sizeof(arr)){
	//	item_profeLimit = copy_value(arr);
	//}
	item_profeLimit += ({s});
}
array(string) query_item_profeLimit(){return item_profeLimit;}

private int item_canLevel;//��Ʒװ����Ҫ�ȼ�������װ���ĵȼ�����
int query_item_canLevel(){ return item_canLevel;}
void set_item_canLevel(int a){ item_canLevel=a;}

private string item_kind;//��Ʒ���ࣺ���������������֣�single_main_weapon,single_other_weapon, ˫������������ double_main_weapon����Ь��shoes�����ߣ���ָring����neck�����Σ����磨����ȡ�
string query_item_kind(){ return item_kind;}
void set_item_kind(string a){ item_kind=a;}

private string item_skill;//��Ʒ����Ҫ������weapon����armor����Ҫ�ļ��ܣ�����˫�����������иü��ܷ���װ��
string query_item_skill(){ return item_skill;}
void set_item_skill(string a){ item_skill=a;}
//����ȥ��private���Ƿ�洢

int item_dura;//��Ʒ�;öȣ���Ʒĥ��̶ȣ�������Ʒ�������д������ԣ����˽�ָ������������Ʒ�Ȳ���ĥ��
int item_cur_dura;//��Ʒ��ǰ�;ö�
int query_item_dura(){
	int tmp = 0;
	if(query_dura_add()){
		tmp = item_dura+query_dura_add();
		return tmp;
	}
	return item_dura;
}

//������Ʒˢ���ԵĴ���
//��liaocheng��07/12/27��ӣ�������ʯˢװ������
private int convert_limit = 10;//��Ʒˢ�Ĵ�������
int convert_count;//��¼��Ʒ��ˢ�Ĵ���
void set_convert_count(int a){
	if(a>convert_limit)
		a = convert_limit;
	convert_count = a;
}
int query_convert_count(){return convert_count;}
int query_convert_limit(){return convert_limit;}

int is_equip(){return 1;}

int query_weapon_attack(){
	return attack_power+random(attack_power_limit-attack_power+1);
}
//װ����ĥ�����
void reduce_power(int power){
	object ob=this_object();
	if(ob->item_canDura){
		if(ob->item_dura>=10000)
			return;
		ob->item_cur_dura-=power;
		if(ob->item_cur_dura<0)
			ob->item_cur_dura=0;
	}
}
string query_content(){
	string r="";
	object ob=this_object();
	if(!ob->is_equip())
		return r;
	if(ob->query_item_type()=="armor"){
		switch(ob->item_kind){
			case "armor_head":
				r += "(ͷ��)\n";
			break;
			case "armor_cloth":
				r += "(�ز�)\n";
			break;
			case "armor_waste":
				r += "(��)\n";
			break;
			case "armor_hand":
				r += "(�ֲ�)\n";
			break;
			case "armor_thou":
				r += "(�Ȳ�)\n";
			break;
			case "armor_shoes":
				r += "(�Ų�)\n";
		}
	}
	else if(ob->query_item_type()=="jewelry"){
		switch(ob->item_kind){
			case "jewelry_ring":
				r += "(��ָ)\n";
			break;
			case "jewelry_neck":
				r += "(����)\n";
			break;
			case "jewelry_bangle":
				r += "(����)\n";
			break;
		}
	}
	else if(ob->query_item_type()=="decorate"){
		switch(ob->item_kind){
			case "decorate_manteau":
				r += "(����)\n";
			break;
			case "decorate_thing":
				r += "(�Ҽ�)\n";
			break;
			case "decorate_tool":
				r += "(��Ʒ)\n";
			break;
		}
	}
	if(ob->attack_power&&ob->attack_power_limit) r+="�˺���"+ob->attack_power+"-"+ob->attack_power_limit+"\n";
	if(ob->item_kind=="double_main_weapon"||ob->item_kind=="single_main_weapon"||ob->item_kind=="single_other_weapon")
		r+="�ٶȣ�"+ob->speed_power+"\n";
	if(ob->query_item_type()=="weapon"||ob->query_item_type()=="single_weapon"||ob->query_item_type()=="double_weapon"||ob->query_item_type()=="armor")
		r+="�;öȣ�"+ob->item_cur_dura+"/"+ob->item_dura+"\n";

	if(ob->str_add) r+="+"+ob->str_add+"����\n";
	if(ob->dex_add) r+="+"+ob->dex_add+" ����\n";
	if(ob->think_add) r+="+"+ob->think_add+" ����\n";
	if(ob->renxing) r+="+"+ob->renxing+" ����\n";
	if(ob->life_add) r+="+"+ob->life_add+" ������\n";
	if(ob->mofa_add) r+="+"+ob->mofa_add+" ����ֵ\n";
	if(ob->lunck_add) r+="+"+ob->lunck_add+" ����\n";
	if(ob->appear_add) r+="+"+ob->appear_add+" ����\n";
	if(ob->hitte_add) r+="���������� "+ob->hitte_add+"%\n";
	if(ob->doub_add) r+="���������� "+ob->doub_add+"%\n";
	if(ob->dodge_add) r+="���������� "+ob->dodge_add+"%\n";
	if(ob->equip_defend) r+="+"+ob->equip_defend+" ����\n";
	if(ob->attack_add) r+="+"+ob->attack_add+" �����˺�\n";
	if(ob->defend_add) r+="+"+ob->defend_add+" ������\n";
	//�������Լӳɵ�������
	if(ob->all_add) r+="+"+ob->all_add+" ��������\n";
	if(ob->recive_add) r+="�����˺� "+ob->recive_add+"%\n";
	if(ob->back_add) r+="�����˺� "+ob->back_add+"%\n";
	if(ob->weapon_attack_add) r+="�����˺��ӳ� "+ob->weapon_attack_add*10+"%\n";
	if(ob->dura_add) r+="+"+ob->dura_add+" ��Ʒ�;�\n";
	if(ob->rase_life_add) r+="ÿ��ָ� "+ob->rase_life_add+" ������\n";
	if(ob->rase_mofa_add) r+="ÿ��ָ�"+ob->rase_mofa_add+" �㷨��\n";
	if(ob->huo_mofa_attack_add) r+="��ϵ�����˺����� "+ob->huo_mofa_attack_add+"��\n";
	if(ob->bing_mofa_attack_add) r+="��ϵ�����˺����� "+ob->bing_mofa_attack_add+"��\n";
	if(ob->feng_mofa_attack_add) r+="��ϵ�����˺����� "+ob->feng_mofa_attack_add+"��\n";
	if(ob->du_mofa_attack_add) r+="��ϵ�����˺����� "+ob->du_mofa_attack_add+"��\n";
	if(ob->spec_mofa_attack_add) r+="���ⷨ���˺����� "+ob->spec_mofa_attack_add+"��\n";
	if(ob->mofa_all_add) r+="���з����˺����� "+ob->mofa_all_add+"��\n";
	if(ob->attack_huoyan_add) r+="+"+ob->attack_huoyan_add+" �����˺�\n";
	if(ob->attack_bingshuang_add) r+="+"+ob->attack_bingshuang_add+" ��˪�˺�\n";
	if(ob->attack_fengren_add) r+="+"+ob->attack_fengren_add+" �����˺�\n";
	if(ob->attack_dusu_add) r+="+"+ob->attack_dusu_add+" �����˺�\n";
	if(ob->attack_all_add) r+="+"+ob->attack_all_add+" ȫϵ�˺�\n";
	if(ob->attack_spec_add) r+="+"+ob->attack_spec_add+" �����˺�\n";
	if(ob->huoyan_defend_add) r+="���濹������ "+ob->huoyan_defend_add+"��\n";
	if(ob->bingshuang_defend_add) r+="��˪�������� "+ob->bingshuang_defend_add+"��\n";
	if(ob->fengren_defend_add) r+="���п������� "+ob->fengren_defend_add+"��\n";
	if(ob->dusu_defend_add) r+="���ؿ������� "+ob->dusu_defend_add+"��\n";
	if(ob->all_mofa_defend_add) r+="ȫ������������ "+ob->all_mofa_defend_add+"��\n";

	//��ʯ
	if(ob->query_baoshi("blue")){
		foreach(ob->query_baoshi("blue"),object each_ob){
			r += each_ob->query_name_cn()+"("+(each_ob->query_desc()-"\n")+")\n";
		}
	}
	if(ob->query_baoshi("red")){
		foreach(ob->query_baoshi("red"),object each_ob){
			r += each_ob->query_name_cn()+"("+(each_ob->query_desc()-"\n")+")\n";
		}
	}
	if(ob->query_baoshi("yellow")){
		foreach(ob->query_baoshi("yellow"),object each_ob){
			r += each_ob->query_name_cn()+"("+(each_ob->query_desc()-"\n")+")\n";
		}
	}
	//����
	if(ob->query_aocao("blue")) r+="��ɫ����x"+ob->query_aocao("blue")+"\n";
	if(ob->query_aocao("red")) r+="��ɫ����x"+ob->query_aocao("red")+"\n";
	if(ob->query_aocao("yellow")) r+="��ɫ����x"+ob->query_aocao("yellow")+"\n";

	if(ob->query_item_rareLevel()>0)
		r+="ת��������"+ob->query_convert_count()+"/"+ob->query_convert_limit()+"\n";
	if(ob->item_canLevel>0) r+="Ҫ�󼶱�"+ob->item_canLevel+"\n";
	//ְҵҪ��
	if(ob->item_profeLimit&&sizeof(ob->item_profeLimit)){
		r+="Ҫ��ְҵ��";
		for(int i=0; i<sizeof(ob->item_profeLimit); i++){
			if(ob->item_profeLimit[i]&&sizeof(ob->item_profeLimit[i]))
				r+=this_player()->query_profe_cn(ob->item_profeLimit[i])+" ";
		}
		r+="\n";
	}
	r+="--------\n";
	return r;
}
