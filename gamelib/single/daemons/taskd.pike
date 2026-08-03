//属性说明:

//["/taskd/Cont"]:玩家当前任务记录,([int:array]) --  ([taskid:({start_time,status})])
//status 0:任务未完成
//       1:任务已完成完成
//["/taskd/done"]:玩家已经完成过的任务,([int:int]) -- ([任务id taskid:完成的次数 tasknum])
#include <globals.h>
#include <gamelib/include/gamelib.h>
inherit LOW_DAEMON;
#define ASYNC_IOD ((object)(ROOT "/gamelib/single/daemons/async_iod.pike"))
#define TIME_INTERVAL 1800 //半个小时查询任务列表是否更新   
#define TASK_LIST ROOT "/gamelib/data/task/task_list.csv" //任务列表
#define TASK_ITEM_LIST ROOT "/gamelib/data/task/task_item_list.csv" //任务物品列表
#define log_file ROOT ROOT "/log/task_system.log" 
//object LOG;
class task
{
	int id;//[0]任务ID--任务唯一标示
	string isManual;//[1]手工生成--该条任务纪录是否是需要手工来完成的
	string name;//[2]任务名称--任务的中文简单描述
	string desc;//[3]任务内容--任务内容的大概描述

	int level_limit;//[4]级别限制--接受该任务的修为需求限制
	int age_limit;//[5]年龄限制--接受该任务的年龄需求限制
	string raceId_limit;//[6]阵营限制--接受该任务的年龄需求限制
	string sex_limit;//[7]性别限制--接受该任务的性别需求限制
	string profe_limit;//[8]职业限制--接受该任务的职业限制
	string isMarriage;//[9]夫妻限制--接受该任务的夫妻需求限制

	string grantNPC;//[10]发放任务NPC--该任务是由哪个npc发放的
	string kind;//[11]任务类型--任务是哪种基本类型的：搜寻-find,传信-msg,杀戮-kill,传物-send
	int taskType; //[12]是否是新手任务
	string acceptWord;//[13]发放任务对话--该任务被接受后，所说的任务提示

	string kill_info; //[14]杀戮信息 -- 如果任务类型是kill,该字段是kill的npc名字及数量
	string find_info;//[15]搜寻物品名称--如果任务类型是find,该字段为find的物品名称及数量
	string send_info;//[16]传物涉及物品--同传信
	int day_limit;//[17]完成时间限制--是否有时间限制

	string checkNPC; //[18]验收任务的NPC
	string promptWord;//[19]任务完成之前对话内容--任务类型对应任务未完成时候的提示（比如：未完成，是否放弃，等等）
	string completeWord;//[20]任务完成之后NPC答复--任务类型对应完成任务后npc的答复（奖励描述，给物品等等）

	int exp_award;//[21]经验奖励--完成任务后由奖励的经验
	int money_award;//[22]任务奖励金钱--同上
	mapping(string:int) itemid_award;//[23]任务奖励物品id--同上
	int isRepeat;//[24]是否可重复完成-- 0-不能 1-能 2-日常
	int preIds;//[25]任务前续--是否需要下一个任务的限制
	int str_limit;//[26]力量限制 2007/04/19添加
	int think_limit; //[27]智力限制 2007/04/19添加
	int dex_limit; //[28]敏捷限制 2007/04/19
	int isStrait; //[29]是否严格限制
	string roomToDoTask;//[30]做任务的房间(新手任务专用)
	string roomToReTask;//[31]交任务的房间(新手任务专用)

	mapping(string:int) kill_map = ([]);
	array(string) kill_order = ({});
	mapping(string:int) find_map = ([]);
	array(string) find_order = ({});
	mapping(string:int) send_map = ([]);
}

private mapping(int:task) taskMap = ([]); //任务总表,记录了任务的所有信息
private mapping(string:array(int)) grantMap = ([]); //npc与能发放任务的映射表
private mapping(string:array(int)) checkMap = ([]); //npc与验证任务的映射表 
private mapping(string:array(int)) killMap = ([]); //杀怪的任务映射表
private mapping(string:array(int)) dropItemMap = ([]); //掉落任务物品与任务id的映射表
private mapping(string:mapping(string:int)) taskItemMap = ([]); //怪:任务物品 掉落表
private mapping(string:string) pathMap = ([]); //怪的中文名:怪的文件路径,
                                               //如："沙虫的眼睛":"task/shachongdeyanjing"  
// 任务引导只保存服务端审核过的大地图或副本外入口，避免按钮注入任意路径。
private mapping(string:string) taskGuideTargetRoom = ([
	"清云兽":"shierxianjing/shierxianjing",
	"灵龟":"shierxianjing/shierxianjing",
	"雷鸟":"shierxianjing/shierxianjing",
	"飘渺仙灵":"plxianjing/xianzhenplxianjing",
	"游云飞龙":"plxianjing/xianzhenplxianjing",
	"卷云幽魂":"plxianjing/xianzhenplxianjing",
	"阎罗王":"jiangjunmu/dajiangjunlingershiceng",
	"秦广王":"jiangjunmu/dajiangjunlingershiceng",
	"五道转轮王":"jiangjunmu/dajiangjunlingershiceng",
	"金蛟龙":"muye/huanghean",
	"木蛟龙":"muye/huanghean",
	"水蛟龙":"muye/huanghean",
	"火蛟龙":"muye/huanghean",
	"土蛟龙":"muye/huanghean",
	"七彩龙":"muye/huanghean",
	"金翅蛟龙王":"muye/huanghean",
	"金毛狮鹫":"plxianjing/xianzhenplxianjing",
	"凝泪水妖":"plxianjing/xianzhenplxianjing",
	"虚空妖婆":"plxianjing/xianzhenplxianjing",
	"虚幻鬼帅":"fushoushan/dijiaoershiceng",
	"妖鸟鬼车":"fushoushan/dijiaoershiceng",
	"伯夫鬼王":"fushoushan/dijiaoershiceng",
]);
private mapping(string:string) taskGuideFindRoom = ([
	"狮鹫之尾":"plxianjing/xianzhenplxianjing",
	"苍鹰尾羽":"plxianjing/xianzhenplxianjing",
	"妖法水球":"plxianjing/xianzhenplxianjing",
	"仙灵之魂":"plxianjing/xianzhenplxianjing",
	"凝泪之眼":"plxianjing/xianzhenplxianjing",
	"蛇之精粹":"plxianjing/xianzhenplxianjing",
	"苍鹰之眼":"plxianjing/xianzhenplxianjing",
	"狮鹫之眼":"plxianjing/xianzhenplxianjing",
	"仙灵之眼":"plxianjing/xianzhenplxianjing",
	"虚空精华":"plxianjing/xianzhenplxianjing",
	"毒蛇之眼":"plxianjing/xianzhenplxianjing",
	"水妖之泪":"plxianjing/xianzhenplxianjing",
]);

protected void create() 
{
	werror("==========  [TASKD start!]  =========\n");
	load();
	werror("===== Task_list end!  =====\n");
	Load_task_item_list();
	werror("===== Task_Item_list end!  =====\n");
	werror("==========  [TASKD end!]  =========\n");
}

mapping query_cache_status()
{
	return ([
		"mode":"parsed_startup_snapshot",
		"tasks":sizeof(taskMap),
		"grant_indexes":sizeof(grantMap),
		"check_indexes":sizeof(checkMap),
		"kill_indexes":sizeof(killMap),
		"drop_indexes":sizeof(dropItemMap),
		"task_items":sizeof(taskItemMap),
	]);
}

void load(int|void isFirst)
{
	werror("===== Item_list start!  =====\n");
	//LOG->append_time("[load-start]");
	/*Stdio.Stat file_stat = file_stat(rootFile);
	if(file_stat == 0)
		LOG->append_time("[File:" + rootFile +" Not-Exist!]");
	else
	{
		int time_interval = time() - file_stat->mtime;
		if(!isFirst)
		{
			if(time_interval > TIME_INTERVAL)
			{
				call_out(load,TIME_INTERVAL);
				return;
			}
		}
	}*/

	taskMap = ([]);
	grantMap = ([]);
	checkMap = ([]);
	killMap = ([]); 
	dropItemMap = ([]);

	string taskList = ASYNC_IOD->read_text(TASK_LIST,4*1024*1024);
	array lines;
	if(taskList&&sizeof(taskList))
		// 同时兼容历史CRLF和新任务的LF行尾。
		lines = taskList/"\n";
	if(lines&&sizeof(lines))
	{
		//werror("----we have "+sizeof(lines)+" tasks----\n");
		for(int i = 1; i < sizeof(lines); i++)
		{
			string tempLine = lines[i];
			//	tempLine = upper(tempLine);

			if(tempLine&&sizeof(tempLine))
			{
				array columns = tempLine/",";
				//werror("----size of columns ="+sizeof(columns)+"----\n");
				if(columns&&sizeof(columns) == 32)
				{
					if(columns[0]=="")
						continue;

					task tempTask = task();
					tempTask->id = (int)columns[0];
					/*if(tempTask->id == 0)
					{
						LOG->append_time("[taskId:" + tempTask->id +" can't equal 0!]");
						continue;
					}*/
					tempTask->isManual = upper_case(columns[1]);
					tempTask->name = columns[2];
					tempTask->desc = columns[3];

					tempTask->level_limit = (int)columns[4];
					tempTask->age_limit = (int)columns[5];
					tempTask->raceId_limit = columns[6];
					tempTask->sex_limit = columns[7];
					tempTask->profe_limit = columns[8];
					tempTask->isMarriage = upper_case(columns[9]);

					tempTask->grantNPC = split(columns[10]);
					tempTask->kind = columns[11];
					tempTask->taskType = (int)columns[12];
					tempTask->acceptWord = columns[13];

					tempTask->kill_info= String.trim_all_whites(columns[14]);
					tempTask->find_info = columns[15];
					tempTask->send_info= columns[16];
					tempTask->day_limit = (int)columns[17];

					tempTask->checkNPC = split(columns[18]); 
					tempTask->promptWord = columns[19];
					tempTask->completeWord = columns[20];

					tempTask->exp_award = (int)columns[21];
					tempTask->money_award = (int)columns[22];
					tempTask->itemid_award = ([]);
					if(columns[23]!=""){
						//werror("----now is the task "+tempTask->id+" of columns 23----\n");	
						array(string) award_tmp = columns[23]/"|";
						if(award_tmp&&sizeof(award_tmp)){
							foreach(award_tmp,string each_award){
								//werror("award = "+each_award+",");
								array(string) a_str = each_award/":";
								if(a_str&&(sizeof(a_str)==2)){
									//werror("num = "+a_str[1]+"\n");
									tempTask->itemid_award[a_str[0]] = (int)a_str[1];
								}
							}
						}
					//	werror("----now end the columns 23----\n");	
					}

					tempTask->isRepeat = (int)columns[24];
					tempTask->preIds = (int)columns[25];
					//2007/04/19添加任务的力量限制，智力限制和敏捷限制
					tempTask->str_limit = (int)columns[26];
					tempTask->think_limit = (int)columns[27];
					tempTask->dex_limit = (int)columns[28];
					tempTask->isStrait = (int)columns[29];

					//werror("----now start the columns 30----\n");	
					if(columns[30]&&columns[30]!="")
					tempTask->roomToDoTask = columns[30];
					if(columns[31]&&columns[31]!="")
					tempTask->roomToReTask = columns[31];
					//werror("----now end the columns 31----\n");	


					//将此任务加入到任务总表中
					if(taskMap[tempTask->id] == 0)
						taskMap[tempTask->id] = tempTask;
					/*else
					  {
					  LOG->append_time("[taskId:" + tempTask->id +" Repeat!]");
					  continue;
					  }*/

					//更新npc的发放任务数组
					if(grantMap[tempTask->grantNPC] == 0){
						grantMap[tempTask->grantNPC] = ({tempTask->id});
					}
					else{
						grantMap[tempTask->grantNPC] += ({tempTask->id});
					}

					//更新npc的验收任务数组
					if(checkMap[tempTask->checkNPC] == 0)
						checkMap[tempTask->checkNPC] = ({tempTask->id});
					else
						checkMap[tempTask->checkNPC] += ({tempTask->id});

					//若该任务为杀怪类型的任务
					if(tempTask->kill_info != "")
					{
						array(string) s_array = tempTask->kill_info/"|";
						s_array -= ({""});
						foreach(s_array,string s)
						{
							if(s == 0)
								continue;
							s = String.trim_all_whites(s);
							array b_array = s/":";

							tempTask->kill_order += ({b_array[0]});
							if(sizeof(b_array) == 1)
								tempTask->kill_map[b_array[0]] = 1;
							else
								tempTask->kill_map[b_array[0]] = (int)b_array[1];

							if(killMap[b_array[0]] == 0)
								killMap[b_array[0]] = ({tempTask->id});
							else
								killMap[b_array[0]] += ({tempTask->id});
						}
					}
					//若任务为获得任务物品类型
					if(tempTask->find_info != "")
					{
						array(string) s_array = tempTask->find_info/"|";
						s_array -= ({""});
						foreach(s_array,string s)
						{
							if(s == 0)
								continue;
							s = String.trim_all_whites(s);
							array b_array = s/":";

							tempTask->find_order += ({b_array[0]});
							if(sizeof(b_array) == 1)
								tempTask->find_map[b_array[0]] = 1;
							else
								tempTask->find_map[b_array[0]] = (int)b_array[1];

							if(dropItemMap[b_array[0]] == 0)
								dropItemMap[b_array[0]] = ({tempTask->id});
							else
								dropItemMap[b_array[0]] += ({tempTask->id});
						}
					}
					//若任务是传物类型
					if(tempTask->send_info != "")
					{
						array(string) s_array = tempTask->send_info/" ";
						s_array -= ({""});
						foreach(s_array,string s)
						{
							if(s == 0)
								continue;
							s = String.trim_all_whites(s);
							array b_array = s/":";

							if(sizeof(b_array) == 1)
								tempTask->send_map[b_array[0]] = 1;
							else
								tempTask->send_map[b_array[0]] = (int)b_array[1];
						}
					}

				}
				else{
					werror("-----wrong in Load() when getting comlumns, task num is"+i+"-----\n");
					return;
					//LOG->append_time("[load:("+ tempLine + ")] [columns-size:"+sizeof(columns)+"] [columns-num error!]");
				}
			}
		}
		werror("===== everything is ok!  =====\n");
	}
	else
		werror("===== Error! file not exist =====\n");

	//call_out(load,TIME_INTERVAL);
	//LOG->append_time("[load-end]");
}

//加载task_item_list.csv，写入taskItemMap和pathMap两个映射表中
void Load_task_item_list()
{
	werror("=====  Task_item start!  =====\n");
	string strTmp = ASYNC_IOD->read_text(TASK_ITEM_LIST,4*1024*1024);
	if(strTmp){
		array(string) lines = strTmp/"\r\n";
		if(lines&&sizeof(lines)){
			lines=lines-({""});
			foreach(lines,string eachline){
				array(string) column = eachline/",";
				pathMap[column[1]] = column[0];
				//对于第三列,将会把怪和掉落概率分割出来
				array(string) in_column2 = column[2]/"|";
				foreach(in_column2,string pair){
					array(string) each_pair = pair/":";
					int prop = (int)each_pair[1];
					if(taskItemMap[each_pair[0]]==0)
						taskItemMap[each_pair[0]] = ([column[1]:prop]);
					else
						taskItemMap[each_pair[0]] += ([column[1]:prop]);
				}
			}
			werror("===== everything is ok!  =====\n");
			return;
		}
	}
	else 
		werror("===== Error! file not exist =====\n");
}



// 新增的 .pike NPC 文件在 object_name 中保留扩展名，任务表沿用旧式短名。
string normalize_task_npc_name(string npcname)
{
	if(!npcname)
		return "";
	if(sizeof(npcname)>=5 &&
	   npcname[sizeof(npcname)-5..]==".pike")
		return npcname[0..sizeof(npcname)-6];
	return npcname;
}

// 每级职业历练由各阵营的职业导师发放；方士使用独立的方士传人。
int is_growth_task_teacher(object player,object npc)
{
	string profession_id;
	string npcname;

	if(!player || !npc)
		return 0;
	profession_id = player->query_profeId();
	npcname = normalize_task_npc_name(npc->query_name());
	switch(profession_id){
		case "jianxian":
		case "yushi":
		case "zhuxian":
			return npcname=="daodezhenjun400" ||
				npcname=="taijizhenren400" ||
				npcname=="yuanshitianzun999" ||
				npcname=="yuyixian400";
		case "kuangyao":
		case "wuyao":
		case "yinggui":
			return npcname=="zhaogongming400" ||
				npcname=="wangtianjun400" ||
				npcname=="tongtianjiaozhu999" ||
				npcname=="yuyuan400";
		case "fangshi":
			return npcname=="fangshi_teacher";
		case "zhenyue":
			return npcname=="zhenyue_teacher";
		case "tianxiang":
			return npcname=="tianxiang_teacher";
		case "lingyi":
			return npcname=="lingyi_teacher";
	}
	return 0;
}

//根据玩家的任务完成情况返回玩家可以接受的任务,可以提交的任务
string query_npc_taskList(object player,object npc)
{
	array(int) tmp_taskList=({});
	string canAccept = "\n可领取的任务：\n";
	string canRefer = "\n可提交的任务：\n";
	string s_rtn = "";
	string npcname=npc->query_name();
	string tasknpcname=normalize_task_npc_name(npcname);
	int flag_acc = 0;
	int flag_ref = 0;
	task tmp_task;
	tmp_taskList = grantMap[tasknpcname];
	//werror("task_list"+ tmp_taskList[0]+"----\n");
	if(player["/taskd/done"]==0)
		player["/taskd/done"]=([]);  //([string:int])
	if(player["/taskd/Cont"]==0)
		player["/taskd/Cont"]=([]); //([int:mapping(string:int)])
	if(player["/taskd/kill"]==0)
		player["/taskd/kill"]=([]); //([int:mapping(string:int)])
	if(player["/taskd/find"]==0)
		player["/taskd/find"]=([]); //([int:mapping(string:int)])
	//npc有任务可发放
	if(tmp_taskList&&sizeof(tmp_taskList)){
		for(int i=0;i<sizeof(tmp_taskList);i++){
			tmp_task = taskMap[tmp_taskList[i]];
			if(tmp_task){
				//如果玩家已经完成了这个任务并且这个任务不能重复做,则略过
				if(player["/taskd/done"][tmp_taskList[i]]==1&&!tmp_task->isRepeat)
					continue;
				//今天完成日常后将不再显示日常任务
				if(player["/taskd/done"][tmp_taskList[i]]==1&&tmp_task->isRepeat==2&&player->get_once_day[tmp_taskList[i]]==1)
					continue;
				//如果玩家没有完成这个任务的前续任务,也略过
				if(tmp_task->preIds&&player["/taskd/done"][tmp_task->preIds]==0)
					continue;
				//任务列表只显示当前等级真正可以领取的任务。
				if(player->query_level()<tmp_task->level_limit)
					continue;
				//职业不对口也不显示
				if(tmp_task->profe_limit!=""&&tmp_task->profe_limit!=player->query_profe_cn(player->query_profeId()))
					continue;
				//力量不符合限制，略过
				if(player->query_str()<tmp_task->str_limit)
					continue;
				if(tmp_task->isStrait && player->query_str()!=tmp_task->str_limit)
					continue;
				//智力不符合限制，略过
				if(player->query_think()<tmp_task->think_limit)
					continue;
				if(tmp_task->isStrait && player->query_think()!=tmp_task->think_limit)
					continue;
				//敏捷不符合限制，略过
				if(player->query_dex()<tmp_task->dex_limit)
					continue;
				if(tmp_task->isStrait && player->query_dex()!=tmp_task->dex_limit)
					continue;

				if(!player["/taskd/Cont"][tmp_taskList[i]]) {  //玩家没有这个任务
					canAccept +="["+tmp_task->name+":char_task_accept "+npcname+" "+tmp_task->id+"]\n";
					flag_acc = 1;
				}
			}
			else 
				werror("task:"+ tmp_taskList[i]+",may not exist----\n");
		}
	}

	// 动态每级历练不占普通任务栏，但应与普通任务一起出现在导师对话中。
	if(is_growth_task_teacher(player,npc)){
		mapping growth_state = query_growth_task_state(player);
		int growth_level = player->query_level();
		if(mappingp(growth_state) && sizeof(growth_state)){
			int required =
				query_growth_task_required(growth_state["level"]);
			canRefer += "["+
				query_growth_task_title(
					growth_state["profession"],growth_state["level"])+
				":growth_task]（"+growth_state["progress"]+"/"+
				required+"）";
			if(growth_state["progress"]>=required)
				canRefer += "(完成)";
			canRefer += "\n";
			flag_ref = 1;
		}
		else if(!query_growth_task_done(player,growth_level)){
			canAccept += "["+
				query_growth_task_title(
					player->query_profeId(),growth_level)+
				":growth_task]\n";
			flag_acc = 1;
		}
	}

	//npc有任务可验收
	tmp_taskList = checkMap[tasknpcname];
	if(tmp_taskList&&sizeof(tmp_taskList)){
		for(int i=0;i<sizeof(tmp_taskList);i++){
			tmp_task = taskMap[tmp_taskList[i]];
			if(player["/taskd/done"][tmp_taskList[i]]==1&&!tmp_task->isRepeat){ //如果玩家已经完成了这个任务,则略过
				//werror("----the task "+tmp_taskList[i]+" is done and can't repeat("+tmp_task->isRepeat+") ,so we continue ----\n");
				continue;
			}
			else{ 
				if(player["/taskd/Cont"][tmp_taskList[i]]) {  //玩家有这个任务
					if(!isComplete(player,tmp_taskList[i])) //若尚未完成
						canRefer +="["+tmp_task->name+":char_task_refer "+npcname+" "+tmp_task->id+"](未完成)\n";
					else  //已完成完成
						canRefer +="["+tmp_task->name+":char_task_refer "+npcname+" "+tmp_task->id+"](完成)\n";
					flag_ref = 1;
				}
			}
		}	
	}
	if(!flag_acc)
		canAccept = "";
	if(!flag_ref)
		canRefer = "";
	s_rtn += canAccept+canRefer;
	return s_rtn;
}

//返回任务列表，由外部调用
string query_words(object player,object npc)
{
	string taskStr = "";
	if(!player || !npc) return "";  // 添加 NULL 检查，兼容 Pike 9
	taskStr += query_npc_taskList(player,npc);
	return taskStr;
}

// ------------------------------------------------------------------------
// 每级职业历练
//
// 旧CSV任务只覆盖到68级，并且中间存在等级断档。这里为九个职业提供
// 1-MAX_LEVEL每级一次的动态历练，不占用旧任务的10个任务位。
// 只有击杀与领取等级相差5级以内的真实NPC才会推进，避免刷低级怪领奖。
// ------------------------------------------------------------------------

int is_growth_task_profession(string profession_id)
{
	switch(profession_id){
		case "jianxian":
		case "yushi":
		case "zhuxian":
		case "kuangyao":
		case "wuyao":
		case "yinggui":
		case "fangshi":
		case "zhenyue":
		case "tianxiang":
		case "lingyi":
			return 1;
	}
	return 0;
}

string query_growth_task_profession_name(string profession_id)
{
	switch(profession_id){
		case "jianxian":
			return "剑仙";
		case "yushi":
			return "羽士";
		case "zhuxian":
			return "诛仙";
		case "kuangyao":
			return "狂妖";
		case "wuyao":
			return "巫妖";
		case "yinggui":
			return "影鬼";
		case "fangshi":
			return "方士";
		case "zhenyue":
			return "镇越";
		case "tianxiang":
			return "天象";
		case "lingyi":
			return "灵医";
	}
	return "未知职业";
}

string query_growth_task_base_name(string profession_id)
{
	switch(profession_id){
		case "jianxian":
			return "剑心试锋";
		case "yushi":
			return "羽化巡灵";
		case "zhuxian":
			return "诛邪试炼";
		case "kuangyao":
			return "狂战淬体";
		case "wuyao":
			return "巫咒采魂";
		case "yinggui":
			return "影行猎杀";
		case "fangshi":
			return "灵契巡游";
		case "zhenyue":
			return "镇山守望";
		case "tianxiang":
			return "星轨推演";
		case "lingyi":
			return "百草济世";
	}
	return "职业历练";
}

string query_growth_task_stage(int level)
{
	switch(level%5){
		case 0:
			return "破境";
		case 1:
			return "初识";
		case 2:
			return "磨砺";
		case 3:
			return "精进";
		case 4:
			return "圆融";
	}
	return "历练";
}

string query_growth_task_title(string profession_id,int level)
{
	return "【"+query_growth_task_profession_name(profession_id)+"】"+
		query_growth_task_base_name(profession_id)+"·"+
		query_growth_task_stage(level)+"（"+level+"级）";
}

string query_growth_task_flavor(string profession_id)
{
	switch(profession_id){
		case "jianxian":
			return "以同阶妖邪磨砺剑心，在实战中稳固御剑根基。";
		case "yushi":
			return "巡察同阶灵脉，以仙术净化沿途作乱的妖邪。";
		case "zhuxian":
			return "追猎同阶强敌，在攻守转换间磨炼诛邪之术。";
		case "kuangyao":
			return "挑战同阶对手，以正面搏杀淬炼妖躯与战意。";
		case "wuyao":
			return "从同阶敌手身上感悟魂息，精进巫咒变化。";
		case "yinggui":
			return "潜行猎取同阶目标，在生死一线磨炼身法。";
		case "fangshi":
			return "携灵兽巡游同阶区域，以灵契或自身法术平息异动。";
		case "zhenyue":
			return "迎战同阶强敌，以稳固仇恨和守势磨炼镇山之躯。";
		case "tianxiang":
			return "观测同阶敌手的抗性，以不同法术积蓄并引爆星痕。";
		case "lingyi":
			return "观察同阶战局中的伤势，以智能治疗、净化与药契维持生机。";
	}
	return "击败同阶敌人，完成本级职业历练。";
}

int query_growth_task_required(int level)
{
	int required = 3+level/25;
	if(required>12)
		required = 12;
	if(required<3)
		required = 3;
	return required;
}

int query_growth_task_exp(int level)
{
	if(level<1)
		level = 1;
	if(level>MAX_LEVEL)
		level = MAX_LEVEL;
	return level*level*25+100;
}

int query_growth_task_money(int level)
{
	if(level<1)
		level = 1;
	if(level>MAX_LEVEL)
		level = MAX_LEVEL;
	return level*100+100;
}

mapping query_growth_task_state(object player)
{
	if(!player || !mappingp(player["/taskd/growth_active"]))
		return ([]);
	return copy_value(player["/taskd/growth_active"]);
}

int query_growth_task_done(object player,int level)
{
	if(!player || !mappingp(player["/taskd/growth_done"]))
		return 0;
	return player["/taskd/growth_done"][level] ? 1 : 0;
}

int query_growth_task_done_count(object player)
{
	if(!player || !mappingp(player["/taskd/growth_done"]))
		return 0;
	return sizeof(player["/taskd/growth_done"]);
}

int accept_growth_task(object player)
{
	string profession_id;
	int level;

	if(!player)
		return 0;
	profession_id = player->query_profeId();
	level = player->query_level();
	if(!is_growth_task_profession(profession_id))
		return 2;
	if(level<1 || level>MAX_LEVEL)
		return 3;
	if(mappingp(player["/taskd/growth_active"]))
		return 4;
	if(query_growth_task_done(player,level))
		return 5;

	player["/taskd/growth_active"] = ([
		"level":level,
		"profession":profession_id,
		"progress":0,
		"required":query_growth_task_required(level),
		"accepted_time":time(),
	]);
	return 1;
}

int cancel_growth_task(object player)
{
	if(!player || !mappingp(player["/taskd/growth_active"]))
		return 0;
	player["/taskd/growth_active"] = 0;
	return 1;
}

// 返回0=不计数，1=计数成功，2=本级历练已达成。
int record_growth_task_kill(object player,int killed_level)
{
	mapping state;
	int task_level;
	int min_level;
	int max_level;
	int required;

	if(!player || killed_level<1)
		return 0;
	state = player["/taskd/growth_active"];
	if(!mappingp(state))
		return 0;
	if(state["profession"]!=player->query_profeId())
		return 0;
	task_level = state["level"];
	if(task_level<1 || task_level>MAX_LEVEL)
		return 0;
	required = query_growth_task_required(task_level);
	state["required"] = required;
	if(state["progress"]<0)
		state["progress"] = 0;
	min_level = task_level-5;
	if(min_level<1)
		min_level = 1;
	max_level = task_level+5;
	if(max_level>MAX_LEVEL)
		max_level = MAX_LEVEL;
	if(killed_level<min_level || killed_level>max_level)
		return 0;
	if(state["progress"]>=required)
		return 0;

	state["progress"]++;
	tell_object(player,"职业历练进度："+state["progress"]+"/"+
		required+"\n");
	if(state["progress"]>=required){
		tell_object(player,"本级职业历练已经完成，可从任务列表提交。\n");
		return 2;
	}
	return 1;
}

mapping claim_growth_task(object player)
{
	mapping result = ([
		"code":0,
		"level":0,
		"exp":0,
		"money":0,
		"level_up":0,
	]);
	mapping state;
	int level;
	int get_exp;
	int actual_exp;
	int get_money;
	int required;

	if(!player)
		return result;
	state = player["/taskd/growth_active"];
	if(!mappingp(state)){
		result["code"] = 1;
		return result;
	}
	if(state["profession"]!=player->query_profeId()){
		result["code"] = 2;
		return result;
	}
	level = state["level"];
	if(level<1 || level>MAX_LEVEL){
		result["code"] = 4;
		return result;
	}
	required = query_growth_task_required(level);
	if(state["progress"]<required){
		result["code"] = 3;
		return result;
	}
	if(query_growth_task_done(player,level)){
		player["/taskd/growth_active"] = 0;
		result["code"] = 5;
		return result;
	}

	if(!mappingp(player["/taskd/growth_done"]))
		player["/taskd/growth_done"] = ([]);
	// 先落完成标记再发奖励，配合HTTP核心命令锁避免重复提交。
	player["/taskd/growth_done"][level] = 1;
	player["/taskd/growth_active"] = 0;

	get_exp = query_growth_task_exp(level);
	if(player->query_level()<MAX_LEVEL)
		actual_exp = player->add_exp_with_bonus(get_exp);
	get_money = query_growth_task_money(level);
	player->add_account(get_money);
	player->query_if_levelup();
	DAILYGOALD->record_task_completion(player);

	result["code"] = 6;
	result["level"] = level;
	result["exp"] = actual_exp;
	result["money"] = get_money;
	result["level_up"] = player->query_levelFlag();
	return result;
}

string query_growth_task_guide_room(object player)
{
	mapping state;
	string race_id;
	int level;

	if(!player)
		return "";
	state = player["/taskd/growth_active"];
	if(!mappingp(state) || !sizeof(state))
		return "";
	level = state["level"];
	race_id = player->query_raceId();

	// 达到70级后，普通地图怪才会按玩家等级动态刷新。
	if(level>=70){
		if(race_id=="human")
			return "plxianjing/zilingxijing";
		if(race_id=="monst")
			return "plxianjing/qingyuwulin";
		return "plxianjing/binghuanyuntai";
	}
	if(level>=68)
		return "klshuanjingwaicheng/heishandong";
	if(level>=66)
		return "klshuanjingwaicheng/heiheyuan";
	if(level>=64)
		return "penglaihuanjing/liehuochitang";
	if(level>=62)
		return "penglaihuanjing/qiushuangshilu";
	if(level>=59)
		return "penglaihuanjing/yunyepingyuan";
	if(level>=55)
		return "plxianjing/binghuanyuntai";
	if(level>=53)
		return "plxianjing/dangyunshijie";
	if(level>=50)
		return "liuguangpingyuan/liuguangchalu";
	if(level<=5){
		if(race_id=="monst")
			return "shanyaohaiwan/diwashuikeng";
		return "huanyecun/baishizilu";
	}
	if(level<=10){
		if(race_id=="monst")
			return "jinaodao/xiangshudongsiceng";
		return "kunlunshan/pubudongxuesiceng";
	}
	if(level<=15){
		if(race_id=="monst")
			return "wugongdong/xiaozhuadong";
		return "kunlunshan/lianpi";
	}
	if(level<=20){
		if(race_id=="monst")
			return "fushoushan/fushounongchangsanceng";
		if(race_id=="third")
			return "shierxianjing/taoyuantongshijiuceng";
		return "jiangjunmu/peilingyiceng";
	}
	if(level<=25){
		if(race_id=="monst")
			return "wugongdong/daxiedong";
		if(race_id=="third")
			return "liangjinghu/hehuamigong3";
		return "shierxianjing/lingxiadongershiceng";
	}
	if(level<=30){
		if(race_id=="monst")
			return "chaogewaicheng/beichenqiang";
		if(race_id=="third")
			return "liangjinghu/yueyingmigong18";
		return "shierxianjing/lingxiadongershiceng";
	}
	if(level<=35){
		if(race_id=="monst")
			return "chaogewaicheng/hebaomu";
		if(race_id=="third")
			return "liangjinghu/huayaotingyuan20";
		return "jiangjunmu/dajiangjunlingershiceng";
	}
	if(level<=40){
		if(race_id=="monst")
			return "muye/fuluying19";
		if(race_id=="third")
			return "liangjinghu/huxinting";
		return "muye/poyaozhen17";
	}
	return "waihai/qianhaihuangshapo";
}

mapping queryGrowthTaskGuideTarget(object player)
{
	mapping result = ([]);
	mapping state;
	string room_path;
	int required;

	if(!player)
		return result;
	state = player["/taskd/growth_active"];
	if(!mappingp(state) || !sizeof(state))
		return result;
	required = query_growth_task_required(state["level"]);
	if(state["progress"]>=required)
		return result;
	room_path = query_growth_task_guide_room(player);
	if(!room_path || room_path=="")
		return result;
	return ([
		"path":room_path,
		"target":state["level"]+"级历练区",
		"level":state["level"],
	]);
}

string queryGrowthTaskGuideLink(object player)
{
	mapping target = queryGrowthTaskGuideTarget(player);
	if(!sizeof(target))
		return "";
	return "[任务引导·飞往"+target["target"]+
		":task_guide growth]\n";
}

int queryTaskHasGuide(int taskid)
{
	task my_task = taskMap[taskid];
	if(!my_task)
		return 0;
	if(my_task->roomToDoTask &&
	   my_task->roomToDoTask!="" &&
	   my_task->roomToDoTask!="null")
		return 1;
	foreach(my_task->kill_order,string target_name){
		if(taskGuideTargetRoom[target_name])
			return 1;
	}
	foreach(my_task->find_order,string item_name){
		if(taskGuideFindRoom[item_name])
			return 1;
	}
	return 0;
}

mapping queryTaskGuideTarget(object player,int taskid)
{
	mapping result = ([]);
	task my_task = taskMap[taskid];
	string room_path = "";
	string target_name = "任务区域";

	if(!player || !my_task ||
	   !mappingp(player["/taskd/Cont"]) ||
	   !player["/taskd/Cont"][taskid])
		return result;

	if(my_task->kind=="kill"){
		foreach(my_task->kill_order,string each_target){
			int progress = 0;
			if(mappingp(player["/taskd/kill"]) &&
			   mappingp(player["/taskd/kill"][taskid]))
				progress =
					player["/taskd/kill"][taskid][each_target];
			if(progress<my_task->kill_map[each_target] &&
			   taskGuideTargetRoom[each_target]){
				target_name = each_target+"所在地图";
				room_path = taskGuideTargetRoom[each_target];
				break;
			}
		}
	}
	else if(my_task->kind=="find"){
		foreach(my_task->find_order,string each_item){
			if(count_MyItem(player,each_item)<
			   my_task->find_map[each_item] &&
			   taskGuideFindRoom[each_item]){
				target_name = each_item+"来源地图";
				room_path = taskGuideFindRoom[each_item];
				break;
			}
		}
	}
	if(room_path=="" &&
	   my_task->roomToDoTask &&
	   my_task->roomToDoTask!="" &&
	   my_task->roomToDoTask!="null")
		room_path = my_task->roomToDoTask;
	if(room_path=="")
		return result;
	return ([
		"path":room_path,
		"target":target_name,
		"taskid":taskid,
	]);
}

string queryTaskGuideLink(object player,int taskid)
{
	mapping target = queryTaskGuideTarget(player,taskid);
	if(!sizeof(target))
		return "";
	return "[任务引导·飞往"+target["target"]+
		":task_guide "+taskid+"]\n";
}

string queryGrowthTaskPage(object player)
{
	string s = "";
	string profession_id;
	mapping state;
	int level;
	int min_level;
	int max_level;
	int required;

	if(!player)
		return "无法读取人物状态。\n";
	profession_id = player->query_profeId();
	level = player->query_level();
	s += "【每级职业历练】\n";
	s += "每个等级都可完成一次，独立于普通任务栏。\n\n";
	if(!is_growth_task_profession(profession_id)){
		s += "当前职业尚未开放每级历练。\n";
		return s;
	}

	state = player["/taskd/growth_active"];
	if(mappingp(state)){
		required = query_growth_task_required(state["level"]);
		min_level = state["level"]-5;
		if(min_level<1)
			min_level = 1;
		max_level = state["level"]+5;
		if(max_level>MAX_LEVEL)
			max_level = MAX_LEVEL;
		s += query_growth_task_title(state["profession"],state["level"])+"\n";
		s += query_growth_task_flavor(state["profession"])+"\n";
		s += "目标：击败"+min_level+"至"+max_level+"级怪物 "+
			required+"只。\n";
		s += "进度："+state["progress"]+"/"+required+"\n";
		s += "奖励："+query_growth_task_exp(state["level"])+"经验、"+
			MUD_MONEYD->query_other_money_cn(
				query_growth_task_money(state["level"]))+"。\n\n";
		if(state["progress"]>=required)
			s += "[提交本级历练:growth_task claim]\n";
		else{
			s += "只有真实击杀才会推进；组队时必须与队伍同处一室。\n";
			s += queryGrowthTaskGuideLink(player);
		}
		s += "[放弃本级历练:growth_task cancel]\n";
		return s;
	}

	if(query_growth_task_done(player,level)){
		s += level+"级职业历练已经完成，升级后会开放下一次历练。\n";
		return s;
	}
	s += query_growth_task_title(profession_id,level)+"\n";
	s += query_growth_task_flavor(profession_id)+"\n";
	min_level = level-5;
	if(min_level<1)
		min_level = 1;
	max_level = level+5;
	if(max_level>MAX_LEVEL)
		max_level = MAX_LEVEL;
	s += "目标：击败"+min_level+"至"+max_level+"级怪物 "+
		query_growth_task_required(level)+"只。\n";
	s += "奖励："+query_growth_task_exp(level)+"经验、"+
		MUD_MONEYD->query_other_money_cn(
			query_growth_task_money(level))+"。\n\n";
	s += "[领取本级历练:growth_task accept]\n";
	s += "[领取并前往任务地图:task_guide growth_accept]\n";
	return s;
}

string queryGrowthTaskLine(object player)
{
	mapping state;
	int level;
	int required;

	if(!player || !is_growth_task_profession(player->query_profeId()))
		return "";
	level = player->query_level();
	state = player["/taskd/growth_active"];
	if(mappingp(state)){
		required = query_growth_task_required(state["level"]);
		return "\n【每级职业历练】"+
			"["+query_growth_task_title(
				state["profession"],state["level"])+
			":growth_task]（"+state["progress"]+"/"+
			required+"）\n";
	}
	if(query_growth_task_done(player,level))
		return "\n【每级职业历练】"+level+"级已完成，升级后刷新。\n";
	return "\n【每级职业历练】"+
		"["+query_growth_task_title(player->query_profeId(),level)+
		":growth_task]\n";
}

task queryTask(int id)
{
	return taskMap[id];
}

//返回任务名字
string queryTaskName(int id)
{
	string name = "";
	task myTask = taskMap[id];
	if(myTask)
		name = myTask->name;
	return name;
}

//返回任务等级
int queryTaskLevel(int id)
{
	int rtn = 0;
	task myTask = taskMap[id];
	if(myTask)
		rtn = myTask->level_limit;
	return rtn;
}

//返回任务职业限制
string queryTaskProfe(int id)
{
	string rtn_s = "";
	task myTask = taskMap[id];
	if(myTask)
		rtn_s =myTask->profe_limit;
	return rtn_s;
}

//返回任务描述
string queryTaskDesc(int id)
{
	string retStr = "";
	task myTask = taskMap[id];			
	if(myTask)
		retStr = myTask->desc;
	return retStr;
}

//返回接受任务时npc的说话
string queryTaskPromptWord(int id)
{
	string retStr = "";
	task myTask = taskMap[id];			
	if(myTask)
		retStr = myTask->promptWord;
	return retStr;
}

//返回完成任务时npc的说话
string queryTaskCompleteWord(int id)
{
	string retStr = "";
	task myTask = taskMap[id];			
	if(myTask)
		retStr = myTask->completeWord;
	return retStr;
}

string queryTaskAcceptWord(int id)
{
	string retStr = "";
	task myTask = taskMap[id];			
	if(myTask)
		retStr = myTask->acceptWord;
	return retStr;
}
//返回任务的金钱奖励
int queryTaskMoney(int id)
{
	int rtn = 0;
	task myTask = taskMap[id];			
	if(myTask)
		rtn = myTask->money_award;
	return rtn;
}

//返回任务是否有物品奖励
string queryTaskItem(int id)
{
	string rtn = "";
	task myTask = taskMap[id];			
	if(myTask){
		if(myTask->itemid_award == ([]))
			return rtn;
		else{
			foreach(indices(myTask->itemid_award),string item){
				string s_file = ITEM_PATH+item;
				//werror("----s_file in queryTaskItem() = "+s_file+"----\n");
				object item_ob = clone(s_file);
				if(item_ob){
					rtn += "["+item_ob->query_name_cn()+":inv_other "+s_file+"]x"+myTask->itemid_award[item]+"\n";
				}
			}
		}
	}
	else
		werror("Caution:----the task "+id+" don't exist----\n");
	return rtn;
}

//返回是否可以重复做
int query_task_isRepeat(int id)
{
	int rtn = 0;
	task myTask = taskMap[id];			
	rtn = myTask->isRepeat;
	return rtn;
}

//任务只能交给任务表中配置的验收NPC，避免旧页面或伪造命令静默失败。
int is_task_check_npc(int taskid,object npc)
{
	task myTask = taskMap[taskid];
	if(!myTask || !npc)
		return 0;
	return myTask->checkNPC==
		normalize_task_npc_name(npc->query_name());
}

//核心接口之一，由task_accept.pike调用，完成接受任务的一系列动作
int get_task(object player,int taskid,void|object npc)
{
	int rtn = 0;
	task tmp_task = taskMap[taskid];
	if(player["/taskd/Cont"]==0)
		player["/taskd/Cont"]=([]);
	if(tmp_task){
		if(player->query_level()<tmp_task->level_limit)
			return 2;  //玩家等级不够
		if(tmp_task->preIds &&
		   (!player["/taskd/done"] ||
		    player["/taskd/done"][tmp_task->preIds]==0))
			return 7;  //前续任务尚未完成
		if(npc && tmp_task->grantNPC!=
		   normalize_task_npc_name(npc->query_name()))
			return 7;  //必须从实际发放该任务的NPC处领取
		if(sizeof(indices(player["/taskd/Cont"]))>=10)
			return 3;  //玩家接受的任务超过了10个的限制
		if(tmp_task->profe_limit!=""&&tmp_task->profe_limit!=player->query_profe_cn(player->query_profeId()))
			return 4;  //职业不对口
		if(player["/taskd/Cont"][taskid])
			return 5; //重复接受任务是不可能的
		if(player->get_once_day[taskid]==1){
			werror("-----I am going to return the VALUE 666666!----\n");
			return 6;
		}
		player["/taskd/Cont"][taskid]=(["status":0,"start_time":time()]);
		//若此任务有杀戮的要求
		if(tmp_task->kind == "kill"){
			if(player["/taskd/kill"]==0)
				player["/taskd/kill"]=([]);
			foreach(indices(tmp_task->kill_map),string s_kill){
				player["/taskd/kill"][taskid] += ([s_kill:0]);
			}
			rtn = 1;
		}
		//若此任务有搜寻要求
		else if(tmp_task->kind == "find"){
			if(player["/taskd/find"]==0)
				player["/taskd/find"]=([]);
			foreach(indices(tmp_task->find_map),string s_find){
				player["/taskd/find"][taskid] += ([s_find:0]);
			}
			rtn = 1;
		}
		//若此任务有送信要求
		else if(tmp_task->kind == "send"){
			player["/taskd/Cont"][taskid]["status"]=1;
			rtn = 1;
		}
	}
	return rtn;
}

//核心接口之一，判断玩家是否完成了该任务,每次玩家打任务怪的时候调用
int isComplete(object player,int taskid)
{
	int rtn = 1;
	int count = 0;
	int flag_k = 1;
	task tmp_task = taskMap[taskid];
	if(tmp_task){
		switch(tmp_task->kind){
			case "kill":
				if(player["/taskd/Cont"][taskid]["status"]==1)
					return rtn;
			if(!player["/taskd/kill"][taskid])
				return 0;
			foreach(indices(tmp_task->kill_map),string s_kill){
				if(player["/taskd/kill"][taskid][s_kill]!= tmp_task->kill_map[s_kill]){
					flag_k = 0;
					rtn = 0;
					break;
				}
			}
			if(flag_k)
				player["/taskd/Cont"][taskid]["status"] = 1;
			break;
			case "find":
				foreach(indices(tmp_task->find_map),string s_find){
					count = count_MyItem(player,s_find);
					if(count<tmp_task->find_map[s_find]){
						rtn = 0;
						break;
					}
				}
			break;
			case "send":
				rtn = 1;
			break;
			default:
			rtn = 0;
		}
		return rtn;
	}
	return 0;
}

//核心接口之一，完成任务奖励，返回任务奖励的描述
string getTaskAward(object player,int taskid)
{
	string s_rtn = "";
	task tmp_task = taskMap[taskid];
	if(tmp_task){
		if(tmp_task->exp_award){
			int get_exp = tmp_task->exp_award;
			if(player->query_level() > tmp_task->level_limit)
				get_exp -= (int)(get_exp*(player->query_level() - tmp_task->level_limit)*10/100);
			if(get_exp <= 0||player->query_level()>=MAX_LEVEL)
				get_exp = 1;
			// 使用带加成的经验函数（HTTP API 用户自动获得 50% 加成）
			int actual_exp = player->add_exp_with_bonus(get_exp);
			// 构建 HTTP API 加成提示
			if(player->is_http_api_user && actual_exp > get_exp) {
				int bonus = actual_exp - get_exp;
				s_rtn = "【新界面加成+"+bonus+"】得到了"+actual_exp+"点经验。\n";
			} else {
				s_rtn = "得到了"+actual_exp+"点经验。\n";
			}
			player->query_if_levelup();
			if(player->query_levelFlag())
				s_rtn += "你的等级提升到了 "+player->query_level()+" 级！\n";	
		}
		if(tmp_task->money_award){
			player->add_account(tmp_task->money_award);
			s_rtn += "得到了"+MUD_MONEYD->query_other_money_cn(tmp_task->money_award)+"。\n";
		}
		if(tmp_task->itemid_award != ([])){
			object item_ob;
			foreach(indices(tmp_task->itemid_award),string item){
				string s_file = ITEM_PATH+item;
				string item_name = "";
				for(int j=0;j<tmp_task->itemid_award[item];j++){
					item_ob = clone(s_file);
					if(item_ob){
						item_name = item_ob->query_name_cn();
						if(item_ob->is("combine_item"))	
							item_ob->move_player(player->query_name());
						else
							item_ob->move(player);
					}
				}
				s_rtn += "得到了["+item_name+":inv_other "+s_file+"]x"+tmp_task->itemid_award[item]+"！\n";
			}
		}
	}
	return s_rtn;
}

//完成玩家提交任务后的善后工作
int clearTask(object player,int taskid)
{
	task tmp_task = taskMap[taskid];
	if(tmp_task){
		if(player["/taskd/Cont"][taskid])
			m_delete(player["/taskd/Cont"],taskid);

		if(tmp_task->kind=="kill"&&player["/taskd/kill"][taskid])
			m_delete(player["/taskd/kill"],taskid);

		else if(tmp_task->kind=="find"&&player["/taskd/find"][taskid]){
			foreach(indices(tmp_task->find_map),string s_find){
				remove_MyItem(player,s_find,tmp_task->find_map[s_find]);
			}
			m_delete(player["/taskd/find"],taskid);
		}

		if(player["/taskd/done"]==0)
			player["/taskd/done"]=([]);
		player["/taskd/done"][taskid]=1;
		//werror("-----tmo+task->isRepeat=["+ tmp_task->isRepeat +"]----\n");
		if(tmp_task->isRepeat==2){ //日常任务完成记录
			werror("-----I am going to set GET_ONCE_DAY!----\n");
			player->get_once_day[taskid]=1;
		}
		DAILYGOALD->record_task_completion(player);
		return 1;
	}
	return 0;
}
//移除玩家身上的任务物品
int remove_MyItem(object player,string item_name,int num)
{
	array all_obj = all_inventory(player);
	int i = 0;
	int temp_num = num;
	//检查任务物品符合条件才会调用该接口
	foreach(all_obj,object ob1){
		//非复数物品
		if(!ob1->is_combine_item()&&ob1->query_name_cn() == item_name){
			i++;
			ob1->remove();
			if(i >= num)
				break;
		}
		//复数物品,需要轮询检查，要判断具体数字
		if(ob1->is_combine_item()&&ob1->query_name_cn() == item_name){
			//该复数物品一组20个不够交付任务，接着轮询下一组
			if(ob1->amount<=temp_num){
				i+=ob1->amount;
				temp_num -= ob1->amount;
				ob1->remove();
			}
			else{
				i+=temp_num;
				ob1->amount -= temp_num;
			}
			if(i >= num)
				break;
		}
	}
	return i;
}
//获得玩家身上任务物品的个数
int count_MyItem(object player,string item_name)
{
	array(object) all_obj = all_inventory(player);
	int tmp = 0;
	foreach(all_obj,object ob1)
	{
		if(ob1)
		{
			//如果是复数物品
			if(ob1->is_combine_item()&&ob1->query_name_cn()==item_name)
				tmp+=ob1->amount;
			//如果是单数物品
			if(!ob1->is_combine_item()&&ob1->query_name_cn()==item_name)
				tmp++;	
		}
	}
	return tmp;
}

//查询玩家的任务列表，由gamelib/cmds/mytasks.pike调用
string queryMyTasks(object player)
{
	string s_rtn = "";
	int task_num = 0;
	task tmp_task;
	if(player["/taskd/Cont"]==0)
		player["/taskd/Cont"]=([]);
	if(player["/taskd/done"]==0)
		player["/taskd/done"]=([]);
	if(player["/taskd/kill"]==0)
		player["/taskd/kill"]=([]);
	if(player["/taskd/find"]==0)
		player["/taskd/find"]=([]);
	s_rtn += queryGrowthTaskLine(player);
	s_rtn +="[查询已完成的任务历史:viewTaskHistory]\n";
	if((task_num=sizeof(player["/taskd/Cont"]))==0){
		s_rtn += "\n你目前没有接受任何普通任务.T_T\n";
	}
	else{
		s_rtn += "\n已接受的任务("+task_num+"/10)：\n";
		foreach(indices(player["/taskd/Cont"]),int taskid){
			tmp_task = taskMap[taskid];
			if(tmp_task){
				s_rtn += "["+tmp_task->name+":view_mytask "+taskid+" 1]";
				//werror("\n\n------------FLAG!!----------\n");
				if(isComplete(player,taskid))
				{
				//werror("\n\n---------taskType="+tmp_task->taskType+"----------\n");
					if(tmp_task->taskType)
					{
						s_rtn += "(完成)";
						s_rtn += "([完成任务:qge74hye "+tmp_task->roomToReTask+"]\n)";
					}
					else
						s_rtn += "(完成)";
				}
				else{ 
				//werror("\n\n---------taskType="+tmp_task->taskType+"----------\n");
					if(tmp_task->taskType)
					{
						//		werror("\n\n--------i am in!!------\n");
						s_rtn += "([开始任务:qge74hye "+tmp_task->roomToDoTask+"])\n";
					}
					else
						s_rtn += "\n";
					s_rtn += queryTaskGuideLink(player,taskid);
				}
			}
		}
	}
	return s_rtn;
}

//查询已完成的任务,在wapmud/cmds/viewTaskHistory.pike 中调用
string queryTaskHistory(object player)
{
	string s_rtn = "";
	array(int) task_arr = ({});
	int taskid;
	int growth_count;
	task tmp_task;

	if(player["/taskd/done"]==0)
		player["/taskd/done"]=([]);
	task_arr = indices(player["/taskd/done"]);
	growth_count = query_growth_task_done_count(player);
	if(growth_count)
		s_rtn += "每级职业历练：已完成"+growth_count+"个等级。\n";
	if(task_arr&&sizeof(task_arr)){
		s_rtn += "已完成任务的历史记录：\n";
		for(int i=0;i<sizeof(task_arr);i++){
			taskid = task_arr[i];
			tmp_task = taskMap[taskid];
			if(tmp_task){
				s_rtn +="["+tmp_task->name+":view_mytask "+taskid+" 0]\n";
			}
		}
	}
	else if(!growth_count)
		s_rtn += "没有已完成任务的历史\n";
	return s_rtn;
}

//返回玩家在此任务的完成进度，由view_mytask.pike调用
string queryTaskProcess(object player,int taskid)
{
	int count = 0;
	string s_rtn = "";
	task tmp_task = taskMap[taskid];
	if(tmp_task){
		if(tmp_task->kind == "kill"){
			//异常情况处理，按照逻辑来说不会执行这一步，以防万一
			if(player["/taskd/kill"] == 0){
				player["/taskd/kill"] = ([]);
				get_task(player,taskid);
			}
			//正常情况处理
			if(player["/taskd/kill"][taskid]){
				foreach(sort(indices(player["/taskd/kill"][taskid])),string s){
					count = player["/taskd/kill"][taskid][s];
					s_rtn += "已杀死的"+s+"："+count+"/"+tmp_task->kill_map[s]+"\n";
				}
			}
		}
		if(tmp_task->kind == "find"){
			if(player["/taskd/find"] == 0){
				player["/taskd/find"] = ([]);
				get_task(player,taskid);
			}
			if(player["/taskd/find"][taskid]){
				foreach(sort(indices(player["/taskd/find"][taskid])),string s){
					count = count_MyItem(player,s);
					s_rtn += "已得到的"+s+"："+count+"/"+tmp_task->find_map[s]+"\n";
				}
			}
		}
	}
	else 
		werror("-----queryTaskProcess():no such task----\n");
	return s_rtn;
}

//玩家放弃任务，由task_cancel.pike调用
int cancelTask(object player,int taskid)
{
	task tmp_task = taskMap[taskid];
	if(tmp_task){
		if(player["/taskd/Cont"][taskid])
			m_delete(player["/taskd/Cont"],taskid);
		if(tmp_task->kind=="kill" && player["/taskd/kill"][taskid])
			m_delete(player["/taskd/kill"],taskid);
		else if(tmp_task->kind=="find" && player["/taskd/find"][taskid])
			m_delete(player["/taskd/find"],taskid);
		return 1;
	}
	return 0;
}

//判断所杀怪是否属于玩家的任务，若是，则进行相应的处理
int if_in_killTask(object player,string killed_name,int|void killed_level)
{
	int taskid;
	int growth_result;
	task tmp_task;
	array(int) task_array = killMap[killed_name];
	NEWBIED->record_kill(player);
	DAILYGOALD->record_kill(player,killed_level);
	growth_result = record_growth_task_kill(player,killed_level);
	if(!player["/taskd/Cont"])
		player["/taskd/Cont"]=([]);
	if(!player["/taskd/kill"])
		player["/taskd/kill"]=([]);
	if(task_array&&sizeof(task_array)){
		for(int i=0;i<sizeof(task_array);i++){
			taskid = task_array[i];
			if(player["/taskd/Cont"][taskid]){
				tmp_task = taskMap[taskid];
				if(tmp_task){
					if(player["/taskd/kill"][taskid]&&player["/taskd/kill"][taskid][killed_name]<tmp_task->kill_map[killed_name]){	
						player["/taskd/kill"][taskid][killed_name]++;
						string s_tmp = "已杀死"+killed_name+"："+player["/taskd/kill"][taskid][killed_name]+"/"+tmp_task->kill_map[killed_name]+"\n";
						tell_object(player,s_tmp);
					}
				}
				else 
					return -1;
			}
			else 
				continue;
		}
		return 1;
	}
	return growth_result ? 1 : 0;
}

//判断是否掉落任务物品,由npc.pike->fight_die()调用
object if_in_findTask(object player,string killed_name)
{
	string log_s = "";
	int prop = 0; //掉落任务物品的几率
	object|zero rtn_ob = 0;
	array(object) items_drop = ({});
	array(int) item_task_list = ({});
	task tmp_task;
	//获得玩家已领取的搜寻任务的任务列表
	array(int) player_task_list = ({});
	if(!player["/taskd/find"])
		player["/taskd/find"]=([]);
	player_task_list = indices(player["/taskd/find"]);
	if(!player_task_list)
		return 0;
	//获得被杀怪能掉落的任务物品映射表
	mapping(string:int) killed_m = taskItemMap[killed_name];
	if(!killed_m)
		return 0;
	//对于每种可掉落的任务物品与玩家的任务列表进行比对，从而得出应该掉落的物品
	foreach(indices(killed_m),string task_item){
		log_s += "--now the task_item ="+task_item+"--";
		//获得与任务物品相关的任务列表,实际上只有一个元素
		item_task_list = dropItemMap[task_item];
		if(!item_task_list)
			item_task_list = ({});
		//与玩家任务列表比对,
		array(int) task_have = ({});
		task_have = copy_value(player_task_list & item_task_list);
		if(task_have&&sizeof(task_have)){
			log_s += "--the player had the task: "+task_have[0]+"--";
			//此时就得到了掉落物品的名字
			tmp_task = taskMap[task_have[0]];
			if(tmp_task){
				if(count_MyItem(player,task_item)<tmp_task->find_map[task_item]){
					string itemname = pathMap[task_item];
					log_s += "--so the task item name = "+itemname+"--";
					object tmp_ob = ITEMSD->get_task_item(itemname,killed_m[task_item]);
					if(tmp_ob){
						log_s += "--and we drop it--";
						items_drop += ({tmp_ob});
					}
					continue;
				}
			}
		}
		else 
			continue;
	}
	if(items_drop&&sizeof(items_drop)){
		int num = random(sizeof(items_drop));
		rtn_ob = items_drop[num];
		log_s += "--at last got :"+rtn_ob->query_name_cn()+"--\n";
		log_s += "\n------------------------\n";
		string now=ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/taskdrop.log",
			now[0..sizeof(now)-2]+":"+log_s);

		return rtn_ob;
	}
	else{
		log_s += "\n------------------------\n";
		string now=ctime(time());
		ASYNC_IOD->append_log(ROOT+"/log/taskdrop.log",
			now[0..sizeof(now)-2]+":"+log_s);
		return 0;
	}
}

string split(string pathname)
{
	if(pathname == 0)
		return "";
	pathname = String.trim_all_whites(pathname);
	array(string) a_array = pathname/"\/";
	return a_array[sizeof(a_array)-1];
}
