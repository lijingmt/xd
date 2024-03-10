/**************************************************************************************************************
 *������Ʒ�ػ�ģ��
 *��caijieд��2008/7/3
 *�ѿɹ������Ʒ�����"/usr/local/games/usrdata/items/can_buy_item.list"�ļ��У����и��б����
 * ��Ʒ�����Ʒ�ļ�����        �ȼ����ơ�ְҵ���ơ���Ʒ����������Ҫ����ʯ����ʯ�ȼ�           ��  ��Ҫ�Ļƽ�
 *�磺book  book/liejiajianfeng     9      jianxian  ���硿�Ѽ׽���  5:1(5Ϊ��ʯ������1Ϊ��ʯ�ȼ�)  50
 *���ػ�ģ����Ҫ�ǰѿɹ�����Ʒ�������ᵽ���������뵽ӳ���buy_item_list�У�Ȼ��Ӧ�õ�������Ʒ���г��ɹ������Ʒ�嵥�ӿ���
 ***************************************************************************************************************/
#include <globals.h>
#include <gamelib/include/gamelib.h>


#define ITEM_PATH  ROOT "/gamelib/clone/item/"
#define BOOK_LIST  ROOT "/gamelib/data/can_buy_book_list.csv" //�滻·��
#define FLUSH_TIME 24*3600	//24Сʱˢ��һ��
#define PACKAGE_EXP ROOT "/gamelib/data/package_expand.csv"

class buy_item
{
	string item_type;//[0]��Ʒ����磺�飬���ϣ���ҩ
	string file;//[1]��Ʒ�ļ���
	int level;//[2]ѧϰ���ܵȼ�����
	string zhiye;//[3]ѧϰ����ְҵ����,����:jianxian ��ʿ:yushi ����:zhuxian ������wuyao ����:kuangyao Ӱ��:yinggui ����:human ��ħ:monst ����ְҵ:all
	string name_cn;//[4]�������������
	int need_yushi;//[5]��Ҫ������
	//int yushi_level;
	int need_money;//[6]��Ҫ�Ļƽ�
	int num;	//�ɹ�������� 080903 cai
}


private static mapping(string:buy_item) buy_item_list = ([]);
private static mapping(string:buy_item) high_level_book = ([]);
private static mapping(string:array) book_on = ([]);
private static mapping(string:array(array(int))) package = ([]);

void create(){
	load_list();
	start_book();
	load_pac_file();
}

void load_list()
{
	buy_item_list = ([]);
	string liandanData = Stdio.read_file(BOOK_LIST);
	array(string) lines = liandanData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			buy_item tmpBuy = buy_item();
			array(string) columns = eachline/",";
			if(sizeof(columns) == 8){
				tmpBuy->item_type = columns[0];
				tmpBuy->file = columns[1];
				tmpBuy->level = (int)columns[2];
				tmpBuy->zhiye = columns[3];
				tmpBuy->name_cn = columns[4];
				//array(string) tmpYu = columns[5]/":";//tmpYu[0]��Ҫ��ʯ��������tmpYu[1]��ʯ�ȼ�
				//tmpBuy->need_yushi = (int)tmpYu[0];
				tmpBuy->need_yushi = (int)columns[5];
				//tmpBuy->yushi_level = (int)tmpYu[1];
				tmpBuy->need_money = (int)columns[6];
				tmpBuy->num = (int)columns[7];
				if(columns[1]!=""){
					if(tmpBuy->level>=60){
						if(high_level_book[columns[1]]==0)
							high_level_book[columns[1]]=tmpBuy;
					}
					else{
						if(buy_item_list[columns[1]]==0)                     //080903
							buy_item_list[columns[1]] = tmpBuy;
					}
				}
			}
			else 
				 werror("------size of columns wrong in load_csv() of buyd.pike------\n");
		}
	}
	else 
		werror("------read can_buy_item.list wrong in gamelib/single/daemon/buyd.pike------\n");
}

//���زֿ�������Ϣ�ļ�
void load_pac_file()
{
	package = ([]);
	string liandanData = Stdio.read_file(PACKAGE_EXP);
	array(string) lines = liandanData/"\r\n";
	if(lines && sizeof(lines)){
		lines = lines-({""});
		foreach(lines,string eachline){
			array columns = eachline/"|";
			if(sizeof(columns)==3){
				if(!package[columns[0]]){
					package[columns[0]] = ({({(int)columns[1],(int)columns[2]})});
				}
				else{
					package[columns[0]] += ({({(int)columns[1],(int)columns[2]})});
				}
			}
			else
				werror("------size of columns wrong in load_pac_file() of buyd.pike------\n");
		}
	}
	else 
		werror("------read package_expand.csv wrong in gamelib/single/daemon/buyd.pike------\n");
}


//�г���Ʒ�嵥���ýӿ�
//����Ʒ���ͣ��磺�顢���ϵȵȣ���ְҵ������ʶ��
string get_buy_item_list(string item_type,string zhiye){
	object me = this_player();
	string s = "";
	foreach(sort(indices(buy_item_list)),string eachbook){
		buy_item tmpAtt = buy_item_list[eachbook];
		if(tmpAtt->item_type==item_type&&tmpAtt->zhiye==zhiye){
			if(tmpAtt->level==0)
				s += "["+tmpAtt->name_cn+":buy_items "+item_type+" "+zhiye+" "+eachbook+" "+tmpAtt->need_yushi+" "+tmpAtt->need_money+" 0]\n";
			else 
				s += "["+tmpAtt->name_cn+":buy_items "+item_type+" "+zhiye+" "+eachbook+" "+tmpAtt->need_yushi+" "+tmpAtt->need_money+" 0]("+tmpAtt->level+"��)\n";
		}
	}
	return s;
}


//������ʯ�ͻƽ�����Ʒ�Ľӿ�
string buy_items(string item_name,string item_type)
{
	object me = this_player();
	object item;
	string s = "";
	buy_item tmp = buy_item_list[item_name];
	int money = (tmp->need_money)*100;//������Ʒ��Ҫ�Ļƽ�
	int yushi = tmp->need_yushi;//������Ʒ��Ҫ����ʯ
	int have_money = me->query_account();//������ϴ��еĽ�Ǯ
	string item_namecn = "";
	if(have_money<money){
		s += "�ƽ𲻹�\n";
		return s ;
	}
	if(!YUSHID->have_enough_yushi(me,yushi)){
		s += "��ʯ����\n";
		return s;
	}
	if(me->if_over_easy_load()){
		s += "���ı���������ȥ����һ��������\n";
		return s;
	}
	mixed err = catch{
		item = clone(ITEM_PATH+tmp->file);
		item_namecn = item->query_name_cn();
	};
	if(!err&&item){
		YUSHID->pay_yushi(me,yushi);
		me->del_account(money);
		if(item->is_combine_item()){
			item->move_player(me->query_name());
		}
		else
			item->move(me);
		string consume_time = MUD_TIMESD->get_mysql_timedesc();
		int cost_reb=yushi;
		string c_log = "["+MUD_TIMESD->get_mysql_timedesc()+"]-"+"["+GAME_NAME_S+"]["+ me->query_name()+"]["+item_type+"]["+item_name+"]["+item_namecn+"][1]["+cost_reb+"][0]\n";
		Stdio.append_file(ROOT+"/log/stat/consume/"+GAME_NAME_S+"_consume_"+MUD_TIMESD->get_year_month_day()+".log",c_log);
		s += "����ɹ���\n";
	}
	return s;
}

//��ʾ��Ʒ��Ϣ���ýӿ�
string item_view(string item_name,int need_yushi,int need_money){
	string s = "";
	object item_ob = (object)(ITEM_PATH+item_name);
	s += item_ob->query_name_cn()+"\n";
	s += item_ob->query_picture_url()+"\n"+item_ob->query_desc()+"\n";
	if(item_ob->profe_read_limit||item_ob->level_limit)
		s += "Ҫ��ְҵ: "+item_ob->profe_read_limit+"\n"+"Ҫ��ȼ�: "+item_ob->level_limit+"\n";
	s += "\n";
	s += "�۸�:"+YUSHID->get_yushi_for_desc(need_yushi);
	if(need_money){
		s += ", "+need_money+"�ƽ�";
	}
	s += "\n";
	return s;
}

/*
   ����������ͨ����ʯ��Ǯ������Ʒ
   ������player    ���
         suiyu_num ��Ҫ����������
	 money     ��Ҫ��Ǯ������(�������� = �������*100)
	 flag      ��ʶ�����׵���Ʒ�Ƿ�Ҫװ�������0��ձ�ʾ�� 1��
   ����ֵ��
         0: ֧��ʧ�� ��ʯ����
	 1��֧��ʧ�� ��Ǯ����
	 2��֧��ʧ�� �ռ䲻��
	 3��֧���ɹ�
	 4: ϵͳ����
   author Evan 2008.07.25
 */
int do_trade(object player,int suiyu_num,int money,void|int flag)
{
	if(flag){
		if(player->if_over_easy_load()){
			return 2;                                                         
		}
	}
	if(!YUSHID->have_enough_yushi(player,suiyu_num)){
		return 0;
	}
	if(player->query_account()<money){
		return 1;
	}
	//���û�г���������������ʽ��ʼʵ�ֽ���
	if(YUSHID->pay_yushi(player,suiyu_num))//�۳���ʯ
	{
		if(money){
			player->del_account(money);//�۳���Ӧ��Ǯ
		}
	}
	else{
		return 4;
	}
	return 3;
}


//�г��ɹ���ĸ߼������� 080903 
string get_book()
{
	string s = "";
	string name,name_cn;
	int num,need_yushi;
	if(book_on && sizeof(book_on)){
		array tmp = indices(book_on);
		int size = sizeof(tmp);
		for(int i=0;i<size;i++){
			name = tmp[i];
			name_cn = book_on[name][0];
			num = book_on[name][1];
			need_yushi = book_on[name][2];
			s += "["+name_cn+":yushi_buy_hlbook_detail "+name+" "+need_yushi+"](ʣ��"+num+"��)\n";
		}
	}
	return s;
}

//���ؿɹ���ĸ߼������� 080903
void start_book()
{
	book_on = ([]);
	array(string) book = indices(high_level_book);
	int size = sizeof(book);
	int i = random(size);
	int j = random(size);
	//werror("=size="+size+"========what's wrong with start_book???=i="+i+"==j="+j+"==\n");
	while(j==i){
		j = random(size);
	//werror("==========what's wrong with start_book???=======\n");
		if(j!=i) 
			break;
	}
	//werror("==========what's wrong with start_book???=======\n");
	book_on[book[i]] = query_hl_book_info(book[i]);
	book_on[book[j]] = query_hl_book_info(book[j]) ;
	call_out(start_book,FLUSH_TIME);
}


//������Ʒ��Ϣ({name,name_cn,num,yushi})  080903

array query_hl_book_info(string name)
{
	string name_cn = "";
	int num = 0;
	int need_yushi = 0;
	array a = ({});
	if(high_level_book && sizeof(high_level_book)){
		name_cn = high_level_book[name]->name_cn;
		num = high_level_book[name]->num;
		need_yushi = high_level_book[name]->need_yushi;
		a += ({name_cn,num,need_yushi});
	}
	return a;
}


//���ü������ʣ������
void set_book_num(string name,int num)
{
	array bc = book_on[name];
	if(bc && sizeof(bc)){
		int have_num = (int)bc[1];
		if(have_num>=num){
			bc[1] = have_num - num;
			book_on[name][1]=bc[1];
		}
	}
}

int query_book_num(string name)
{
	array bc = book_on[name];
	if(bc && sizeof(bc)){
		int num = bc[1];
		if(num>0)
			return bc[1];
		else 
			return 0;
	}
}

//�г��ɹ���ı�����ֿ��嵥
//type==beibao cangku
string get_pac_list(string type,string cmd)
{
	string tmp_s = "";
	string s = "";
	if(type=="beibao") tmp_s += "�񱳰�";
	if(type=="cangku") tmp_s += "��ֿ�";
	if(package){
		array(array) tmp = package[type];
		int size = sizeof(tmp);
		//werror("---size of tmp="+size+"----\n");
		if(size){
			for(int i=0;i<size;i++){
			//werror("------i="+i+"---tmp[i][0]="+sizeof(tmp[i])+"---\n");
				s += "[����"+tmp[i][0]+tmp_s+":"+cmd+" "+type+" "+tmp[i][0]+" "+tmp[i][1]+" 0](��Ҫ"+YUSHID->get_yushi_for_desc(tmp[i][1])+")\n";
			}
		}
		else 
			s += "�����ⲿ����������Ʒ\n";
	}
	return s;
}


//��ѯ�Ѿ������˵ı������ֿ߲������
//����: type="beibao" or "cangku" 
//      player ���
int query_cangku_num(object player,string type)
{
	int cangku_num = 0;
	array a_tmp = query_all_pac_kind(player,type);
	if(sizeof(a_tmp)){
		for(int i=0;i<sizeof(a_tmp);i++){
			cangku_num += player->package_expand[type][a_tmp[i]];
		}
	}
	return cangku_num;
}

//�������������еı�����ֿ�Ʒ�� type = "beibao" or "cangku"
//������д��user.pike��������ڲ�����������
array(int) query_all_pac_kind(object player,string type)
{
	array a_tmp = ({});
	if(player->package_expand){
		if(player->package_expand[type] && sizeof(player->package_expand[type])){
			mapping m_tmp = player->package_expand[type];//player->package_expand=(["beibao":([����Ʒ��:��Ӧ����]),])
			a_tmp = indices(m_tmp);
		}
	}
	return a_tmp;
}
//��ÿ��滻�ı�����ֿ���б�
string get_pac_replace_list(object player,string type,int replace_size)
{
	string s = "";
	string tmp_s = "";
	int need_yushi = 0;
	if(type=="beibao")tmp_s+="����";
	if(type=="cangku")tmp_s+="�ֿ�";
	array a_tmp = query_all_pac_kind(player,type);
	array(array) p_tmp = package[type];
	if(sizeof(a_tmp)){
		mapping m_tmp = player->package_expand[type];
		for(int i=0;i<sizeof(a_tmp);i++){
			if(a_tmp[i]<replace_size&&a_tmp[i]>0){
				need_yushi = query_pac_price(type,replace_size) - query_pac_price(type,a_tmp[i]);
				//����������+�滻ǰ�ı�����С+Ҫ���滻�ı�����С+���
				s += m_tmp[a_tmp[i]]+"��"+a_tmp[i]+"��"+tmp_s+" [�滻:user_package_replace_detail "+type+" "+a_tmp[i]+" "+replace_size+" "+need_yushi+"]\n";
			}
		}
	}
	return s;
}


//�鿴�����ļ۸�
int query_pac_price(string type,int pac_size)
{
	array(array) p_tmp = package[type];
	int p_price = 0;
	if(sizeof(p_tmp)){
		for(int i=0;i<sizeof(p_tmp);i++){
			if(p_tmp[i][0]==pac_size){
				p_price = p_tmp[i][1];
				return p_price;
			}
		}
	}
	return p_price;
}
