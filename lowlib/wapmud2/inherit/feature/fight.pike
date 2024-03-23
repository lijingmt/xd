#include <globals.h>
#include <command.h>
#include <wapmud2/include/wapmud2.h>
//������������Ҫ��������������ͨ��ģ��
#define CITYD ((object)(ROOT "/gamelib/single/daemons/cityd"))
private int tmp_heart_beat;
private int in_combat;
private mapping items;
//Ӱ��ȡ����ְҵ���ͱ�
static mapping(string:int) profe_fight=([
		"jianxian":0,
		"yushi":1,
		"zhuxian":2,
		"kuangyao":3,
		"wuyao":4,
		"yinggui":5,
		"humanlike":6,
		"beast":7,
		"bird":8,
		"fish":9,
		"amphibian":10,
		"bugs":11
		]);

//���ܳ�޼�Ȩӳ���
private mapping(string:int) skills_hate=([
		"test":100,

		]);

//ս������//////////////////////////////////
//��liaocheng��07/1/11��ӣ�����ս������
static mapping(string:array(string)) m_fight_desc=([
		"jian"  :({"һ��ֱ��","һ����ɨ","һ������","һ��б��"}),
		"dao"   :({"һ��˳��ն","һ���Ϳ�","һ��ͻ��","һ����������"}),
		"qiang" :({"һ��ֱ��","һ������","һ������","���ɨ��Ҷ","һ������ǹ"}),
		"gun"   :({"һ�����ɨ","��ͷһ��","ʩչȺ������","һ��ֱ��ͻ��"}),
		"bi"    :({"һ�����","һ���Ҵ�","һ��ֱ��","һ������","һ���Ͻ�"}),
		"zhang" :({"һ���ͻ�","һ����ɨ","ӭ����ȥ","�����Ҵ�"}),
		"chui"  :({"��ͷ����","һ����ձ�ȭ","���˹�ȥ","һ����ѹ","һ����ɽ�û�"}),
		"fu"	:({"һ����ɨ","һ�ٿ�","ӭ�濳��","ʹ��һ��������"}),
		"none"	:({"ӭ��һȭ","һ�����","һ��ֱȭ","��������"}),
		"beast" :({"���˺ҧ","һ���ͳ�","һ��צ��","�����̶����"}),
		"bird"	:({"չ���˴�","һ������","����һ��","��ץһͨ"}),
		"fish"  :({"һ����ײ","һ��β���Ĵ�","Сҧһ��"}),
		"amphibian"  :({"һ����ײ","һ��β���Ĵ�","Сҧһ��"}),
		"bugs"  :({"һ����ײ","һ������","С��һ��","��Һ����"})
		]);
//��Ҫ�ӿڣ���attack�����е�ս�������������
//��ʹ����֮ǰ��������Ҫ�õ�arg������_fight()��Ҫ�����Ӧ���ж�
string query_fight_desc(string arg) {  //arg Ϊ����Ӱ����index�е�
	array(string) desc_tmp=m_fight_desc[arg];
	if(desc_tmp)
		return desc_tmp[random(sizeof(desc_tmp))];
	else
		return ("");
}
//���arg�Ľӿ�,���������������Ƿ���need_weapon_type����_fight()���ٸ�������ʹ�õ���������
string query_fight_type() {
	string proId=this_object()->query_profeId();
	switch(profe_fight[proId]){
		case 0 .. 6:
			return("");
			break;
		default:
			return(proId);
			break;
	}
}
static string fight_desc_arg_main="";//Ϊ��ʱ��ʾ�������Σ���Ϊ��ʱ��¼������������������
static string fight_desc_arg_other="";//��fight_desc_arg_mainΪ��ʱ����¼������������������


// ս���˺�////////////////////////////////
private int attack_weapon=0;
private int attack_huoyan_add=0;
private int attack_bingshuang_add=0;
private int attack_fengren_add=0;
private int attack_dusu_add=0;
private int defend = 0;
//////////////////////////////////////////

private int killing;
private int autoPerforming;//�Զ��ͷż��ܵ�һ�α�ʾ
object enemy;
private string action;//"escape"|"perform ..."
static string accept_fight_msg="$N������$p����ս��";
read_only(accept_fight_msg);
static string deny_fight_msg="$N��Ը���$p���С�";
read_only(deny_fight_msg);
static string success_msg="$N��$p���ֵ����������ˡ���";
read_only(success_msg);
static string surrender_msg="$N��$p�������ĵ���������˱���ˣ���Ͷ���ˡ���";
read_only(surrender_msg);
static string killing_msg="$N��������ɱ��$p��";
read_only(killing_msg);
int query_killing(){
	return killing;
}
int query_in_combat(){
	return in_combat;
}
private void recover(){
	if(in_combat) return;
	//npcս���Ժ��Զ��ָ�����
	this_object()->life=this_object()->life_max;
}
void _clean_fight(){
	//werror("\n----"+this_object()->query_name_cn()+"����_clean_fight()��ʼ----\n");
	in_combat=0;
	action=0;
	killing=0;
	this_object()->first_fight = 0;
	this_object()->timeCold = 0;
	this_object()->eat_timeCold = 0;
	if(this_object()->is("npc")){
		this_object()->who_fight_npc = "";//�����״ι�����
		this_object()->term_who_fight_npc = "";//�����״ι����߶����ʾ          
	}
	else 
		//��ԭɱ¾��,ʾ��Ϊ��սҪ����liaocheng��08/08/30���
		this_object()->kill_flag = 1;
	this_object()->reset_targets(); //���ó���б�
	if(tmp_heart_beat){
		set_heart_beat(0);
		tmp_heart_beat=0;
	}
	if(this_object()->is("npc")){
		if(zero_type(find_call_out(recover)))
			call_out(recover,2);
	}
	//��ʼ��debuffӳ���
	this_object()->set_debuff("dot",0,"none");
	this_object()->set_debuff("dot",1,0);
	this_object()->set_debuff("dot",2,0);
	this_object()->set_debuff("curse",0,"none");
	this_object()->set_debuff("curse",1,0);
	this_object()->set_debuff("curse",2,0);
	this_object()->set_debuff("curse2",0,"none");
	this_object()->set_debuff("curse2",1,0);
	this_object()->set_debuff("curse2",2,0);
	//��ʼ��buffӳ���
	this_object()->set_buff("buff",0,"none");
	this_object()->set_buff("buff",1,0);
	this_object()->set_buff("buff",2,0);
	this_object()->set_buff("buff2",0,"none");
	this_object()->set_buff("buff2",1,0);
	this_object()->set_buff("buff2",2,0);
	//werror("\n22222"+this_object()->query_name_cn()+"����_clean_fight()����222222\n");
}
//private void escape(void|int change){
void escape(void|int change){
	if(this_object()->get_cur_life()>0&&enemy->get_cur_life()>0){
		if(this_object()->query_debuff("70_skill_curse",0) == "baofengfeixue"){
			tell_object(this_object(),"�����������ѩЧ�������޷����ܡ�\n");
			return;
		}
		int succ = 40+(int)(this_object()->query_dex()/20);
		if(random(100)>=succ){
			tell_object(enemy,this_object()->query_name_cn()+"�����ܣ�����ʧ���ˡ�\n");
			tell_object(this_object(),"������ʧ���ˡ�\n");
			return;
		}
		tell_object(enemy,this_object()->query_name_cn()+"�����ˡ�\n");
		tell_object(this_object(),"�������ˡ�\n");
		enemy->clean_targets(this_object());
		_clean_fight();
		object env=environment(this_object());
		if(sizeof(env->exits)){
			this_object()->command("leave "+indices(env->exits)[random(sizeof(env->exits))]);
		}
		return;
	}
	else{                                                                    
		if(!this_object()->is("npc"))
			tell_object(this_object(),"���Ѿ�������\n");
		return;
	}
}
//��������ϵͳ20070206//////////////////////////////////
//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
//���ң���ֹ�������ܵȼ����޶����
	void skills_level_check(string sname){
		if(MUD_SKILLSD[sname]->boss_skill == 1)
			return;
		int cur_skills_level_limit = 10;
		//��ǰ���û��ü��ܵȼ��������ȴ��ڸü��ܱ���õȼ��������ȣ����������û��ĸü��ܵȼ�
		if( this_object()->skills[sname][1]>=MUD_SKILLSD[sname]->performs_shuliandu[this_object()->skills[sname][0]] ){
			//��ǰ���ܵȼ��趨����Ϊ10��
			if(this_object()->skills[sname][0]<cur_skills_level_limit){
				this_object()->skills[sname][0]++;
				this_object()->skills[sname][1] = 0;
			}
		}
		else{
			//���������ٶȽ���һ��
			int tmp = random(3)+1;
			if(tmp==2)
				this_object()->skills[sname][1]++;
		}
	}
//��������ϵͳ20070206//////////////////////////////////
//�����ͷŽӿ�20070131//////////////////////////////////
void perform(string name,void|int flag){
	//�������ж�......
	if(enemy==0)
		return;
	if(enemy && environment(this_object())==environment(enemy)){
		if(enemy->first_fight == 0 || !enemy->in_combat){
			enemy->_fight(this_object());
			enemy->first_fight = 1;
		}
	}
	object f_cur_skill;//��ǰʹ�ü��ܶ���
	string s = "";//�����Լ���ս������
	string s1=""; //������˵�ս������
	if(name&&sizeof(name))
		f_cur_skill = (object)MUD_SKILLSD[name];
	else
	{
		string stmp = "��Ҫʩ��ʲô���ܣ�";
		tell_object(this_object(),stmp+"\n");
		return;
	}
	if(this_object()->query_debuff("curse2",0)=="shenzhishufu"){
		int time_left = this_object()->query_debuff("curse2",2);
		string stmp = "��������֮����Ч��������ʱ�޷�ʹ�ü���(��ʣ"+time_left+"s)\n";
		tell_object(this_object(),stmp+"\n");
		return;
	}
	if(this_object()->timeCold!=0 && !flag){
		string stmp = "����"+this_object()->timeCold+"�뷨��������ȴʱ��\n";
		tell_object(this_object(),stmp);
		return;
	}
	if(f_cur_skill){
		int can_skill_level=0;//���ֶμ�¼ ��ҿ���ʹ�õĸü��ܵ���߼���
		//�����жϼ���ʹ�õĵȼ�����
		//mapping(int:string) lvLimit = f_cur_skill->query_performs_level_limit_all(); 
		//��ʱ�����֣���������Ҳ���������Ҫ�ж���������������������ִ�У������򷵻�0������鼶��
		mapping(int:string) lvLimit = f_cur_skill->query_performs_level_limit_all?f_cur_skill->query_performs_level_limit_all():0;                                         
		if(lvLimit && sizeof(lvLimit))//�ü����еȼ�����
		{
			//��һ������������������ȣ�ʹ�õ�Խ�༶��Խ�ߣ����ּ���ֻ��һ���ȼ�����
			if(sizeof(lvLimit) == 1){ //ֻ��һ������ļ���
				if(this_object()->query_level()<lvLimit[1])
				{
					string stmp = "����δ�ﵽ"+lvLimit[1]+"�����޷�ʹ�øü��ܡ�\n";
					tell_object(this_object(),stmp);
					return;
				}
			}
			else{//�ڶ�����������ܷ�Ϊ�����ȼ���ÿ���ȼ���Ӧ��lvҪ��ͬ��ĳ��������ʹ�ã����Զ��ж����ܷ�ʹ�ýϵ͵ļ��𣬷����ж�ֱ����ͼ���
				for(int i=sizeof(lvLimit);i>0;i--)
				{
					if(this_object()->query_level>=lvLimit[i])
					{
						can_skill_level = i;
					}
					else if(i == 1)//��������һ����Ҫ��û�дﵽ�����޷�ʹ�øü��ܡ�
					{
						string stmp = "����δ�ﵽ"+lvLimit[1]+"�����޷�ʹ�øü��ܡ�\n";
						tell_object(this_object(),stmp);
						return;
					}
				}
			}
		}

		//�ж������ּ���
		string mofa_type=f_cur_skill->s_skill_type; //�õ�ħ������
		//���ж��Ƿ����㹻�ķ���ʩ�Ÿü���
		int skill_level=(int)(this_object()->skills[name][0]);
		//werror("===========skill_level:"+skill_level+"\n");
		if(skill_level>can_skill_level&&can_skill_level>0)
			skill_level=can_skill_level;
		//werror("===========275 skill_level:"+skill_level+"\n");
		int s_cast = f_cur_skill->query_performs_cast(skill_level);
		if(s_cast<=this_object()->get_cur_mofa()){
			//���㹻�ķ���
			int s_cold = this_object()->f_skills[name];//���ܵ���ȴʱ��
			int s_cold_del = 0;//���ܶ����ٵ���ȴʱ��
			int s_cold_add = 0;//���ܶ��ӳ�����ȴʱ��
			if(this_object()->query_buff("70_skill_buff",0)=="lieyanzhuoshao"||this_object()->query_buff("70_skill_buff",0)=="bingci"){
				s_cold_del = this_object()->query_buff("70_skill_buff",1);
				s_cold -= s_cold_del;
			}
			if(this_object()->query_debuff("70_skill_curse",0)=="cuidu"){
				s_cold_add = 1;
				s_cold += s_cold_add;
			}
			if(s_cold < 0)
				s_cold = 0;
			//�����ж��Ƿ��Ǹ�ְҵ������Ч�����ܣ���liaocheng��08/01/16���
			if(mofa_type == "spec"){
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//���¸ü�����ȴʱ��,û�ڱ�����������
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					if(name == "xinhunzhuanhua" || name == "xinhunzhuanhua2"){
						//���ɵ��Ļ�ת��
						int life_tmp;
						if(name == "xinhunzhuanhua")
							life_tmp = this_object()->get_cur_mofa()*3+this_object()->get_cur_life();
						else if(name == "xinhunzhuanhua2")
							life_tmp = this_object()->get_cur_mofa()*7/2+this_object()->get_cur_life();
						if(life_tmp > this_object()->life_max)
							life_tmp = this_object()->life_max;
						this_object()->set_mofa(0);
						this_object()->set_life(life_tmp);
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")\n";
						s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")\n";
						tell_object(this_object(),s);
						tell_object(enemy,s1);
						//�������ֵ
						int hate=(int)(100*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);
					}

					else if(name == "fashukuangchao" || name == "shishabenneng" || name == "fashukuangchao2" || name == "shishabenneng2"){
						//��ʿ�ķ����񳱣����ɵ���Ѫ����
						//��¼buff������
						this_object()->set_buff("buff2",0,f_cur_skill->s_curse_type);
						//��¼buff��ֵ
						int tmp_int=f_cur_skill->query_performs_attack(skill_level);
						if(name == "shishabenneng"){
							tmp_int=this_object()->life_max*2/5;
							this_object()->f_skills = ([]);
							this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
						}
						else if(name == "shishabenneng2"){
							tmp_int=this_object()->life_max*1/2;
							this_object()->f_skills = ([]);
							this_object()->f_skills[name] = f_cur_skill->s_delayTime+1;
						}
						this_object()->set_buff("buff2",1,tmp_int);
						//��¼buff�ĳ���ʱ��
						this_object()->set_buff("buff2",2,f_cur_skill->query_s_lasttime(skill_level));

						//�������ֵ,buff�ĳ����ʱ��Ϊ10
						int hate=(int)(10*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "��ʩ����"+f_cur_skill->query_name_cn()+ "(�ȼ�"+skill_level+")";
						s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

					}
					else if(name == "xueranjiangshan" || name == "xueranjiangshan2"){
						//������ѪȾ��ɽ
						//�ȿ��Ƿ�������������û�оͲ��ܹ���
						mapping items = this_object()->query_equip();//[string:object]
						if(!items["single_main_weapon"]&&!items["double_main_weapon"])
						{
							s += "�ü�����Ҫװ��������������ʩ�š�";
							tell_object(this_object(),s+"\n");
							return;
						}
						//�ȼ�ѹ��
						int difflevel = enemy->query_level()-this_object()->query_level();
						if(difflevel<0)
							difflevel=0;
						int myhitte= this_object()->query_if_hitte();
						int h = (int)(myhitte-difflevel*5);
						if(h<30)
							h=30;
						if(random(100)<=h){
							//������ ~
							int s_phy_damage;
							int life_left;
							if(name == "xueranjiangshan"){
								s_phy_damage = this_object()->get_cur_life()*3/5;
								life_left = this_object()->get_cur_life()/2;
							}
							else if(name == "xueranjiangshan2"){
								s_phy_damage = this_object()->get_cur_life()*65/100;
								life_left = this_object()->get_cur_life()*55/100;
							}
							string s_name_cn = f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
							this_object()->set_life(life_left);
							if(this_object()->weapon_type=="double_main")
								attack(s_phy_damage,0,"double_main",s_name_cn,f_cur_skill->query_name());
							else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
								attack(s_phy_damage,0,"single_main",s_name_cn,f_cur_skill->query_name());
						}
						else{
							//δ����	
							s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+"), ��δ���жԷ���";
							s1 += this_object()->query_name_cn()+"ʩ��"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")����δ�����㡣"; 
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");
						}
					}
					else if(name == "shenzhishufu" || name == "shenzhishufu2"){
						//��������֮����
						//�ȼ�ѹ��
						int difflevel = enemy->query_level()-this_object()->query_level();          
						if(difflevel<0)
							difflevel=0;
						int myhitte= this_object()->query_if_hitte();
						int h = (int)(myhitte-difflevel*5);
						if(h<30)
							h=30;
						if(random(100)<=h){ //������~
							//��¼���������
							enemy->set_debuff("curse2",0,f_cur_skill->s_curse_type);
							//��¼�����ֵ
							enemy->set_debuff("curse2",1,f_cur_skill->query_performs_attack(skill_level));
							//��¼����ĳ���ʱ��
							enemy->set_debuff("curse2",2,f_cur_skill->query_s_lasttime(skill_level));

							//�������ֵ,curse�ĳ����ʱ��Ϊ20
							int hate=(int)(20*skills_hate["test"]/100);
							enemy->flush_targets(this_object(),hate);

							s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
							s1 += this_object()->query_name_cn()+"����ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");

							//ս���л��жԷ���������������ĥ��
							this_object()->reduce_fight_wield_weapon(1);
							//ս���б������߻��У�������ĥ��
							enemy->reduce_fight_wear_armor(1);
						}
						else { //δ����
							s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+"), �����Է��ֿ��ˡ�";
							s1 += this_object()->query_name_cn()+"����ʩ��"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")��������ֿ���";
							tell_object(this_object(),s+"\n");
							tell_object(enemy,s1+"\n");
						}
					}
					else if(name == "jinchanmeiying" || name == "jinchanmeiying2"){
						//Ӱ��Ľ����Ӱ
						array(object) enemys = this_object()->get_all_targets();
						s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")\n";
						if(enemys && sizeof(enemys)){
							for(int i=0;i<sizeof(enemys);i++){
								object target = enemys[i];
								tell_object(target,s1+"\n");
								target->clean_targets(this_object());
							}
						}
						this_object()->_clean_fight();
						this_object()->f_skills = ([]);
						this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
						this_object()->hind = 1;
						if(name == "jinchanmeiying2"){
							this_object()->set_buff("spec_attack_buff",0,f_cur_skill->s_curse_type);
							int tmp_int=f_cur_skill->query_performs_attack(1);
							this_object()->set_buff("spec_attack_buff",1,tmp_int);
							this_object()->set_buff("spec_attack_buff",2,f_cur_skill->s_lasttime);
						}
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")\n";
						tell_object(this_object(),s+"\n");
						this_object()->command("look");
					}
					return;
				}
				else{
					//��ʹ�ù��ļ���δ��ȴ,��ʾ������
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			//70���ĸ�ְҵ���⼼��
			else if(mofa_type == "70_spec"){
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//���¸ü�����ȴʱ��,û�ڱ�����������
					if(name == "fanzhuanyiji")
						this_object()->f_skills = ([]);
					this_object()->f_skills[name] = f_cur_skill->s_delayTime+1;
					this_object()->set_buff("70_skill_buff",0,name);
					this_object()->set_buff("70_skill_buff",1,f_cur_skill->effect_value);
					this_object()->set_buff("70_skill_buff",2,f_cur_skill->s_lasttime);
					if(name == "baofengfeixue" || name == "cuidu"){
						enemy->set_debuff("70_skill_curse",0,name);
						this_object()->set_debuff("70_skill_curse",1,f_cur_skill->effect_value);
						enemy->set_debuff("70_skill_curse",2,f_cur_skill->s_lasttime);
					}
					s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")\n";
					s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")\n";
					tell_object(this_object(),s);
					tell_object(enemy,s1);
					//�������ֵ
					int hate=(int)(100*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);
					return;
				}
				else{
					//��ʹ�ù��ļ���δ��ȴ,��ʾ������
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			//�ж��������Ƿ�������
			/*   ������������     */
			else if(mofa_type!="phy"&&mofa_type!="dot"&&mofa_type!="curse"&&mofa_type!="buff"){
				//����70���ܵķ�������Ч��
				if(enemy->query_buff("70_skill_buff",0)=="bingci"){
					string stmp = "���ɡ�����Ч�����Է����˺�����(����"+enemy->query_buff("70_skill_buff",2)+"s)\n";
					tell_object(this_object(),stmp);
					stmp = "���ɡ�����Ч�����������˶Է���һ�η�������(����"+enemy->query_buff("70_skill_buff",2)+"s)\n";
					tell_object(enemy,stmp);
					return;
				}
				//�ж��ü�����ȴʱ����ж�
				//�õ��ͷż��ܱ������޼�¼������У�����ȴʱ�䵽��û��
				int mofa_a_low=0; //��������������
				int mofa_a_high=0; //��������������
				int mofa_a=0; //ȡ�÷����������漴ֵ
				int mofa_defend=0; //���˵�ħ������
				int fact_mofa_a=0; //���յķ����˺�
				int mofachuantou_add=0;//ħ����͸ֵ
				if(s_cold <= 1){
					this_object()->timeCold = 2;
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					//���¸ü�����ȴʱ��,û�ڱ�����������
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//�����˺����㹫ʽ�����м��⹫ʽ
					//�ȼ�ѹ��
					int difflevel = enemy->query_level()-this_object()->query_level();
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){
						//������ ~
						//�õ��������ܵ��˺��漴ֵ
						mofa_a_low = f_cur_skill->query_performs_mofa_attack_low(skill_level);	
						mofa_a_high = f_cur_skill->query_performs_mofa_attack_high(skill_level);
						mofa_a = random(mofa_a_high-mofa_a_low+1)+mofa_a_low;
						//�ټ���װ�����Դ����ķ����˺�����
						//����Ҳ����߷�����liaocheng��07/4/16���
						//ְҵ���� caijie 08/12/03
						if(this_object()->query_profeId()=="yushi"||this_object()->query_profeId()=="wuyao"){
							mofa_a += this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think()*7/2);
						}
						else
							mofa_a +=this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think()*5/2);
						if(this_object()->query_buff("buff2",0)=="all_mofa_attack"){
							mofa_a = mofa_a*3/2;
						}
						//��������Ӧ�ĵ��˵�ħ������
						switch(mofa_type) {
							case "huo_mofa_attack":
								mofa_defend = enemy->query_equip_add("huoyan_defend");
							break;
							case "bing_mofa_attack":
								mofa_defend = enemy->query_equip_add("bingshuang_defend");
							break;
							case "feng_mofa_attack":
								//����70���ܵķ��з����ӳ�Ч��
								if(this_object()->query_buff("70_skill_buff",0)=="baofengfeixue")
									mofa_a += mofa_a/2;
								mofa_defend = enemy->query_equip_add("fengren_defend");
							break;
							case "du_mofa_attack":
								mofa_defend = enemy->query_equip_add("du_defend");
							break;
							default :
							mofa_defend = 0;
							break;
						}
						mofa_defend += enemy->query_equip_add("all_mofa_defend");
						//����װ�����е�ħ����͸ֵ
						mofachuantou_add=this_object()->query_equip_add("mofachuantou_add");
						//�����ʵ�ʵ�ħ���˺�ֵ
						fact_mofa_a=mofa_a-(int)(mofa_a*mofa_defend/400);
						fact_mofa_a+=mofachuantou_add;//����ħ����͸�Ĺ�����ֵ�����ؽ����
						//�жϱ���
						int b = this_object()->query_if_baoji();
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						s1+=this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						if(b){
							//������ ~
							fact_mofa_a=(int)fact_mofa_a*150/100;
							s += "�������˱���Ч����";
							s1 += "�������˱���Ч����";

						}

						//���������buff��ħ���������˺�liaocheng 07/4/9
						int attack_fact = fact_mofa_a;
						string absorb_desc = "";
						if(enemy->query_buff("buff",0)=="absorb"){
							if((int)enemy->query_buff("buff",1) >= fact_mofa_a){
								int remain = (int)enemy->query_buff("buff",1) - fact_mofa_a;
								attack_fact= 0;
								absorb_desc = "(������)";
								if(remain <= 0)
									enemy->clean_buff("buff");
								else
									enemy->set_buff("buff",1,remain);
							}
							else{
								attack_fact = fact_mofa_a - (int)enemy->query_buff("buff",1); 
								absorb_desc = "("+enemy->query_buff("buff",1)+"�㱻����)";
								enemy->clean_buff("buff");
							}
						}
						if(enemy->query_buff("buff2",0)=="absorb"){
							if((int)enemy->query_buff("buff2",1) >= fact_mofa_a){
								int remain = (int)enemy->query_buff("buff2",1) - fact_mofa_a;
								attack_fact= 0;
								absorb_desc = "(������)";
								if(remain <= 0)
									enemy->clean_buff("buff2");
								else
									enemy->set_buff("buff2",1,remain);
							}
							else{
								attack_fact = fact_mofa_a - (int)enemy->query_buff("buff",1); 
								absorb_desc = "("+enemy->query_buff("buff2",1)+"�㱻����)";
								enemy->clean_buff("buff2");
							}
						}
						//���ħ����͸�����㣬��Ҫ��ǰ����ʾ�����
						string chuantou_desc = "";
						if(mofachuantou_add>0){
							chuantou_desc = "��"+mofachuantou_add+" �㷨����͸��";
						}
						s += "����� " +fact_mofa_a+ " ���˺���"+absorb_desc+chuantou_desc+"\n";
						s1 += "����� " +fact_mofa_a+ " ���˺���"+absorb_desc+chuantou_desc+"\n";
						tell_object(this_object(),s);
						tell_object(enemy,s1);

						//�������ֵ
						int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());	
						//������ȡ 
						int life_damage = enemy->get_cur_life()-attack_fact;
						if(life_damage<=0){
							//������������ѵ��˴ӳ���б������
							this_object()->clean_targets(enemy);
							//�����������������,killing�ж���ɱ¾���Ǿ���
							if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
								enemy->set_life(1);
								tell_object(this_object(),"���ھ�����սʤ�� "+enemy->query_name_cn()+" ��\n");
								tell_object(enemy,this_object()->query_name_cn()+"�ھ�����սʤ���㣡\n");
								enemy->_clean_fight();
								_clean_fight();
								enemy=0;
							}
							else{
								enemy->fight_die();
								enemy=0;
							}
							return;
						}
						enemy->set_life(life_damage);
						//if(this_object()->is("player")){
						//ս���л��жԷ���������������ĥ��
						this_object()->reduce_fight_wield_weapon(1);
						//ս���б������߻��У�������ĥ��
						enemy->reduce_fight_wear_armor(1);
						//}
					}
					else{
						//δ����	
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+"), �����Է��ֿ��ˡ�";
						s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+"��������ֿ���";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());	
					}
					return;
				}
				else{
					//��ʹ�ù��ļ���δ��ȴ,��ʾ������
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*   ����������     */
			else if(f_cur_skill->s_skill_type=="phy"){
				//werror("===========skill_level:"+skill_level+"\n");
				string s_name_cn=f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
				//�ȿ��Ƿ�������������û�оͲ��ܹ���
				mapping items = this_object()->query_equip();//[string:object]
				if(!items["single_main_weapon"]&&!items["double_main_weapon"])
				{
					s += "�ü�����Ҫװ��������������ʩ�š�";
					tell_object(this_object(),s+"\n");
					return;
				}
				//�ж��ü�����ȴʱ����ж�
				//�ж���ȴʱ��
				int s_phy_damage = f_cur_skill->query_performs_attack(skill_level);
				int s_weapon_add = f_cur_skill->query_performs_per(skill_level);
				if(s_cold <= 1){
					//�ü����ڱ��л�����ȴ��
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//�����ܹ�����attack���̣����������Ҳ��������м���
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					//�ȼ�ѹ��
					int difflevel = enemy->query_level()-this_object()->query_level();
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){
						//������ ~
						if(this_object()->weapon_type=="double_main")
							attack(s_phy_damage,s_weapon_add,"double_main",s_name_cn,f_cur_skill->query_name());
						else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
							attack(s_phy_damage,s_weapon_add,"single_main",s_name_cn,f_cur_skill->query_name());
					}
					else{
						//δ����	
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+"), ��δ���жԷ���";
						s1 += this_object()->query_name_cn()+"ʩ�� "+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")����δ�����㡣"; 
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());	
					}
					return;
				}
				else{
					//��ʹ�ù��ļ���δ��ȴ,��ʾ������
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    ʩ�ŵ���dot����    */
			else if(f_cur_skill->s_skill_type=="dot"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//�ȼ�ѹ��
					int difflevel = enemy->query_level()-this_object()->query_level();          
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){ //������~
						//��¼dot���ܵ�����
						enemy->set_debuff("dot",0,name);
						//��¼dot��ÿ���˺�
						enemy->set_debuff("dot",1,f_cur_skill->query_performs_attack(skill_level));
						//��¼dotʣ��ʱ��
						enemy->set_debuff("dot",2,f_cur_skill->query_s_lasttime(skill_level));

						//�������ֵ,dot�ĳ����ʱ��Ϊ20
						int hate=(int)(20*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						s1 += this_object()->query_name_cn()+"����ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");

						//if(this_object()->is("player")){
						//ս���л��жԷ���������������ĥ��
						this_object()->reduce_fight_wield_weapon(1);
						//ս���б������߻��У�������ĥ��
						enemy->reduce_fight_wear_armor(1);
						//}
					}
					else { //δ����
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")�������Է��ֿ��ˡ�";
						s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")��������ֿ���";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());
						return;
					}
				}
				else {
					//���ܻ�δ��ȴ
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*      ʩ�ŵ������似��     */
			else if(f_cur_skill->s_skill_type=="curse"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;
					//�ȼ�ѹ��
					int difflevel = enemy->query_level()-this_object()->query_level();          
					if(difflevel<0)
						difflevel=0;
					int myhitte= this_object()->query_if_hitte();
					int h = (int)(myhitte-difflevel*5);
					if(h<30)
						h=30;
					if(random(100)<=h){ //������~
						//��¼���������
						enemy->set_debuff("curse",0,f_cur_skill->s_curse_type);
						//��¼�����ֵ
						enemy->set_debuff("curse",1,f_cur_skill->query_performs_attack(skill_level));
						//��¼����ĳ���ʱ��
						enemy->set_debuff("curse",2,f_cur_skill->query_s_lasttime(skill_level));

						//�������ֵ,curse�ĳ����ʱ��Ϊ20
						int hate=(int)(20*skills_hate["test"]/100);
						enemy->flush_targets(this_object(),hate);

						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						s1 += this_object()->query_name_cn()+"����ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());

						//ս���л��жԷ���������������ĥ��
						this_object()->reduce_fight_wield_weapon(1);
						//ս���б������߻��У�������ĥ��
						enemy->reduce_fight_wear_armor(1);
					}
					else { //δ����
						s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+"), �����Է��ֿ��ˡ�";
						s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")��������ֿ���";
						tell_object(this_object(),s+"\n");
						tell_object(enemy,s1+"\n");
						//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
						skills_level_check(f_cur_skill->query_name());
						return;
					}
				}
				else {
					//δ��ȴ
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
			/*    ʩ�ŵ�����ħ��    */
			else if(f_cur_skill->s_skill_type=="buff"){
				if(s_cold <= 1){
					this_object()->set_mofa(this_object()->get_cur_mofa()-s_cast);
					this_object()->timeCold = 2;
					this_object()->f_skills[name] = f_cur_skill->query_s_delayTime(skill_level)+1;

					//��¼buff������
					this_object()->set_buff("buff",0,f_cur_skill->s_curse_type);
					//��¼buff��ֵ
					int tmp_int=f_cur_skill->query_performs_attack(skill_level);
					if(f_cur_skill->s_curse_type == "absorb"){
						if(this_object()->query_profeId()=="wuyao"||this_object()->query_profeId()=="yushi"){
							tmp_int += (int)(this_object()->query_think()*3);
						}
						else
							tmp_int += (int)(this_object()->query_think()*3/2);
					}
					this_object()->set_buff("buff",1,tmp_int);
					//��¼buff�ĳ���ʱ��
					this_object()->set_buff("buff",2,f_cur_skill->query_s_lasttime(skill_level));

					//�������ֵ,buff�ĳ����ʱ��Ϊ10
					int hate=(int)(10*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);

					s += "��ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
					s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")";
					tell_object(this_object(),s+"\n");
					tell_object(enemy,s1+"\n");
					//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
					//�����ų��˿����ĳ嶯����
					if(f_cur_skill->query_name() != "chongdong")
						skills_level_check(f_cur_skill->query_name());
					return;
				}
				else {
					//δ��ȴ
					s += "�ü��ܻ���Ҫ"+(s_cold-1)+"����ȴʱ��,�޷�ʹ�á�";
					tell_object(this_object(),s+"\n");
					return;
				}
			}
		}
		else {
			//���㹻�ķ���
			s += "��������������޷�ʩ��"+f_cur_skill->query_name_cn()+"(�ȼ�"+skill_level+")��";
			tell_object(this_object(),s+"\n");
			return;
		}
	}
	else {
		//û�����ּ���
		string stmp = "��Ҫʩ��ʲô���ܣ�";
		tell_object(this_object(),stmp+"\n");
		return;
	}
}

//boss�����ͷ�
void boss_perform(string name){
	//�������ж�......
	if(enemy==0)
		return;
	object f_cur_skill;//��ǰʹ�ü��ܶ���
	string s = "";//�����Լ���ս������
	string s1=""; //������˵�ս������
	f_cur_skill = (object)MUD_SKILLSD[name];
	if(f_cur_skill){
		//�����ж������ּ���
		//���ж��Ƿ����㹻�ķ���ʩ�Ÿü���
		string mofa_type=f_cur_skill->s_skill_type; //�õ�ħ������
		//���㹻�ķ���
		//�ж��������Ƿ�������
		/*   ������������     */
		if(mofa_type!="phy"&&mofa_type!="dot"&&mofa_type!="curse"&&mofa_type!="buff"){
			int mofa_a_low=0; //��������������
			int mofa_a_high=0; //��������������
			int mofa_a=0; //ȡ�÷����������漴ֵ
			int mofa_defend=0; //���˵�ħ������
			int fact_mofa_a=0; //���յķ����˺�
			int myhitte= this_object()->query_if_hitte();
			//������ ~
			//�õ��������ܵ��˺��漴ֵ
			mofa_a_low = f_cur_skill->query_performs_mofa_attack_low();	
			mofa_a_high = f_cur_skill->query_performs_mofa_attack_high();
			mofa_a = random(mofa_a_high-mofa_a_low+1)+mofa_a_low;
			//�ټ���װ�����Դ����ķ����˺�����
			//����Ҳ����߷�����liaocheng��07/4/16���
			mofa_a +=this_object()->query_equip_add(mofa_type)+this_object()->query_equip_add("mofa_all")+(int)(this_object()->query_think());
			if(f_cur_skill->is_aoe){
				array(object) enemys;
				//��aoeħ��
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						if(enemys[i]){
							if(myhitte<0)
								myhitte=0;
							if(random(100)<=myhitte){
								//��������Ӧ�ĵ��˵�ħ������
								switch(mofa_type) {
									case "huo_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("huoyan_defend");
									break;
									case "bing_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("bingshuang_defend");
									break;
									case "feng_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("fengren_defend");
									break;
									case "du_mofa_attack":
										mofa_defend = enemys[i]->query_equip_add("du_defend");
									break;
									default :
									mofa_defend = 0;
									break;
								}
								mofa_defend += enemys[i]->query_equip_add("all_mofa_defend");
								//�����ʵ�ʵ�ħ���˺�ֵ
								fact_mofa_a=mofa_a-(int)(mofa_a*mofa_defend/400);
								//�жϱ���
								int b = this_object()->query_if_baoji();
								s1+=this_object()->query_name_cn()+"ʩ�� "+f_cur_skill->query_name_cn();
								if(b){
									//������ ~
									fact_mofa_a=(int)fact_mofa_a*150/100;
									s1 += "�������˱���Ч����";

								}

								//���������buff��ħ���������˺�liaocheng 07/4/9
								int	attack_fact = fact_mofa_a;
								string absorb_desc = "";
								if(enemys[i]->query_buff("buff",0)=="absorb"){
									if((int)enemys[i]->query_buff("buff",1) >= fact_mofa_a){
										int remain = (int)enemys[i]->query_buff("buff",1) - fact_mofa_a;
										attack_fact= 0;
										absorb_desc = "(������)";
										if(remain <= 0)
											enemys[i]->clean_buff("buff");
										else
											enemys[i]->set_buff("buff",1,remain);
									}
									else{
										attack_fact = fact_mofa_a - (int)enemys[i]->query_buff("buff",1); 
										absorb_desc = "("+enemys[i]->query_buff("buff",1)+"�㱻����)";
										enemys[i]->clean_buff("buff");
									}
								}
								if(enemys[i]->query_buff("buff2",0)=="absorb"){
									if((int)enemys[i]->query_buff("buff2",1) >= fact_mofa_a){
										int remain = (int)enemys[i]->query_buff("buff2",1) - fact_mofa_a;
										attack_fact= 0;
										absorb_desc = "(������)";
										if(remain <= 0)
											enemys[i]->clean_buff("buff2");
										else
											enemys[i]->set_buff("buff2",1,remain);
									}
									else{
										attack_fact = fact_mofa_a - (int)enemys[i]->query_buff("buff2",1); 
										absorb_desc = "("+enemys[i]->query_buff("buff2",1)+"�㱻����)";
										enemys[i]->clean_buff("buff2");
									}
								}
								s1 += "��������� " +fact_mofa_a+ " ���˺���"+absorb_desc+"\n";
								tell_object(enemys[i],s1);

								//�������ֵ
								int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
								enemys[i]->flush_targets(this_object(),hate);

								//������ȡ 
								int life_damage = enemys[i]->get_cur_life()-attack_fact;
								if(life_damage<=0){
									//������������ѵ��˴ӳ���б������
									this_object()->clean_targets(enemys[i]);
									enemys[i]->fight_die();
								}
								else{
									enemys[i]->set_life(life_damage);
									enemy->reduce_fight_wear_armor(1);
								}
							}
							else{
								//δ����
								s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"��������ֿ���";
								tell_object(enemys[i],s1+"\n");
							}
						}
					}
				}
				return;
			}
			//����aoe������ԭ����·��
			if(myhitte<0)
				myhitte=0;
			if(random(100)<=myhitte){
				switch(mofa_type) {
					case "huo_mofa_attack":
						mofa_defend = enemy->query_equip_add("huoyan_defend");
					break;
					case "bing_mofa_attack":
						mofa_defend = enemy->query_equip_add("bingshuang_defend");
					break;
					case "feng_mofa_attack":
						mofa_defend = enemy->query_equip_add("fengren_defend");
					break;
					case "du_mofa_attack":
						mofa_defend = enemy->query_equip_add("du_defend");
					break;
					default:
					mofa_defend = 0;
					break;
				}
				mofa_defend += enemy->query_equip_add("all_mofa_defend");
				//�����ʵ�ʵ�ħ���˺�ֵ
				fact_mofa_a=mofa_a-(int)(mofa_a*mofa_defend/400);
				//�жϱ���
				int b = this_object()->query_if_baoji();
				s1+=this_object()->query_name_cn()+"����ʩ��"+f_cur_skill->query_name_cn();
				if(b){
					//������ ~
					fact_mofa_a=(int)fact_mofa_a*150/100;
					s1 += "�������˱���Ч����";

				}

				//���������buff��ħ���������˺�liaocheng 07/4/9
				int	attack_fact = fact_mofa_a;
				string absorb_desc = "";
				if(enemy->query_buff("buff",0)=="absorb"){
					if((int)enemy->query_buff("buff",1) >= fact_mofa_a){
						int remain = (int)enemy->query_buff("buff",1) - fact_mofa_a;
						attack_fact= 0;
						absorb_desc = "(������)";
						if(remain <= 0)
							enemy->clean_buff("buff");
						else
							enemy->set_buff("buff",1,remain);
					}
					else{
						attack_fact = fact_mofa_a - (int)enemy->query_buff("buff",1); 
						absorb_desc = "("+enemy->query_buff("buff",1)+"�㱻����)";
						enemy->clean_buff("buff");
					}
				}
				if(enemy->query_buff("buff2",0)=="absorb"){
					if((int)enemy->query_buff("buff2",1) >= fact_mofa_a){
						int remain = (int)enemy->query_buff("buff2",1) - fact_mofa_a;
						attack_fact= 0;
						absorb_desc = "(������)";
						if(remain <= 0)
							enemy->clean_buff("buff2");
						else
							enemy->set_buff("buff2",1,remain);
					}
					else{
						attack_fact = fact_mofa_a - (int)enemy->query_buff("buff2",1); 
						absorb_desc = "("+enemy->query_buff("buff2",1)+"�㱻����)";
						enemy->clean_buff("buff2");
					}
				}
				s1 += "����� " +fact_mofa_a+ " ���˺���"+absorb_desc+"\n";
				tell_object(enemy,s1);

				//�������ֵ
				int hate=(int)(fact_mofa_a*skills_hate["test"]/100);
				enemy->flush_targets(this_object(),hate);

				//������ȡ 
				int life_damage = enemy->get_cur_life()-attack_fact;
				if(life_damage<=0){
					//������������ѵ��˴ӳ���б������
					this_object()->clean_targets(enemy);
					//�����������������,killing�ж���ɱ¾���Ǿ���
					if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
						enemy->set_life(1);
						tell_object(this_object(),"���ھ�����սʤ�� "+enemy->query_name_cn()+" ��\n");
						tell_object(enemy,this_object()->query_name_cn()+"�ھ�����սʤ���㣡\n");
						enemy->_clean_fight();
						_clean_fight();
						enemy=0;
					}
					else{
						enemy->fight_die();
						enemy=0;
					}
					return;
				}
				enemy->set_life(life_damage);
				//ս���б������߻��У�������ĥ��
				enemy->reduce_fight_wear_armor(1);
			}
			else{
				//δ����	
				s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"��������ֿ���";
				tell_object(enemy,s1+"\n");
			}
			return;
		}
		//   --- ���������� ---    
		else if(f_cur_skill->s_skill_type=="phy"){
			string s_name_cn=f_cur_skill->query_name_cn();
			//�ж���ȴʱ��
			int s_phy_damage = f_cur_skill->query_performs_attack();
			int s_weapon_add = f_cur_skill->query_performs_per();
			//�ü����ڱ��л�����ȴ��
			//�����ܹ�����attack���̣����������Ҳ��������м���
			//�ȼ�ѹ��
			int myhitte= this_object()->query_if_hitte();
			if(myhitte<0)
				myhitte=0;
			if(random(100)<=myhitte){
				//������ ~
				//if(this_object()->weapon_type=="double_main")
				attack(s_phy_damage,s_weapon_add,"double_main",s_name_cn,f_cur_skill->query_name());
				//else if(this_object()->weapon_type=="single_main"||this_object()->weapon_type=="both")
				//	attack(s_phy_damage,s_weapon_add,"single_main",s_name_cn,f_cur_skill->query_name());

			}
			else{
				//δ����	
				s1 += this_object()->query_name_cn()+"ʩ�� "+f_cur_skill->query_name_cn()+"����δ�����㡣"; 
				tell_object(enemy,s1+"\n");
			}
			return;
		}
		//  ---  ʩ�ŵ���dot���� ---
		else if(f_cur_skill->s_skill_type=="dot"){
			if(f_cur_skill->is_aoe){
				//��aoeħ��
				array(object) enemys;
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						int myhitte= this_object()->query_if_hitte();
						if(myhitte<0)
							myhitte=0;
						if(random(100)<=myhitte){   //������~
							//��¼dot���ܵ�����
							enemys[i]->set_debuff("dot",0,name);
							//��¼dot��ÿ���˺�
							enemys[i]->set_debuff("dot",1,f_cur_skill->query_performs_attack());
							//��¼dotʣ��ʱ��
							enemys[i]->set_debuff("dot",2,f_cur_skill->query_s_lasttime());

							//�������ֵ,dot�ĳ����ʱ��Ϊ20
							int hate=(int)(20*skills_hate["test"]/100);
							enemys[i]->flush_targets(this_object(),hate);
							s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn();
							tell_object(enemys[i],s1+"\n");

							//ս���б������߻��У�������ĥ��
							enemys[i]->reduce_fight_wear_armor(1);
						}
						else { //δ����
							s1 += this_object()->query_name_cn()+"ʩ�� "+f_cur_skill->query_name_cn()+"��������ֿ���";
							tell_object(enemys[i],s1+"\n");
						}
					}
				}
				return;
			}
			//��һ·��
			int myhitte= this_object()->query_if_hitte();
			if(myhitte<0)
				myhitte=0;
			if(random(100)<=myhitte){   //������~
				//��¼dot���ܵ�����
				enemy->set_debuff("dot",0,name);
				//��¼dot��ÿ���˺�
				enemy->set_debuff("dot",1,f_cur_skill->query_performs_attack());
				//��¼dotʣ��ʱ��
				enemy->set_debuff("dot",2,f_cur_skill->query_s_lasttime());

				//�������ֵ,dot�ĳ����ʱ��Ϊ20
				int hate=(int)(20*skills_hate["test"]/100);
				enemy->flush_targets(this_object(),hate);

				s1 += this_object()->query_name_cn()+"����ʩ����"+f_cur_skill->query_name_cn();
				tell_object(enemy,s1+"\n");

				//ս���б������߻��У�������ĥ��
				enemy->reduce_fight_wear_armor(1);
			}
			else { //δ����
				s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"��������ֿ���";
				tell_object(enemy,s1+"\n");
				return;
			}
		}
		//    ---  ʩ�ŵ������似��  ---
		else if(f_cur_skill->s_skill_type=="curse"){
			if(f_cur_skill->is_aoe){
				//��aoeħ��
				array(object) enemys;
				enemys = this_object()->get_all_targets();
				if(enemys && sizeof(enemys)){
					for(int i=0;i<sizeof(enemys);i++){
						s1 = "";
						int myhitte= this_object()->query_if_hitte();
						if(myhitte<0)
							myhitte=0;
						if(random(100)<=myhitte){ //������~
							//��¼���������
							enemys[i]->set_debuff("curse",0,f_cur_skill->s_curse_type);
							//��¼�����ֵ
							enemys[i]->set_debuff("curse",1,f_cur_skill->query_performs_attack());
							//��¼����ĳ���ʱ��
							enemys[i]->set_debuff("curse",2,f_cur_skill->query_s_lasttime());

							//�������ֵ,curse�ĳ����ʱ��Ϊ20
							int hate=(int)(20*skills_hate["test"]/100);
							enemys[i]->flush_targets(this_object(),hate);

							s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn();
							tell_object(enemys[i],s1+"\n");

							//ս���б������߻��У�������ĥ��
							enemys[i]->reduce_fight_wear_armor(1);
						}
						else { //δ����
							s1 += this_object()->query_name_cn()+"ʩ�� "+f_cur_skill->query_name_cn()+"��������ֿ���";
							tell_object(enemys[i],s1+"\n");
						}
					}
					return;
				}
				//��һ·��
				int myhitte= this_object()->query_if_hitte();
				if(myhitte<0)
					myhitte=0;
				if(random(100)<=myhitte){ //������~
					//��¼���������
					enemy->set_debuff("curse",0,f_cur_skill->s_curse_type);
					//��¼�����ֵ
					enemy->set_debuff("curse",1,f_cur_skill->query_performs_attack());
					//��¼����ĳ���ʱ��
					enemy->set_debuff("curse",2,f_cur_skill->query_s_lasttime());

					//�������ֵ,curse�ĳ����ʱ��Ϊ20
					int hate=(int)(20*skills_hate["test"]/100);
					enemy->flush_targets(this_object(),hate);

					s1 += this_object()->query_name_cn()+"����ʩ����"+f_cur_skill->query_name_cn();
					tell_object(enemy,s1+"\n");
					//ս���б������߻��У�������ĥ��
					enemy->reduce_fight_wear_armor(1);
				}
				else { //δ����
					s1 += this_object()->query_name_cn()+"����ʩ�� "+f_cur_skill->query_name_cn()+"��������ֿ���";
					tell_object(enemy,s1+"\n");
				}
			}
			return;
		}
		//  ---  ʩ�ŵ�����ħ�� ---
		else if(f_cur_skill->s_skill_type=="buff"){
			//��¼buff������
			this_object()->set_buff("buff",0,f_cur_skill->s_curse_type);
			//��¼buff��ֵ
			this_object()->set_buff("buff",1,f_cur_skill->query_performs_attack());
			//��¼buff�ĳ���ʱ��
			this_object()->set_buff("buff",2,f_cur_skill->query_s_lasttime());

			//�������ֵ,buff�ĳ����ʱ��Ϊ10
			int hate=(int)(10*skills_hate["test"]/100);
			enemy->flush_targets(this_object(),hate);

			s1 += this_object()->query_name_cn()+"ʩ����"+f_cur_skill->query_name_cn();
			tell_object(enemy,s1+"\n");
			return;
		}
	}
	else {
		//û�����ּ���
		werror("-----error boss_perform the skill "+name+" is not exist------\n");
		return;
	}
}


//ս�������㷨,��ͨ��������ʩ������������ʱ���õĽӿ�
private void attack(int skill_add,int skill_add_per,string type,string skill_name_cn,void|string name_skill){
	if(enemy==0){
		return;
	}
	string fight_action_desc="";
	//���ι����ɹ���������˺�ֵ
	int attack_a = 0;
	//�����ħ����buff����Ϊ���պ���˺�
	int attack_fact = 0;

	int self=this_object()->query_base_damage(); //�õ���������
	int add=0; //�õ����������˺�
	int add_per=0; //�õ����������˺��ٷֱ�
	int h;
	//�����жϹ����ߵ����м��㣺�����ߵ�������+װ���ĸ�������+���ܵ�����(������100%���м���)
	if(skill_name_cn!=""){
		h=100; //�����ܹ�������perform()���Ѿ����˵ȼ�ѹ�ƣ����ﲻ�����չ��������ж�
	}
	else{
		int hitte_a = this_object()->query_if_hitte();//mudlib/inherit/feature/char.pike�нӿ�
		int difflevel = enemy->query_level()-this_object()->query_level(); 
		if(difflevel<0)
			difflevel=0;
		h = (int)(hitte_a-difflevel*5);
		if(this_object()->is_both_weapons) //˫�������еĳͷ�
			h -= 10;
		if(h<30)
			h=30;
	}
	//ֻ�й����������ˣ�����Ҫ������һ������	
	if(random(100)<h){
		//���ܼ��㣺���㱻�����ߵ�������+װ��������	
		int dodge_e = enemy->query_if_dodge();
		//ֻ�б�������δ�����ܣ�����Ҫ������һ������
		int dodgechuantou_add=this_object()->query_equip_add("dodgechuantou_add");
		//�������ܵ��Ժ����ж��Ƿ��������ܣ��������ܴ�͸��ֵ�������������� ����������
		string dodgechuantou_desc="";
		if(dodge_e==1 && dodgechuantou_add>0 && random(100)<=dodgechuantou_add){
			dodge_e=0;//��Ȼ����ˣ����ֱ��������ˣ���Ϊ����������Ч��
			dodgechuantou_desc="\n(���ܴ�͸��Ч�����ӶԷ����ܼ��ܣ���Ĺ������� ��"+enemy->query_name_cn()+"��)\n";
		}
		if(dodge_e==0){

			//���������������ħ���˺�����
			//
			///////////////////////////////

			//if(this_object()->is("player")){	
			//ս���л��жԷ���������������ĥ��
			this_object()->reduce_fight_wield_weapon(1);
			//ս���б������߻��У�������ĥ��
			enemy->reduce_fight_wear_armor(1);
			//}
			////////////////�������˺�����//////////////////////////////////////
			//1.��ҵ������˺�(����˺�������֮���һ�������ֵ)
			if(type=="double_main" || type=="single_main") { //���װ��������������
				//�õ����������˺�
				add=this_object()->main_attack_attri_add+skill_add; 
				//�õ����������˺��ٷֱ�
				//add_per=add+(add*this_object()->main_attack_attri_add_per*10)/100+skill_add_per; 
				add_per=this_object()->main_attack_attri_add_per*10+skill_add_per;//��ȷ�Ĺ�ʽ
				attack_weapon = this_object()->query_main_equiped_attack();//mudlib/inherit/feature/attack.pike�ж���Ľӿ�

				//����
				if(fight_desc_arg_main=="beast"||fight_desc_arg_main=="bird"||fight_desc_arg_main=="fish"||fight_desc_arg_main=="amphibian"||fight_desc_arg_main=="bugs")
					fight_action_desc=query_fight_desc(fight_desc_arg_main);
				else {
					if(skill_name_cn=="")
						fight_action_desc=this_object()->cur_main_weapon_name+"��"+query_fight_desc(fight_desc_arg_main);
					else
						fight_action_desc=this_object()->cur_main_weapon_name;
				}
			}

			else if(type=="other") {
				//�õ����������˺�
				add=this_object()->other_attack_attri_add+skill_add;
				//�õ����������˺��ٷֱ�
				//add_per=add+(add*this_object()->other_attack_attri_add_per*10)/100+skill_add_per; 
				add_per=this_object()->other_attack_attri_add_per*10+skill_add_per;//��ȷ�Ĺ�ʽ	
				attack_weapon = this_object()->query_other_equiped_attack();
				if(skill_name_cn=="")
					fight_action_desc = this_object()->cur_other_weapon_name+"��"+query_fight_desc(fight_desc_arg_other);
				else 
					fight_action_desc=this_object()->cur_main_weapon_name;
			}

			//�õ�δ����ǰ���ܹ����˺�,�������ⲻ��Ҫ�ĸ�������
			int total_attack=0;
			if(add_per) 
				total_attack = attack_weapon+(int)(attack_weapon*add_per/100)+add+self;
			else 
				total_attack = attack_weapon+add+self;

			//npc����������������3
			if(this_object()->is("npc")){
				total_attack = total_attack/3;
			}
			//3.�����Ƿ��б���������У�����ӳɱ�����֮��Ĺ���ֵ=���й���ֵ�ܺ�*����/100	
			int baoji_a = this_object()->query_if_baoji(enemy);//����һ������ֵ��Ϊ%�ķ�����ʽ�ṩ
			if(baoji_a==1){
				total_attack = (int)((total_attack)*150/100);
				int renxing = enemy->query_equip_add("renxing");
				if(renxing){
				//����Է������ԣ���ÿ40�����Լ���2%����������˺������㹫ʽΪ��ʵ�ʹ���ֵ=������Ĺ���ֵ - ������Ĺ��� * (����/40) * 2%;Ϊ�˾���С�ļ������ʰѹ�ʽת��Ϊ ʵ�ʹ���ֵ=������Ĺ���ֵ - (������Ĺ��� * ���� *2��)/(40*100)  added by caijie 08/12/04
					total_attack -= (int)((total_attack * renxing * 2)/(40*100));
				}
			}
			////////////////���ϱ������߷�������õ����������˺�ֵattack_a/////////////////////
			defend = enemy->query_defend_power();
			
			
			int division = this_object()->query_level()*120;//������������㷨��
			if(this_object()->query_level()<70){
				division=8000;//����֮ǰ��Ĭ��ֵ
			}
			string u_profe = this_object()->query_profeId();
			if(u_profe=="yinggui"){//��Ӱ��������������������Է��ķ�����ĸ����4����һ��Է�����1������
			//���ڷ�ʦ��ħ���˺����ڴ�֮�����ӵģ����Զ�Ӱ�����������ְҵ���˼ӳɡ�
				division=this_object()->query_level()*450;
				//werror("===========wuyaoxiuzheng:\n");
			}
			//werror("=======================division:"+division+" u_profe:"+u_profe+"\n");
			//werror("=======================enemy defend:"+defend+"\n");
			//�����ӵ����� ����͸�����ӷ�����ֱ�Ӽ������ս����
			int wulichuantou_add=this_object()->query_equip_add("wulichuantou_add");
			attack_a = (total_attack - (int)(defend*total_attack)/division);
			attack_a+=wulichuantou_add;//��������͸
			if(name_skill && skill_name_cn != "" && name_skill != "xueranjiangshan" && name_skill != "xueranjiangshan2") 
				attack_a = attack_a*3/2;//Ϊ������ܹ����ܣ����ܹ�����ǿ1.5��
			//���ܵ��˺��ٷֱ�buff�������ӣ���liaocheng��080827���
			int per_tmp;
			if(this_object()->query_buff("spec_attack_buff",0) != "none"){
				per_tmp = this_object()->query_buff("spec_attack_buff",1);
			}
			if(this_object()->query_buff("70_skill_buff",0) == "lieshanmengji"){
				per_tmp += this_object()->query_buff("70_skill_buff",1);
			}
			if(per_tmp)
				attack_a += total_attack*per_tmp/100;
			//�����˺��ļ�����������
			if(enemy->query_buff("70_skill_buff") == "baofengfeixue")
				attack_a = attack_a*70/100;
			//����70�������˺�����
			string reflect_desc = "";
			if(enemy->query_buff("70_skill_buff",0) == "fanzhuanyiji"){
				int attack_reflect = attack_a*30/100;
				attack_a = attack_a - attack_reflect;
				int life_left = this_object()->get_cur_life()-attack_reflect;
				if(life_left<0)
					life_left = 0;
				this_object()->set_life(life_left);
				reflect_desc = "("+attack_reflect+"������)";
			}
			//������������������ӵ�ħ���˺�(��+3�����˺�)
			attack_huoyan_add = get_attack_mofa_add("huoyan_defend",this_object()->huo_add,enemy);
			attack_bingshuang_add = get_attack_mofa_add("bingshuang_defend",this_object()->bing_add,enemy);
			attack_fengren_add = get_attack_mofa_add("fengren_defend",this_object()->feng_add,enemy);
			attack_dusu_add = get_attack_mofa_add("dusu_defend",this_object()->du_add,enemy);
			//Ӱ��70�������˺���ߵ�Ч��
			if(this_object()->query_buff("70_skill_buff",0)=="cuidu")
				attack_dusu_add += attack_dusu_add/2;

			attack_a += attack_huoyan_add+attack_bingshuang_add+attack_fengren_add+attack_dusu_add;
			//���ڵ�attack_a�������յ��˺�ֵ
			if (attack_a<=0)
				attack_a=random(5);

			//���������buff��ħ���������˺�liaocheng 07/4/9
			attack_fact = attack_a;
			string absorb_desc = "";
			if(enemy->query_buff("buff",0)=="absorb"){
				if((int)enemy->query_buff("buff",1) >= attack_a){
					int remain = (int)enemy->query_buff("buff",1) - attack_a;
					attack_fact = 0;
					absorb_desc = "(������)";
					if(remain <= 0)
						enemy->clean_buff("buff");
					else
						enemy->set_buff("buff",1,remain);
				}
				else{
					attack_fact = attack_a - (int)enemy->query_buff("buff",1); 
					absorb_desc = "("+enemy->query_buff("buff",1)+"�㱻����)";
					enemy->clean_buff("buff");
				}
			}
			if(enemy->query_buff("buff2",0)=="absorb"){
				if((int)enemy->query_buff("buff2",1) >= attack_a){
					int remain = (int)enemy->query_buff("buff2",1) - attack_a;
					attack_fact = 0;
					absorb_desc = "(������)";
					if(remain <= 0)
						enemy->clean_buff("buff2");
					else
						enemy->set_buff("buff2",1,remain);
				}
				else{
					attack_fact = attack_a - (int)enemy->query_buff("buff2",1); 
					absorb_desc = "("+enemy->query_buff("buff2",1)+"�㱻����)";
					enemy->clean_buff("buff2");
				}
			}
			//�������͸�����㣬��Ҫ��ǰ����ʾ�����
			string chuantou_desc = "";
			if(wulichuantou_add>0){
				chuantou_desc = "��"+wulichuantou_add+" ������͸��";
			}
			//�����������вֵ
			int hate=(int)(attack_a*skills_hate["test"]/100);
			enemy->flush_targets(this_object(),hate);
			if(!enemy->in_combat)
				enemy->_fight(this_object());
			////////////////////////ս������///////////////////////////////////////////////
			if(baoji_a==1) {
				if(skill_name_cn==""){
					tell_object(this_object(),"�����"+fight_action_desc+"����������Ч������"+enemy->query_name_cn()+"�����"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"������Ĺ�����������Ч���������"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
				}
				else {
					tell_object(this_object(),"�����"+fight_action_desc+"ʩչ"+skill_name_cn+"����������Ч������"+enemy->query_name_cn()+"�����"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"ʩչ"+skill_name_cn+"������Ĺ�����������Ч���������"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
					skills_level_check(name_skill);
				}
			}
			else {
				if(skill_name_cn==""){
					tell_object(this_object(),"�����"+fight_action_desc+"����"+enemy->query_name_cn()+"�����"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+fight_action_desc+"�����������"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//tell_object(enemy,this_object()->query_name_cn()+"����"+fight_action_desc+"�����������"+attack_a+"���˺�"+absorb_desc+"\n");
				}
				else {
					tell_object(this_object(),"�����"+fight_action_desc+"ʩչ"+skill_name_cn+"����"+enemy->query_name_cn()+"�����"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					tell_object(enemy,this_object()->query_name_cn()+"ʩչ"+skill_name_cn+"�����������"+attack_a+"���˺�"+absorb_desc+""+reflect_desc+chuantou_desc+dodgechuantou_desc+"\n");
					//���������,��Ҫ�Է��ȼ����Լ��൱���Ż���������������
					if(name_skill != "xueranjiangshan")
						skills_level_check(name_skill);
				}
			}
			int life_damage = enemy->get_cur_life()-attack_fact;
			if(life_damage<=0){
				//������������ѵ��˴ӳ���б������
				this_object()->clean_targets(enemy);
				//�����������������,killing�ж���ɱ¾���Ǿ���
				if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
					enemy->set_life(1);
					tell_object(this_object(),"���ھ�����սʤ�� "+enemy->query_name_cn()+" ��\n");
					tell_object(enemy,this_object()->query_name_cn()+"�ھ�����սʤ���㣡\n");
					enemy->_clean_fight();
					_clean_fight();
				}
				else
					enemy->fight_die();
				enemy=0;
				return;
			}
			enemy->set_life(life_damage);
		}
		//���������жԷ��������Է�������
		else{
			if(skill_name_cn==""){
				tell_object(this_object(),"�����ι������Է������˹�ȥ!\n");
				tell_object(enemy,"���������"+this_object()->query_name_cn()+"����ι���.\n");
			}
			else {
				tell_object(this_object(),"���"+skill_name_cn+"���Է������˹�ȥ!\n");
				tell_object(enemy,"���������"+this_object()->query_name_cn()+"��"+skill_name_cn+".\n");
			}
		}
	}
	//�����߱��ι���û������
	else{
		if(skill_name_cn==""){
			tell_object(this_object(),"��Ĺ���û�л��жԷ�!\n");
			tell_object(enemy,this_object()->query_name_cn()+"û�л����㡣\n");
		}
		else {
			tell_object(this_object(),"���"+skill_name_cn+"û�л��жԷ�!\n");
			tell_object(enemy,this_object()->query_name_cn()+"��"+skill_name_cn+"û�л�����.\n");
		}
	}
}
//��֤��perform�Ƿ�����
private int validate_perform(string arg){
	return 0;
}
private void heart_beat_action(){
	//�����Ҳ�������������̣���Ϊ�˴�������dot�������������dot�����Լ��������м�ȥ�Լ���Ѫ��
	//Ҫ��Ѫ��Ϊ���ˣ����ʾ�Լ����������������Լ���������ͨ�����this_object()->fight_die()����
	//��������������̨�ᱨ�����ֻ���ڵ���ÿ������ʱ����Լ���Ѫ����Ȼ����˵���
	//enemy->fight_die()������Լ�����������
	if(enemy&&enemy->get_cur_life()<=0&&enemy->in_combat){
		if(enemy->query_raceId() == this_object()->query_raceId() && enemy->kill_flag == 0 && this_object()->kill_flag == 0){
			enemy->set_life(1);
			tell_object(this_object(),"���ھ�����սʤ�� "+enemy->query_name_cn()+" ��\n");
			tell_object(enemy,this_object()->query_name_cn()+"�ھ�����սʤ���㣡\n");
			enemy->_clean_fight();
			_clean_fight();
			enemy=0;
		}
		else{
			enemy->fight_die();
			enemy = 0;
		}
		return;
	}
	//�Լ������󽫲������κζ������ȴ���������
	//if(enemy&&this_object()->get_cur_life()<=0)
	//	return;

	enemy=this_object()->get_target(); //���λ�ò��ԣ�Ҫ��ĥ��
	if(enemy==0){
		//����ط���������������������ս��״̬���޷��˳������⡣������
		_clean_fight();
		return;
	}
	else if(environment(this_object())!=environment(enemy)){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
		if(this_object()->if_targets_null())
			_clean_fight();
		return;
	}
	else{
		this_object()->timeCount++;
		if(this_object()->timeCold>0)
			this_object()->timeCold--;
		if(this_object()->eat_timeCold>0)
			this_object()->eat_timeCold--;
		//һ�㼼����ȴʱ��
		if(this_object()->get_cur_life()>0&&this_object()->get_cur_life()<this_object()->life_max)
			this_object()->set_life(this_object()->get_cur_life()+this_object()->rase_life);
		if(this_object()->get_cur_mofa()>0&&this_object()->get_cur_mofa()<this_object()->mofa_max)
			this_object()->set_mofa(this_object()->get_cur_mofa()+this_object()->rase_mofa);
		if(this_object()->f_skills&&sizeof(this_object()->f_skills)){
			foreach(indices(this_object()->f_skills),string index){
				if(index&&sizeof(index)){
					this_object()->f_skills[index]--;
					if(this_object()->f_skills[index]<1)
						this_object()->f_skills[index]=1;
				}
			}
		}
		/////////////////////////////////////////////////////////
		//
		//��������Զ�ȡ�Լ����ϵ�debuffӳ�����Ӱ�������״̬
		//
		/////////////////////////////////////////////////////////
		//���������dot״̬
		if(this_object()->query_debuff("dot",0)!="none"){
			//��Ѫ
			int tmp_life=this_object()->get_cur_life()-this_object()->query_debuff("dot",1);
			if(tmp_life<=0){
				this_object()->set_life(0);
				//������������ѵ��˴ӳ���б������
				enemy->clean_targets(this_object());
				return;
			}
			else {
				//����ʱ���1
				this_object()->set_life(tmp_life);
				int dot_time=this_object()->query_debuff("dot",2)-1; 
				if(dot_time<=0) //dot����ʱ���������ȥ��dot״̬
					this_object()->clean_debuff("dot");
				else
					this_object()->set_debuff("dot",2,dot_time);
			}
		}
		//�������������״̬
		if(this_object()->query_debuff("curse",0)!="none"){
			int curse_time=this_object()->query_debuff("curse",2)-1;
			if(curse_time<=0){
				this_object()->clean_debuff("curse");
			}
			else
				this_object()->set_debuff("curse",2,curse_time);
		}
		if(this_object()->query_debuff("curse2",0)!="none"){
			int curse_time=this_object()->query_debuff("curse2",2)-1;
			if(curse_time<=0){
				this_object()->clean_debuff("curse2");
			}
			else
				this_object()->set_debuff("curse2",2,curse_time);
		}
		//���������buff״̬
		if(this_object()->query_buff("buff",0)!="none"){
			int buff_time=this_object()->query_buff("buff",2)-1;
			if(buff_time<=0)
				this_object()->clean_buff("buff");
			else
				this_object()->set_buff("buff",2,buff_time);
		}
		if(this_object()->query_buff("buff2",0)!="none"){
			int buff_time=this_object()->query_buff("buff2",2)-1;
			if(buff_time<=0)
				this_object()->clean_buff("buff2");
			else
				this_object()->set_buff("buff2",2,buff_time);
		}

		//�����ﴦ������ͽ��������Ӱ��
		this_object()->attack_speed_main=this_object()->raw_attack_speed_main;	
		this_object()->attack_speed_other=this_object()->raw_attack_speed_other;
		if(this_object()->query_buff("buff",0)=="speed"){
			this_object()->attack_speed_main-=this_object()->query_buff("buff",1);
			this_object()->attack_speed_other-=this_object()->query_buff("buff",1);
			if(this_object()->attack_speed_main<=0)
				this_object()->attack_speed_main = 1;
			if(this_object()->attack_speed_other<=0)
				this_object()->attack_speed_other = 1;
		}
		if(this_object()->query_debuff("curse",0)=="speed"){
			this_object()->attack_speed_main+=this_object()->query_debuff("curse",1);
			this_object()->attack_speed_other+=this_object()->query_debuff("curse",1);
		}
		///////////////////////////////////////////////////////////////////////
		//               end
		///////////////////////////////////////////////////////////////////////
	}
	if(!in_combat)
		return;
	string cmd,arg;
	if(action&&sscanf(action,"%s %s",cmd,arg)==0)
		cmd=action;
	if(!present(enemy->name,environment(this_object()),0,this_object())){
		if(this_object()->if_in_targets(enemy))
			this_object()->clean_targets(enemy);
	}
	else if(cmd=="escape"){ 
		escape();
	}
	else if(cmd=="perform"){
		perform(arg);
	}
	//	else if(cmd=="surrender"){
	//		surrender(arg);
	//	}
	else{
		//boss���ܹ�����liaocheng��07/6/18���
		if(this_object()->_boss){
			foreach(indices(this_object()->boss_skills),string time_str){
				array(string) tmp_arr = time_str/"/";
				int first_time = (int)tmp_arr[0];
				int s_time = (int)tmp_arr[1];
				if(this_object()->timeCount==first_time || this_object()->timeCount%s_time == 0){
					boss_perform(this_object()->boss_skills[time_str]);
				}
			}
		}
		//////////////////////////////////////

		//�����Զ��ͷ���������	
		if(this_object()->skills_enable!=""&&this_object()->skills_enable_colddown!=0){
			if(autoPerforming==1){
				autoPerforming = 0;	
				perform(this_object()->skills_enable);
			}
			else if((this_object()->timeCount%this_object()->skills_enable_colddown)==0){
				perform(this_object()->skills_enable);
			}
		}
		//˫�ֶ�������
		if(this_object()->weapon_type=="both"){
			//�ж�ʱ��
			if((this_object()->timeCount%this_object()->attack_speed_main)==0&&(this_object()->timeCount%this_object()->attack_speed_other)==0){
				attack(0,0,"single_main","");
				if(enemy!=0)
					attack(0,0,"other","");
			}
			else if((this_object()->timeCount==1)||((this_object()->timeCount%this_object()->attack_speed_main)==0)){
				attack(0,0,"single_main","");
			}
			else if((this_object()->timeCount%this_object()->attack_speed_other)==0){
				attack(0,0,"other","");
			}
		}
		else if(this_object()->weapon_type=="double_main"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_main==0){
				attack(0,0,"double_main","");
			}
		}
		else if(this_object()->weapon_type=="single_main"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_main==0){
				attack(0,0,"single_main","");
			}
		}
		else if(this_object()->weapon_type=="other"){
			if(this_object()->timeCount==1||this_object()->timeCount%this_object()->attack_speed_other==0){
				attack(0,0,"other","");
			}
		}
		else if(this_object()->weapon_type=="none"){
			attack(0,0,"single_main","");
		}
		if(enemy && environment(this_object())==environment(enemy))
			if(enemy->first_fight == 0 || !enemy->in_combat){
				enemy->_fight(this_object());
				enemy->first_fight = 1;
			}
	}
	set_action("attack");
}

void set_action(string _action){
	action=_action;
}

int _fight(object _enemy){
	if(this_object()->hind == 1) 
		this_object()->hind = 0;
	if(this_object()->query_buff("spec",0) == "hind"){
		this_object()->clean_buff("spec");
		m_delete(this_object()["/danyao"],"spec");
	}
	if(!in_combat){ //����Լ��ڷ�ս��״̬�����Ǹտ�ʼս������Ҫ�õ�ս������
		this_object()->sucide = 0;
		enemy=_enemy;
		if(this_object()->is("npc")){
			//����ǳ���,�ܵ������ᷢ��ͨ��
			if(this_object()->query_npc_type()=="city_lord"){
				object env = environment(this_object());
				string city_name = env->query_belong_to();
				string city_name_cn = "";
				if(city_name=="xiqicheng")
					city_name_cn = "��᪳�";
				else if(city_name=="chaogecheng")
					city_name_cn = "�����";
				string notice = "ս����"+city_name_cn+"��"+this_object()->query_name_cn()+"�⵽�˹�����\n";
				CITYD->notice_update(notice);
			}		
			//��Ӽ�¼
			this_object()->term_who_fight_npc = enemy->query_term();
			//˭�ȿ�ʼ�Ĺ�����������Ʒ����˭
			this_object()->who_fight_npc = enemy->query_name();
		}
		//���˵ĳ���б��м����Լ�
		this_object()->flush_targets(enemy,1); //��ʼ���ֵΪ1
		in_combat=1;
		action="attack";
		//��ʼ��ս������
		//��ǰս�����װ������������,�ٶ�
		this_object()->timeCount=0;//ս��ʱ�����
		this_object()->timeCold=0; //����������ȴʱ��
		this_object()->eat_timeCold=0; //����������ȴʱ��
		this_object()->rase_life=this_object()->query_equip_add("rase_life_add"); //ս�������ظ�
		this_object()->rase_mofa=this_object()->query_equip_add("rase_mofa_add"); //ս��ħ���ظ�
		this_object()->is_both_weapons = 0;  //�Ƿ�Ϊ˫����
		this_object()->cur_main_weapon_name ="";//����������
		this_object()->cur_other_weapon_name = "";//����������
		this_object()->weapon_type = "";//��������,��,��,˫��
		this_object()->attack_speed_main = 0;//�����ٶ�
		this_object()->attack_speed_other = 0;//�����ٶ�
		this_object()->raw_attack_speed_main = 0;//�����ٶ�
		this_object()->raw_attack_speed_other = 0;//�����ٶ�
		this_object()->main_attack_attri_add=0; //�����������ӵ������˺� 
		this_object()->main_attack_attri_add_per=0; //�����������ӵ������˺��ٷֱ�
		this_object()->other_attack_attri_add=0; //����.. 
		this_object()->other_attack_attri_add_per=0; //����..
		//���ָ���ħ���˺���ʼ��
		this_object()->huo_add=this_object()->query_equip_add("attack_huoyan");
		this_object()->bing_add=this_object()->query_equip_add("attack_bingshuang");
		this_object()->feng_add=this_object()->query_equip_add("attack_fengren");
		this_object()->du_add=this_object()->query_equip_add("attack_dusu");
		this_object()->spec_add=0;//this_object()->query_equip_add("attack_spec");

		//����ս������20070131////////////////////////////
		//([skill_name:skill_limit_time])
		//this_object()->f_skills = ([]);
		//��ʼ��debuffӳ���
		/*
		   this_object()->set_debuff("dot",0,"none");
		   this_object()->set_debuff("dot",1,0);
		   this_object()->set_debuff("dot",2,0);
		   this_object()->set_debuff("curse",0,"none");
		   this_object()->set_debuff("curse",1,0);
		   this_object()->set_debuff("curse",2,0);
		//��ʼ��buffӳ���
		this_object()->set_buff("buff",0,"none");
		this_object()->set_buff("buff",1,0);
		this_object()->set_buff("buff",2,0);
		 */
		//����
		fight_desc_arg_main=query_fight_type();
		items = this_object()->query_equip();//[string:object]
		if(items["single_main_weapon"]&&items["single_other_weapon"]){
			this_object()->is_both_weapons = 1;
			this_object()->weapon_type = "both";//�����weapon_type��ָ������װ�����
			//��������Ĺ���
			this_object()->raw_attack_speed_main = items["single_main_weapon"]->query_speed_power();	
			this_object()->raw_attack_speed_other = items["single_other_weapon"]->query_speed_power();	
			//�������������
			this_object()->cur_main_weapon_name = items["single_main_weapon"]->query_name_cn();
			this_object()->cur_other_weapon_name = items["single_other_weapon"]->query_name_cn();
			//����������˺�����(��������)
			//�˺�����
			this_object()->set_attack_attri_add("main",items["single_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add("other",items["single_other_weapon"]->query_attack_add());
			//�˺��ٷֱȸ���
			this_object()->set_attack_attri_add_per("main",items["single_main_weapon"]->query_weapon_attack_add());
			this_object()->set_attack_attri_add_per("other",items["single_other_weapon"]->query_weapon_attack_add());

			//��������������ࣺjian��dao��qiang�ȵ�
			if(fight_desc_arg_main=="") {
				fight_desc_arg_main = items["single_main_weapon"]->query_item_weapon_type();
				fight_desc_arg_other = items["single_other_weapon"]->query_item_weapon_type();
			}
		}
		else if(items["double_main_weapon"]){
			this_object()->weapon_type = "double_main";
			this_object()->raw_attack_speed_main = items["double_main_weapon"]->query_speed_power();
			this_object()->cur_main_weapon_name = items["double_main_weapon"]->query_name_cn();
			//����˫���˺�����
			this_object()->set_attack_attri_add("main",items["double_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("main",items["double_main_weapon"]->query_weapon_attack_add());

			//����
			if(fight_desc_arg_main=="")
				fight_desc_arg_main = items["double_main_weapon"]->query_item_weapon_type();
		}
		else if(items["single_main_weapon"]){
			this_object()->weapon_type = "single_main";
			this_object()->raw_attack_speed_main = items["single_main_weapon"]->query_speed_power();
			this_object()->cur_main_weapon_name = items["single_main_weapon"]->query_name_cn();
			//���ֵ��������˺�����
			this_object()->set_attack_attri_add("main",items["single_main_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("main",items["single_main_weapon"]->query_weapon_attack_add());

			if(fight_desc_arg_main=="")
				fight_desc_arg_main = items["single_main_weapon"]->query_item_weapon_type();
		}
		else if(items["single_other_weapon"]){
			this_object()->weapon_type = "other";
			this_object()->raw_attack_speed_other = items["single_other_weapon"]->query_speed_power();
			this_object()->cur_other_weapon_name = items["single_other_weapon"]->query_name_cn();
			//�����˺�����
			this_object()->set_attack_attri_add("other",items["single_other_weapon"]->query_attack_add());
			this_object()->set_attack_attri_add_per("other",items["single_other_weapon"]->query_weapon_attack_add());

			//����
			if(fight_desc_arg_main=="")
				fight_desc_arg_other = items["single_other_weapon"]->query_item_weapon_type();
		}
		else{
			this_object()->weapon_type = "none";
			this_object()->raw_attack_speed_main = 1; 
			this_object()->cur_main_weapon_name = "����ȭͷ";
			if(fight_desc_arg_main=="")
				fight_desc_arg_main = "none";
		}
		//�Զ��ͷŵļ���
		object sk;
		if(this_object()->skills_enable&&sizeof(this_object()->skills_enable)){
			autoPerforming = 1;
			sk = (object)MUD_SKILLSD[this_object()->skills_enable];
			this_object()->skills_enable_colddown = sk->query_s_delayTime()+1;
		}
	}
	else{ //�Ѵ���ս��״̬�ˣ���ѶԷ����뵽�Լ��ĳ���б��� 
		this_object()->flush_targets(_enemy,1);
	}
	//��ʼս������
	if(query_heart_beat()==0){
		set_heart_beat(1);
		tmp_heart_beat=1;
	}
}

//��liaocheng�� 07/1/30���
//this_object()->��������char.pike��ս�����յĸ���ħ�������˺�
int get_attack_mofa_add(string type,int attack,object enemy){
	int tmp1,tmp2;
	if(attack){
		if((tmp1=enemy->query_equip_add(type))||(tmp2=enemy->query_equip_add("all_mofa_defend")))
			return attack-(int)(attack*(tmp1+tmp2)/400);
		else 
			return attack;
	}
	else return 0;
}

int kill(string|object _enemy,int count){
	object ob=present(_enemy,environment(this_object()),count,this_object());
	if(ob){
		if(!in_combat)//{
			killing=1;
		_fight(ob);
		if(ob->first_fight == 1)
			ob->_fight(this_object());
		//ob->kill_notify(this_object());
		return 1;
		//}
		//else
		//	return 0;
	}
}
int fight(string|object _enemy,int count,int flag){
	object ob=present(_enemy,environment(this_object()),count,this_object());
	if(ob){
		if(ob->in_combat){
			tell_object(this_object(),"��Ҫ�д��������ս���У����Ժ����ԡ�\n[����:look]\n");
			return 0;
		}
		if(flag){
			//������ս��ִ��
			tell_object(ob,this_object()->query_name_cn()+"�����������ս��\n");
			//���þ�����ʾ����Ϊ��սҪ����liaocheng��08/08/30��� 
			ob->kill_flag = 0;
			this_object()->kill_flag = 0;

			_fight(ob);
			ob->_fight(this_object());
			return 1;
		}
		else{
			//��ս������ִ��
			tell_object(this_object(),"����"+ob->query_name_cn()+"�����˾������룬����ԭ�صȴ��Է���ͬ�⡣\n[����:look]\n");
			tell_object(ob,this_object()->query_name_cn()+"�������������Ը������������ս��[������ս:fight "+this_object()->query_name()+" "+count+" 1]\n[����:look]\n");
		}

	}
	else
		tell_object(this_object(),"��Ҫ�д���˲��ڵ�ǰ���������������ͬһ���������д衣\n[����:look]\n");
	return 0;
}
//�̶���ʾ��ǰ�����ߺͱ���������������״��
	string query_cur_life(){
		if(enemy==0)
			return "";
		string s = "";
		if(in_combat&&enemy!=0){
			//�����������ʾ
			s += "����:"+this_object()->get_cur_life()+" | ����:"+this_object()->get_cur_mofa()+"\n";
			//s += "����:"+(this_object()->get_cur_life()==0?1:this_object()->get_cur_life())+" | ����:"+this_object()->get_cur_mofa()+"\n";
			s += "--------\n";
			//s += "�Է�����:"+(enemy->get_cur_life()==0?1:enemy->get_cur_life())+" | �Է�Ŀ��:"+enemy->get_target_name()+"\n";
			s += "�Է�����:"+enemy->get_cur_life()+" | �Է�Ŀ��:"+enemy->get_target_name()+"\n";
			s += "--------\n";
		}
		return s;
	}
string query_fighting_msg(){
	string s = this_object()->drain_catch_tell(0,6);
	if(enemy==0){
		s+= "ս�������ˡ�\n[����:look]\n";
	}
	return s;
}
string query_status(){
	string s = "";
	string more = "\n";
	if(this_object()->red_flag && environment(this_object())->query_room_type()=="city")
		more = "(��ɱ¾)\n";
	if(this_object()->in_combat && enemy)
		s += "��ս�У�"+this_object()->get_target_name()+"��";
	else
		s += "�ε���";
	return s+more;
}
/*	void attack_notify(object who){
	if(enemy==0)
	_fight(who);
	else if(who!=enemy)
	if(random(100)<50) enemy=who;
	}
	void kill_notify(object who){
	if(enemy==0)
	_fight(who);
	killing=1;
//tell_object(enemy,MUD_EMOTED->filter(killing_msg+"\n",this_object(),enemy,enemy));
}
 */
private string initer=(this_object()->add_heart_beat(heart_beat_action,1),"");
