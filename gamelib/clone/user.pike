#include <globals.h>
#include <gamelib/include/gamelib.h>
#include <gamelib.h>
inherit WAP_USER;
//�û��ֿ�̳���
inherit GAMELIB_PACKAGED;
//�������û�ע��ʱ���¼                                                                            
string user_reg_time;

//�Ƽ��˱�ʾ����liaocheng��07/08/23��ӣ�����������ϵͳ
int all_mark;//�ܵĻ���
int cur_mark;//��ǰ����
int all_fee;//��Ҿ���������(�� ���� Ϊ��λ)
string set_presenter;
mapping home_rights;//��԰Ȩ�ޱ�ʶ add by caijie 080923
mapping pic_flag;

//ɱ¾��ʾ�������ж�ͬ��Ӫ����ɱ¾���Ǿ���
//��liaocheng �� 08/08/30 ���
int kill_flag;

int get_gift;//��û������Ʒ�ı�ʶ��1=����ȡ��0=δ��ȡ��ÿ��һ��ˢ��
mapping(string:int) get_once_day=([]);//��¼ÿ����һ�ε���Ʒ��ȡ���
string last_pos;//����½�����¼
string term;//�����־
string chatid;//����Ƶ����־
int honerpt;//����ֵ
int honerlv;//�����ȼ�
int killcount;//ɱ�˼�¼
int lunhuipt;//�ֻ�ֵ
string relife;//������¼
string mobile;//�ʺŰ󶨵��ֻ�����
int yushi_flag;//�����ƹ���������ʯ�����ر�־λ
mapping(string:mapping(int:int)) package_expand;//���������ʶ��added by caijie 08/10/08

int ljs_time;//�̽�ʯ��Чʱ��
string ljs_sw;//�̽�ʯ����

//�һ���������ֶ� Evan 2008.11.20
int auto_learn_dazuo;// ����ʣ��ʱ��
int query_auto_learn_dazuo(){
	return auto_learn_dazuo;
}
int max_yao;
int query_max_yao(){
	object me=this_player();
	max_yao=5*(me->query_vip_flag()+1);
	//werror("========me->query_vip_flag() "+me->query_vip_flag()+"\n");
	return max_yao;
}
string query_max_yao_info(){
	string s="��Ա���ʳ�ô���:\n";
	s+="ˮ����Ա10��\n";
	s+="�ƽ��Ա15��\n";
	s+="�׽��Ա20��\n";
	s+="��ʯ��Ա25��\n";
	s+="������û�Ա QQ��1811117272\n";
	return s;
}
void set_auto_learn_dazuo(int s)
{
	auto_learn_dazuo = s;
}
int auto_learn_xiuchan;// ����ʣ��ʱ��
int query_auto_learn_xiuchan(){
	return auto_learn_xiuchan;
}
void set_auto_learn_xiuchan(int s)
{
	auto_learn_xiuchan = s;
}
//end of Evan 2008.11.20


string inhome_pos;//�����ĳ��home(��԰ϵͳ)�еı�־ Evan 2008.08.29 

int home_yushi;
int home_money;
void set_home_sale(int money_fg,int price){
	if(money_fg==1){
		home_yushi += price;
	}
	else if(money_fg==0){
		home_money += price;
	}
}

string query_inhome_pos(){
	return inhome_pos;
}
void set_inhome_pos(string masterName)
{
	inhome_pos = masterName;
}
//end of Evan added 2008.08.29

string home_path;//����Ƿ�ӵ��home�ı�־  Evan 2008.09.16
string query_home_path(){
	return home_path;
}
void set_home_path(string a)
{
	home_path = a;
}
//end of Evan added 2008.09.16


//һ��ʼ���20��λ��
//ÿ����10��λ��100g,�ܹ�����8�Σ�����100����Ʒ
int packageLevel;

//add by calvin 20080806
string bandpswd;//��ȫ�����

string query_bandpswd_link(){
	if(bandpswd&&sizeof(bandpswd))
		return "";
	else
		return "[�趨��ȫ��:set_bandpsw]";
}
//add by calvin 20080806

//�ͻ�Ա�ƶ���ص��ֶκʹ桢ȡ����  added by evan 2008.07.16
int vip_flag;      //��Ա��־ 0:�ǻ�Ա 1:ˮ����Ա  2:�ƽ��Ա  3:�׽��Ա  4:��ʯ��Ա
int vip_end_time;  //��Ա����ʱ�� 
mapping(int:int) vip_history=([]);//��һ�Ա��ʷ��¼ ���ṹ  ��Ա����ʱ��:��Ա�ȼ���
void add_vip_history(int endtime,int level){  //����ʷ��¼����������Ϣ
	vip_history[endtime] = level;
}
//end of evan added


/**
 * ��Ϸ�еĹ�עϵͳ
 * @author evan 
 * 2008/07/06
 * 
 *�����ݽṹ��
 * 1��mapping(string:int) spy_info  ÿ����ҵ������ж�����������ֶΣ����ڼ�¼������ע�����
 *      ���У�string:  ����ע�����id
 *               int�� ��ע��־λ��"1"��ʾĳ������ڹ�ע�б��У�������δ���ѽ��й�ע����
 *		                   "*****"��ʾ�Ѿ���ʼ��ע����ң��������ֵΪ��ʼ��ע��ʱ��
 * 2��int spy_flush_time       ÿ�ι�ע�ĳ���ʱ��
 * 3��int spy_max_num          ÿ����ҿ��Թ�ע���������
 *
 *������˵����
 * insert_spy_info()  ��ĳ�������ӵ���ע�б�
 * delete_spy_info()  ��ĳ����Ҵӹ�ע�б���ɾ��
 * start_spy()        ��ʼ��עĳ�����
 * query_spy_info()   ��ʾ���еĹ�ע��Ϣ
 * is_spied()         �ж�ĳ������Ƿ���"��ע"״̬
 *
 *��ʵ���߼���
 *  1��spy_info�м�¼��ÿ����ҵĹ�ע�б����û��Ĺ�ע���ݷ����仯ʱ�����ֶη�����Ӧ�仯��
 *  2��query_spy_info()���õ�spy_info�е�������Ϣ��չʾ��ҳ���ϣ��Ӷ�ʵ�ֹ�ע���� 
 */
mapping(string:int) spy_info =([]);       //��¼��ע�б�  �ṹ��"�����:��ʼ��עʱ��"
static int spy_flush_time = 3600;         //ÿ�ι�ע�ĳ���ʱ��
static int spy_max_num =10;               //ÿ����ҿ��Թ�ע���������

/*  �����ܡ�  �������ӵ���ע�б���
    ��������  id:���ID
    ������ֵ��   0:����ע��������ﵽ����
1:��������ڹ�ע�б��У����������
2:��ӳɹ�
 * @author evan 
 * 2008/07/06
 */
int insert_spy_info(string id)
{
	int re = 0;
	if(sizeof(spy_info)<spy_max_num)    //ÿ����������Թ�עspy_max_num��Ŀ��
	{
		if(!spy_info[id])           //������ӵ����δ���б���
		{
			spy_info[id]= 1;    //��������ӵ��б��С�"1"��ʾ��������б��У�����δ���ѿ�ʼ��ע��    
			re=2;               //��ӳɹ�
		}
		else
			re = 1;             //���������б��У����������
	}
	else
		re = 0;                     //�Ѿ��ﵽ�������ޣ����������                      
	return re;
}

/*  �����ܡ�  ��ʼ��עĳ�����
    ��������  id:���ID
    ������ֵ��   0:�����Ѿ����ڹ�ע״̬�£������ظ���ע
1:��ע�ɹ�
 * @author evan 
 * 2008/07/06
 */
int start_spy(string id)
{
	int re = 0;
	if(!is_spied(id))                   //��δ��ʼ��ע���ˡ�
	{   
		spy_info[id] = time();      //��ʼ��ע��ʱ��
		re = 1;                     //��ʼ��ע�ɹ�
	}
	return re;
}

/*  �����ܡ�  չʾ��ǰ��ҵ����й�ע��Ϣ
    ������ֵ��  string re:���ַ���ֱ��д�뵽��Ϸ�м��ɣ�չʾ��ǰ��ҵ����й�ע��Ϣ��
 * @author evan 
 * 2008/07/06
 */
string qurey_spy_info()
{
	string re ="";
	array(string) all_user = indices(spy_info);
	object tmp_user;
	int load_flag = 0;
	if(sizeof(all_user)==0)
		re += "�㻹û�й�ע�Ķ���\n";
	else{
		re += "��ǰ��ע����ң�\n";
		re += "\n";
		foreach(all_user,string single)//��ѯ�õ���ע�б��е�������Ϣ
		{
			if(single=="")
				continue;
			tmp_user = find_player(single);
			if(!tmp_user)
			{
				array list=users(1);
				object helper; //����Ҹ����ߵ���ң��Ե���load_player()����δ���ߵ���������ڴ�
				for(int j=0;j<sizeof(list);j++){
					helper = list[j];
					if(helper)
						break;
				}
				tmp_user = helper->load_player(single);           //������˲����ߣ�����ء�
				load_flag =1;
			}
			if(tmp_user)
			{
				re += tmp_user->query_name_cn();
				if(is_spied(single))                              //�������ڹ�ע״̬��
				{
					if(load_flag)                             //������˲�����Ϸ�У�����ʾ"����"
						re += " ���� ";
					else
						re += " "+environment(tmp_user)->query_name_cn();  //�õ��������ڷ���   
				}
				else{
					re +="  [��ע:spy_start "+single+"]";
				}
				re += "  [ɾ��:spy_del "+ single +"]\n";
			}
			if(load_flag)
			{
				tmp_user->remove(); //�����ص���������ߣ�ͬʱ�ı��־λ��
				load_flag=0;
			}
		}
		re += "\n\n[ˢ�¿���:spy_mylist]\n";
	}
	return re;
}

/*  �����ܡ�  ����ҳ��ע�б���ɾ��
    ��������  id:���ID
    ������ֵ��   0:ɾ��ʧ��
1:������Ѿ������б���
2:ɾ���ɹ�
 * @author evan 
 * 2008/07/06
 */
int delete_spy_info(string id)
{
	int re = 0; 
	if(!spy_info[id]) re = 1;
	else{
		spy_info = spy_info - ([id:1]);
		if(spy_info)re = 2;
	}
	return re;
}
//=== �ж�ĳ���û��Ƿ������ڹ�ע״̬ ===//
/*  �����ܡ�  �ж�ĳ���û��Ƿ������ڹ�ע״̬
    ��������  id:���ID
    ������ֵ��   0:���ٹ�ע״̬
1:���ڹ�ע״̬
 * @author evan 
 * 2008/07/06
 */
int is_spied(string id)
{
	int re = 0;
	if(spy_info[id]&&(time()-spy_info[id])<spy_flush_time)
		re =1;
	return re;
}
//========================== End of evan added 2008.07.07 ==============================//


void set_term(string t){
	term = t;
}
	string query_term(){
		if(term&&sizeof(term))
			return term;
		else
			return "noterm";
	}
void set_chatid(string t){
	chatid = t;
}
string query_chatid(){
	return chatid;
}

string query_honer_desc(){
	object me = this_object();
	return WAP_HONERD->query_honer_level_desc(me->honerlv,me->query_raceId());
}

//����ӵ�mobile���Ե�query��set������evan added 2007.12.06
string query_mobile(){
	return mobile;
}
void set_mobile(string arg){
	mobile = arg;
}
//����ӵ�yushiflag���Ե�query��set����
int query_yushi_flag(){
	return yushi_flag;
}
void set_yushi_flag(int arg){
	yushi_flag = arg;
}
//end of evan added 2007.12.06

string game_fg;//������ԭ���� ��ʶ



int fee;//���±�
array(string) query_command_prefix(){
	return ({ROOT+"/gamelib/cmds/",})+::query_command_prefix();
}
/////////////////////////////////////////////////////
void create(){
	::create();
	//term = "noterm";
	picture = "nosex";	
	living_time=10*60;
	call_out(save,10*60);
}
string query_extra_links(void|int count)
{
	object env=environment(this_object());
	object me = this_player();
	USERD->check_daily(me);//���ÿ����Ҫ���õ����������ҩ���ȵ�
	if(env&&env->is("menu")){
		return "";
	}
	string addstr = "[ע���ʺ�:reg_account]\n";
	string status = "";
	if(me->query_profeId()=="yinggui" && me->hind == 1){
		status = "(Ӱ��״̬)";
		if(me->query_buff("spec_attack_buff",0) == "jinchanmeiying2")
			status += "(+"+me->query_buff("spec_attack_buff",1)+"%)";
	}
	string topten= "[���а�:look_top]\t";
	string returnLinks="[ˢ��:look]"+topten+status+"\n[״̬:myhp](����"+this_player()->get_cur_life()+"/"+this_player()->query_life_max()+")\n[����:myskills](����"+this_player()->get_cur_mofa()+"/"+this_player()->query_mofa_max()+")\n[��Ʒ:inventory]|[��ͼ:map_display]|[����:my_term]\n[����:mytasks]|[����:my_bang]|[����:my_games]\n[����:yushi_myzone]|[����:game_detail]|[url ��ҳ:http://www.wapmud.com/gamehome/]\n";
	//string returnLinks="[ˢ��:look]"+status+"\n[״̬:myhp](����"+this_player()->get_cur_life()+"/"+this_player()->query_life_max()+")\n[����:myskills](����"+this_player()->get_cur_mofa()+"/"+this_player()->query_mofa_max()+")\n[��Ʒ:inventory]|[��ͼ:map_display]|[����:mytasks]\n[����:my_term]|[����:my_qqlist]\n[����:chatroom_list]|[���:userlist]\n[�ҵİ���:my_bang]\n[�����:yushi_myzone]\n[��Ϸ����:game_detail]\n[url �ɵ��ٷ�վ:http://xd.dogstart.com]\n";
	if(this_player()->sid == "5dwap")
		returnLinks += addstr;
	returnLinks += "[����:1811117272@qq.com]\n";
	returnLinks += "--------\n";
	//returnLinks += "�ɽ�ʱ��\n"+TIMESD->query_cur_time()+"\n";
	returnLinks += TIPSD->get_tail_desc();
	///////////////////////////////////////////////////////
	string powers = MANAGERD->checkpower(me->name);
	if(powers=="admin"||powers=="assist")
		returnLinks += "\n[���߹���ƽ̨���:game_deal]\n"; 
	///////////////////////////////////////////////////////
	return returnLinks;
}

void save(void|int autosave){
	object env=environment(this_object());
	if(this_object()->sid == "5dwap"){
		//tell_object(this_object(),"��ӭ�����ɵ������������ο���ݣ���ĵ��������ᱻ���棬��ӭ���ע��һ����ʽ�ʺ��������ɵ�����Ȥ��\n[ע���ʺ�:reg_account]\n");
		this_object()->command("quit");
		return;
	}
	if(env&&!env->is("character")&&!env->is("menu")){
		last_pos=file_name(env)-ROOT;
	}
	string now=ctime(time());
	//�������а�����
	string zhenying="���ɡ�";
	if(this_object()->query_raceId()=="monst")
		zhenying="������";
	string topname = this_object()->query_name_cn()+"("+this_object()->query_level()+"��)"+zhenying;
	TOPTEN->try_top(this_object()->query_name(),topname,"�ȼ�",this_object()->query_level());
	TOPTEN->try_top(this_object()->query_name(),topname,"����",this_object()->query_account());
	if(this_object()->query_raceId()=="monst")
		TOPTEN->try_top(this_object()->query_name(),topname,"����",this_object()->honerpt);
	if(this_object()->query_raceId()=="human")
		TOPTEN->try_top(this_object()->query_name(),topname,"����",this_object()->honerpt);
	/*
	TOPTEN->try_top(this_object()->query_name(),topname,"����",this_object()->query_fight_attack());
	TOPTEN->try_top(this_object()->query_name(),topname,"����",this_object()->query_defend_power());
	TOPTEN->try_top(this_object()->query_name(),topname,"����",(int)this_object()->query_phy_dodge());
	TOPTEN->try_top(this_object()->query_name(),topname,"�м�",(int)this_object()->query_phy_parry());
	TOPTEN->try_top(this_object()->query_name(),topname,"����",(int)this_object()->query_phy_hitte());
	TOPTEN->try_top(this_object()->query_name(),topname,"����",(int)this_object()->query_phy_baoji());
	*/
	TOPTEN->try_top(this_object()->query_name(),topname+"("+this_object()->all_fee+")("+this_object()->name+")","����",(int)this_object()->all_fee);
	//end �������а�����
	::save();
	if(!environment(this_object())){
		//destruct(this_object());
		return;
	}
	else
		call_out(save,10*60);
}
void remove(){
	if(term && term != "noterm"){
		TERMD->leave_term(term,this_object()->query_name(),this_object()->query_name_cn()); 
	}
	::remove();
}
void fight_die()
{
	object me = this_object();
	string t = "";
	string w_kill = "";
	int my_level = me->query_level();
	object env =environment(me);//��ս�м��룬Ҫ�ǳ�ս��װ���;ý�����ĺ�С
	me->red_flag=0;

	if(enemy)
		w_kill += enemy->query_name_cn();

	//���ɱ����Ӧ��������㣬Ȼ����ݵ�ɱ�����Ŷ�ɱ����
	//�ýӿڲ����Ƿ�õ�������,����¼�����߼�ɱ���ߵ�ɱ�˼�����++
	int gain_honer = 0;
	int gain_lunhui = 0;//�ֻ�ֵ
	//������Ҳ�����ս��ð�����ֵ����liaocheng��08/08/30 ���
	int gain_baqi = 0;
	if(enemy&&!enemy->is("npc")){
		if(me->query_level() - enemy->query_level()>5)
			;
		else {
			gain_honer = WAP_HONERD->honer_killed(enemy,me);
			gain_lunhui = WAP_HONERD->lunhui_killed(enemy,me);
		}
		//������Ҳ�����ս��ð�����ֵ����liaocheng��08/08/30 ��� 
		if(enemy->bangid && me->bangid){
			if(BANGZHAND->is_in_bangzhan(enemy->bangid,me->bangid)){
				gain_baqi = BANGZHAND->get_baqi(enemy,me);
			}
		}
	}

	//�����ɱ�����Ŷӣ����߱�ɱ���Ŷ���Ϣ
	if(me->query_term()!=""&&me->query_term()!="noterm"){
		if(TERMD->query_termId((string)me->query_term()))
			if(w_kill&&sizeof(w_kill))
				TERMD->term_tell(me->query_term(),me->query_name_cn()+" �� "+w_kill+" ɱ���ˡ�\n");
			else
				TERMD->term_tell(me->query_term(),me->query_name_cn()+" �Ѿ�������\n");
	}
	///////////////////////////////////////////
	//���ɱ�������Ŷӣ�����ɱ�����Ŷӣ�˭ɱ�˱���ɱ�ߣ�ÿ���˷��˶�������ֵ
	if(enemy&&!enemy->is("npc")&&enemy->query_term()!=""&&enemy->query_term()!="noterm"){
		//ˢ�¶��飬���Ƿ��Զ���ɢ��ӳ���ɢ
		TERMD->flush_term(enemy->query_term());
		//�������Ƿ����ڴ�
		if(TERMD->query_termId(enemy->query_term())){
			//����Ŷ��ڴ�mappingָ��
			mapping(string:array) map_term = ([]);
			map_term = (mapping)TERMD->query_term_m(enemy->query_term());
			if(map_term&&sizeof(map_term)){
				array(int) level_tmp = TERMD->query_term_level(map_term);
				//�����Ŷ����ж�Ա�ȼ���������ɱĿ��ȼ�5�����������ֵ���ֻ�ֵ
				if(level_tmp[sizeof(level_tmp)-1]-my_level<=5){
					//���Ŷ�ɱ��,�õ�����ֵ��ƽ������///////////////
					if(gain_honer>0){
						string tmp = "";
						if(enemy->query_raceId()=="human")
							tmp += "����";
						else
							tmp += "����";
						//�������������䣬Ȼ��ƽ�������ÿ����ֵĶ�Ա
						//���ֻ��һ���˴򣬾Ͱ�Ǯ���Ǹ���ֵĶ�Ա��
						//1.�ȵõ���ǰ������ֵĶ�Ա����
						int t_count = 0;//sizeof(map_term);
						foreach(indices(map_term),string uid){
							object termer = find_player(uid);
							if(termer){
								//�ж��Ƿ�һ�����䣬һ��������Է���
								if( environment(enemy)->query_name() == (environment(termer))->query_name() )
									t_count++;
							}
						}
						int t_money = gain_honer/t_count;
						if(t_money<=0)
							t_money = 1;
						//���������������Ķ�Ա	
						foreach(indices(map_term),string uid){
							int flag = 0;
							object termer = find_player(uid);
							if(termer){
								//�ж��Ƿ�һ�����䣬һ��������Է���
								if( environment(enemy)->query_name() == (environment(termer))->query_name() )
									flag = 1;
							}
							if(flag){//�����ͬһ������
								//������ҩ�������ӳɣ���liaocheng��07/11/21���
								int te_honer = termer->query_buff("te_honer",1);
								if(te_honer){
									t_money = t_money+t_money*te_honer/100;
								}
								termer->honerpt+=t_money;
								//ˢ�µõ������ߵ���������
								termer->honerlv = WAP_HONERD->flush_honer_level(termer->honerpt,termer->honerlv);
								string mstr = "";
								mstr += enemy->query_name_cn()+" ɱ���� "+me->query_name_cn()+" ��\n";
								mstr += "��� "+tmp+" ������ "+t_money+" �㡣\n";
								//������Ҳ�����ս��ð�����ֵ����liaocheng��08/08/30 ���              
								if(gain_baqi)
									mstr += "��İ��������� "+gain_baqi+" �������\n";
								tell_object(termer,mstr);
							}
						}
					}
					//����ֻ�ֵ
					if(gain_lunhui>0){
						string tmp = "";
						//1.�ȵõ���ǰ������ֵĶ�Ա����
						int t_count = 0;//sizeof(map_term);
						foreach(indices(map_term),string uid){
							object termer = find_player(uid);
							if(termer){
								//�ж��Ƿ�һ�����䣬һ��������Է���
								if( environment(enemy)->query_name() == (environment(termer))->query_name() )
									t_count++;
							}
						}
						int t_lunhui = gain_lunhui/t_count;
						if(t_lunhui<=0){
							t_lunhui = 1;
						}
						if(me->query_raceId()=="human"){
							t_lunhui = 0 - t_lunhui;
						}
						//�����ֻص������Ķ�Ա	
						foreach(indices(map_term),string uid){
							int flag = 0;
							object termer = find_player(uid);
							if(termer){
								//�ж��Ƿ�һ�����䣬һ��������Է���
								if( environment(enemy)->query_name() == (environment(termer))->query_name() )
									flag = 1;
							}
							if(flag){//�����ͬһ������
								termer->lunhuipt+=t_lunhui;//�����ֻ�ֵ
								string mstr = "";
								mstr += "����ֻ�ֵ������ "+t_lunhui+" �㡣\n";
								tell_object(termer,mstr);
							}
						}
					}
				}
			}
		}
	}
	else{
		//û���Ŷӣ���ɱ��
		if(enemy&&!enemy->is("npc")){
			tell_object(enemy,"��ɱ����"+me->query_name_cn()+"��\n");
			if(enemy->query_level()-my_level<=5){
				if(gain_honer>0){
					string tmp = "";
					if(enemy->query_raceId()=="human")
						tmp += "����";
					else
						tmp += "����";
					//������ҩ�������ӳɣ���liaocheng��07/11/21���
					int te_honer = enemy->query_buff("te_honer",1);
					if(te_honer){
						gain_honer = gain_honer+gain_honer*te_honer/100;
					}
					enemy->honerpt += gain_honer;
					tell_object(enemy,"���"+tmp+"������ "+gain_honer+" �㡣\n");
					//ˢ�¸û�ɱ�ߵ���������
					enemy->honerlv = WAP_HONERD->flush_honer_level(enemy->honerpt,enemy->honerlv);
				}
				//�����ֻ�ֵ
				if(gain_lunhui>0){
					if(me->query_raceId()=="human"){
						enemy->lunhuipt -= gain_lunhui;
					}
					else
						enemy->lunhuipt += gain_lunhui;
				}
				//������Ҳ�����ս��ð�����ֵ����liaocheng��08/08/30 ���
				string baqi_s = "";
				if(gain_baqi){
					baqi_s = "��İ��������� "+gain_baqi+" �������\n";
					tell_object(enemy,baqi_s);
				}
			}
		}
	}
	//���Է�ɱ���ĳͷ�
	if(me->sucide == 0){
		if(env->query_room_type() != "city"){
			if(w_kill&&sizeof(w_kill))
				t ="\n�㱻"+w_kill+"ɱ���ˡ�����װ����ǰ�;���ʧ�ٷ�֮һ��\n";
			else
				t = "\n���Ѿ�����������װ����ǰ�;���ʧ�ٷ�֮һ��\n";
			//�����ͷ�������װ����ǰ�;���ʧ25%
			array(object) items=all_inventory(me);
			if(items&&sizeof(items)){
				for(int i=0;i<sizeof(items);i++){
					//ÿ��װ�����;���ʧ
					if(items[i]->equiped && items[i]->item_dura<10000){
						if(items[i]->item_cur_dura>0){
							//items[i]->item_cur_dura -= items[i]->item_dura*25/100;
							items[i]->item_cur_dura -= items[i]->item_dura*1/100;//�����Ϸ�����ԣ���1%�;ö�
							if(items[i]->item_cur_dura<=0)
								items[i]->item_cur_dura = 0;
						}
						else
							items[i]->item_cur_dura = 0;
					}
				}
			}
		}
		else{
			//��սʱ����������װ������ĳͷ�
			if(w_kill&&sizeof(w_kill))
				t ="\n�㱻"+w_kill+"ɱ���ˡ�\n";
			else
				t = "\n���Ѿ�������\n";
		}
		//�����Ǳ���ɱ�����Ǳ����ɱ����������ʧ����
		//���������npc�򲻵����飬��������pk����侭��
		if(enemy&&(enemy->query_level()-my_level<=5)&&!enemy->is_npc){
			//��������̽�ʯʹ��Ч�����̽�ʯЧ���������ֶο��ƣ�һ����ʱ��ljs_time��һ����ʹ�ÿ���ljs_sw����ʱ�����������̽�ʯ���ڹر�״̬�Ǳ��Է�ɱ������ʧ��Ӧ�ľ���
			if(!me->ljs_time||me->ljs_time<=0||(me->ljs_sw&&me->ljs_sw=="close")){
				int drop_exp = me->killed_exp(enemy);
				if(drop_exp){
					int del_result = me->del_exp(drop_exp);
					if(del_result==1){
						t += "�ȼ�����1��\n";
					}
					else if(del_result==2){
						t += "ͬʱ��ʧ"+drop_exp+"�㾭��\n";
					}
				}
			}
		}
	}
	else 
		t += "�������ɱ��~~\n";
	tell_object(me,t);
	_clean_fight();
	if(enemy)
		enemy->clean_targets(me);
	//���ϵ�ҩЧ��ʧ
	me->reset_buff();

	//��������˸���㣬�Ӹ���㸴������Ĭ����Ӫ����ظ���
	//���ȳ�ս�����������Զ������ǳظ����
	if(env->query_room_type() == "city" && me->query_raceId()==env->room_race){
		string city_name = env->query_belong_to();                                                  
		string rest_room = CITYD->query_rest_room(city_name);
		if(rest_room && sizeof(rest_room)){
			mixed err=catch{
				(object)(rest_room);
			};
			if(!err){
				me->move(rest_room);
				return;
			}
		}
	}
	//��������˸���㣬�Ӹ���㸴������Ĭ����Ӫ����ظ���
	if(me->relife){
		mixed err=catch{
			(object)(ROOT+me->relife);
		};
		if(!err)
			me->move(ROOT+me->relife);
	}
	else{
		//û�и���㣬��Ĭ����Ӫ����ظ���
		if(me->query_raceId()=="human")
			me->last_pos="/gamelib/d/congxianzhen/congxianzhenguangchang";
		if(me->query_raceId()=="monst")
			me->last_pos="/gamelib/d/jinaodao/yuhuacunguangchang";
		if(me->last_pos){
			mixed err=catch{
				(object)(ROOT+me->last_pos);
			};
			if(!err)
				me->move(ROOT+me->last_pos);
		}
	}
}
string query_links(void|int count)
{
	string out="";
	if(this_object()->home_path&&this_object()->home_path!="")
	{
		out += "��԰��["+HOMED->query_homeName_by_masterId(this_object()->query_name())+":home_display "+this_object()->query_home_path()+"]\n";
	}
	if(this_object()->query_raceId()==this_player()->query_raceId()){
		//�����˰�սɱ¾����ʾ����liaocheng��08/08/30���
		object env=environment(this_object());
		if(env->room_race == "third" && this_object()->bangid && this_player()->bangid && BANGZHAND->is_in_bangzhan(this_object()->bangid,this_player()->bangid))
			out += "[ɱ¾:kill "+this_object()->query_name()+" "+count+"]\n";
		//��Ӹ������ӣ���liaocheng��07/09/21���
		else if(this_player()->follow == "_none" && this_player()->query_term()==this_object()->query_term() && this_player()->query_term() != "noterm")
			out += "[����:follow_you "+this_object()->query_name()+" "+count+"]\n";
		out += "[�۲�:view_equip "+this_object()->query_name()+"] ";
		out += "[��ע:spy_add "+this_object()->query_name()+"]\n";
		out += "[�Ի�:ask "+this_object()->query_name()+" "+count+"] ";
		out += "[����:fight "+this_object()->query_name()+" "+count+" 0]\n";
		out += "[����:trade "+this_object()->query_name()+"] ";
		out += "[����:sendother "+this_object()->query_name()+"]\n";
		out += "[��Ϊ����:qqlist "+this_object()->query_name()+"]\n";
		if(this_object()->query_term()==""||this_object()->query_term()=="noterm")
			out += "[�������:term_assist "+this_object()->query_name()+"]\n";
	}
	else{
		out += "[�۲�:view_equip "+this_object()->query_name()+"] ";
		out += "[ɱ¾:kill "+this_object()->query_name()+" "+count+"]\n";
		out += "[��ע:spy_add "+this_object()->query_name()+"]\n";
	}
	out = out + ::query_links(count);                                                                                        
	return out;
}
string query_bangstatus(){
	string rst = "";
	if(this_object()->bangid){
		rst += BANGD->query_bang_name(this_object()->bangid);
	}
	if(rst&&sizeof(rst))
		rst = "���ɣ�<"+rst+">*"+BANGD->query_level_cn(this_object()->query_name(),this_object()->bangid);
	return rst;                                                                   
}
string query_bc_msg()
{
	object me = this_object();
	object env=environment(me);
	if(env&&env->is("menu")){
		return "";
	}
	string tmp = "";
	string bc_msg = BROADCASTD->bcShow();
	if(bc_msg&&sizeof(bc_msg))
		tmp += bc_msg; 
	return tmp;
}
string query_chat_msg()
{
	object me = this_object();
	object env=environment(me);
	if(env&&env->is("menu")){
		return "";
	}
	string tmp = "";
	if(me->roomchatid=="pub" || me->roomchatid=="open"){
		//if(me->query_level() >=6)//Ϊ������ǹ�ֶ������޸�
			tmp +="[ui_chat ...]\n";
		if(me->query_raceId()=="human")
			tmp += CHATROOMD->query_chatroom_msg("pub_channel",me->query_name());
		else if(me->query_raceId()=="monst")
			tmp += CHATROOM2D->query_chatroom_msg("pub_channel",me->query_name());
		tmp += "��|";
		//tmp += "[��:ui_select_room sale]|";
		tmp += "[��:ui_select_room term]|";
		tmp += "[��:ui_select_room bang]|";
		tmp += "[��:ui_select_room close]\n";
	}
	/*else if(me->roomchatid=="sale"){
		if(me->query_level() >=6)
			tmp +="[ui_chat ...]\n";
		if(me->query_raceId()=="human")
			tmp += CHATROOMD->query_chatroom_msg("sales_channel",me->query_name());
		else if(me->query_raceId()=="monst")
			tmp += CHATROOM2D->query_chatroom_msg("sales_channel",me->query_name());
		tmp += "[��:ui_select_room pub]|";
		tmp += "��|";
		tmp += "[��:ui_select_room term]|";
		tmp += "[��:ui_select_room bang]|";
		tmp += "[��:ui_select_room close]\n";
	}*/
	else if(me->roomchatid=="term"){
		if(me->query_term()=="" || me->query_term()=="noterm"){
			tmp += "��û�����κζ�����\n";
			tmp += "[��:ui_select_room pub]|";
			//tmp += "[��:ui_select_room sale]|";
			tmp += "��|";
			tmp += "[��:ui_select_room bang]|";
			tmp += "[��:ui_select_room close]\n";
		}
		else{
			tmp += "[ui_chat ...]\n";
			tmp += TERMD->query_termChat_ui(me->query_term());
			tmp += "[��:ui_select_room pub]|";
			//tmp += "[��:ui_select_room sale]|";
			tmp += "��|";
			tmp += "[��:ui_select_room bang]|";
			tmp += "[��:ui_select_room close]\n";
		}
	}
	else if(me->roomchatid=="bang"){
		if(me->bangid == 0){
			tmp += "�㻹δ�����κΰ���\n";
			tmp += "[��:ui_select_room pub]|";
			//tmp += "[��:ui_select_room sale]|";
			tmp += "[��:ui_select_room term]|";
			tmp += "��|";
			tmp += "[��:ui_select_room close]\n";
		}
		else if(BANGD->query_level(me->query_name(),me->bangid) > 1){
			tmp += "[ui_chat ...]\n";
			tmp += BANGD->query_ui_bangChat(me->bangid); 
			tmp += "[��:ui_select_room pub]|";
			//tmp += "[��:ui_select_room sale]|";
			tmp += "[��:ui_select_room term]|";
			tmp += "��|";
			tmp += "[��:ui_select_room close]\n";
		}
		else if(BANGD->query_level(me->query_name(),me->bangid) == 1){
			tmp += "���ѱ��������߹�Ա������\n";
			tmp += BANGD->query_ui_bangChat(me->bangid); 
			tmp += "[��:ui_select_room pub]|";
			//tmp += "[��:ui_select_room sale]|";
			tmp += "[��:ui_select_room term]|";
			tmp += "��|";
			tmp += "[��:ui_select_room close]\n";
		}
	}
	else if(me->roomchatid=="close"){
		//tmp += me->query_mini_picture_url("open_chat")+"[������:ui_select_room open]\n";
		tmp +="[������:ui_select_room open]\n";
	}
	return tmp;
}
string query_tips_msg()
{
	object me = this_object();
	object env=environment(me);
	if(env&&env->is("menu")){
		return "";
	}
	string tmp = "";
	string sys_msg = TIPSD->query_server_tips();
	string yun_msg = "[��Ϸ������Ϣ:check_yun_msg]\n"; 
	if(sys_msg&&sizeof(sys_msg))
		tmp += sys_msg; 
	if(TIPSD->query_yunying_status())
		tmp += yun_msg; 
	return tmp;
}
int remove_combine_item(string name,int count)
{
	if(!count){
		return 0;
	}
	object me = this_object();
	int i = 0;
	int temp_num = count;
	array(object) all_obj = all_inventory(me);
	foreach(all_obj,object ob1){
		if(ob1->is_combine_item()&&ob1->query_name() == name){
			//�ø�����Ʒһ��20�������������񣬽�����ѯ��һ��
			if(ob1->amount<=temp_num){
				i+=ob1->amount;
				temp_num -= ob1->amount;
				ob1->remove();
			}
			else{
				i+=temp_num;
				ob1->amount -= temp_num;
			}
			if(i >= count)
				break;
		}
	}
	return i;
}
string query_danyao_effect()
{
	object me = this_object();
	string s_rtn = "";
	int flag = 0;
	mapping(string:string) have_yao = me["/danyao"];
	if(have_yao && sizeof(have_yao)){
		foreach(sort(indices(have_yao)),string kind){
			flag += 1;
			string yao_name = have_yao[kind];
			if(sizeof(yao_name) > 0){
				int time_remain = me->query_buff(kind,2);
				if(flag != 1)
					s_rtn += "|";
				s_rtn += yao_name+"("+time_remain+"m)";
			}
		}
	}
	if(s_rtn == "")
		s_rtn += "��";
	return s_rtn;
}
string query_teyao_effect()
{                       
	object me = this_object();                      
	string s_rtn = "";
	int flag = 0;
	mapping(string:array) have_yao = me["/teyao"];
	if(have_yao && sizeof(have_yao)){
		foreach(sort(indices(have_yao)),string kind){
			flag += 1;
			string yao_name = have_yao[kind][3];
			if(sizeof(yao_name) > 0){
				int time_remain = me->query_buff(kind,2);
				if(flag != 1)                                                   
					s_rtn += "|";                                           
				s_rtn += yao_name+"("+time_remain+"m)";                         
			}
		}
	}
	if(s_rtn == "")
		s_rtn += "��"; 
	return s_rtn;
}

string query_homeBuff_effect()
{                       
	object me = this_object();                      
	string s_rtn = "";
	int flag = 0;
	mapping(string:array) have_buff = me["/homeBuff"];
	if(have_buff && sizeof(have_buff)){
		foreach(sort(indices(have_buff)),string kind){
			flag += 1;
			string buff_name = have_buff[kind][3];
			if(sizeof(buff_name) > 0){
				int time_remain = me->query_buff(kind,2);
				if(flag != 1)                                                   
					s_rtn += "|";                                           
				s_rtn += buff_name+"("+time_remain+"m)";                         
			}
		}
	}
	if(s_rtn == "")
		s_rtn += "��"; 
	return s_rtn;
}

//���ӻ������� caijie 080910
void set_base_add(string base,int value)
{
	if(base=="think"){
		base_think += value;
	}
	else if(base=="str"){
		base_str += value;
	}
	else if(base=="dex"){
		base_dex += value;
	}
	else if(base=="luck"){
		_lunck += value;
	}
}

//�ж���������Ƿ���һ��home��
int if_in_home()
{
	object env = environment(this_player());//��ǰ���ڷ���
	if(env->query_room_type()&&env->query_room_type() == "home")
		return 1;
	return 0;
}

//��ѯ��ҵ�װ������Ƕ��ʯ������
//equip==0--ͳ��ȫ�������������ĺͲ������ģ�װ������Ƕ�ı�ʯ;equip==1---ͳ�ƴ�����װ������Ƕ�ı�ʯ
int query_baoshi_xiangqian_num(void|string baoshi_name,int equip){
	object me = this_player();
	array(object) all_items = all_inventory(me); 
	int baoshi_num = 0;
	array tmp = ({});
	if(!equip){
		foreach(all_items,object eachitem){
			if(eachitem->query_if_aocao("all")&&eachitem->query_baoshi("all")){
				tmp += eachitem->query_baoshi("all");
			}
		}
	}
	else if(equip==1){
		foreach(all_items,object eachitem){
			if(eachitem["equiped"]&&eachitem->query_if_aocao("all")&&eachitem->query_baoshi("all")){
				tmp += eachitem->query_baoshi("all");
			}
		}
	}
	if(!baoshi_name){
		//ȫ����ʯ������
		baoshi_num = sizeof(tmp);
	}
	else{
		foreach(tmp,object eachbaoshi){
			if(eachbaoshi->query_name()==baoshi_name){
				baoshi_num ++;
			}
		}
	}
	return baoshi_num;
}
//�����������������ʯ����������
string query_yushi_cn()
{
	string re = "";
	re += YUSHID->query_yushi_cn(this_player());
	return re;
}
//��¼����Ҿ�����������
int query_all_fee(){
	return all_fee;
}
void set_all_fee(int s)
{
	all_fee = s;
}
