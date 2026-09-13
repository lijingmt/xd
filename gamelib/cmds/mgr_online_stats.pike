#include <command.h>
#include <gamelib/include/gamelib.h>
// 管理员在线统计（按账号聚合，角色不计账号数）。
// 数据源：MAP_WORKERD 各Worker持有的协调器全集群在线快照
// （含account_id）；单进程部署时回退扫描本进程在线玩家。
// arg: 空=第一页  page N=翻页  all=多角色账号
#define ONLINE_STATS_PAGE_SIZE 20

private int is_admin(object me)
{
	return me && MANAGERD->checkpower(me->query_name())=="admin";
}

private array(mapping(string:mixed)) collect_online_rows()
{
	mapping snapshot = MAP_WORKERD->query_local_online_snapshot();
	array(mapping(string:mixed)) rows = ({});
	if(mappingp(snapshot) && (int)snapshot["ok"]==1 &&
	   arrayp(snapshot["users"])){
		foreach((array)snapshot["users"],mixed raw)
			if(mappingp(raw))
				rows += ({(mapping)raw});
		return rows;
	}
	// 单进程/快照未就绪回退：本进程即全世界。
	foreach(users(),object player){
		mapping(string:mixed) row;
		mixed err = catch{
			row = ([
				"userid":(string)player->query_name(),
				"name_cn":(string)player->query_name_cn(),
				"profe_id":(string)player->query_profeId(),
				"level":(int)player->query_level(),
				"worker_id":MAP_WORKERD->query_local_worker_id(),
				"account_id":functionp(player->query_account_owner) ?
					(string)player->query_account_owner() :
					(string)player->query_name(),
			]);
		};
		if(!err && mappingp(row) && (string)row["userid"]!="")
			rows += ({row});
	}
	return rows;
}

private string partition_of(string userid)
{
	if(sizeof(userid)>=4 && has_prefix(userid,"xd"))
		return userid[0..3];
	return "主区";
}

int main(string|zero arg)
{
	object me=this_player();
	int page=0;
	int only_multi=0;
	if(!me)
		return 0;
	if(!is_admin(me)){
		write("只有管理员可以使用在线统计。\n[返回游戏:look]\n");
		return 1;
	}
	if(arg && sscanf(arg,"page %d",page)==1)
		;
	else if(arg=="all")
		only_multi=1;
	if(page<0)
		page=0;

	array(mapping(string:mixed)) rows=collect_online_rows();
	// 账号聚合：account_id -> ({角色row...})
	mapping(string:array(mapping(string:mixed))) by_account=([]);
	foreach(rows,mapping row){
		string account=(string)row["account_id"];
		if(account=="")
			account=(string)row["userid"];
		by_account[account]+=({row});
	}
	// 排序：角色多的账号在前，同数量按账号名。
	array(string) accounts=indices(by_account);
	for(int i=0;i<sizeof(accounts);i++)
		for(int j=i+1;j<sizeof(accounts);j++){
			int a=sizeof(by_account[accounts[i]]);
			int b=sizeof(by_account[accounts[j]]);
			if(b>a || (b==a && accounts[j]<accounts[i])){
				string t=accounts[i];
				accounts[i]=accounts[j];
				accounts[j]=t;
			}
		}
	if(only_multi)
		accounts=filter(accounts,lambda(string a){
			return sizeof(by_account[a])>1;
		});

	// 分区统计
	mapping(string:int) by_partition=([]);
	foreach(rows,mapping row)
		by_partition[partition_of((string)row["userid"])]++;

	int total_accounts=sizeof(by_account);
	int total_chars=sizeof(rows);
	int multi_accounts=0;
	foreach(indices(by_account),string a)
		if(sizeof(by_account[a])>1)
			multi_accounts++;

	int max_page=sizeof(accounts)>0 ?
		(sizeof(accounts)-1)/ONLINE_STATS_PAGE_SIZE : 0;
	if(page>max_page)
		page=max_page;
	int start=page*ONLINE_STATS_PAGE_SIZE;
	int end=min(sizeof(accounts)-1,start+ONLINE_STATS_PAGE_SIZE-1);

	string s="§g在线统计§r（快照口径：全集群）\n";
	s+="在线账号："+(string)total_accounts+
		"（多角色账号 "+(string)multi_accounts+"）　"+
		"在线角色："+(string)total_chars+"\n";
	s+="分区：";
	foreach(sort(indices(by_partition)),string p)
		s+=p+" "+(string)by_partition[p]+"人　";
	s+="\n[全部账号:mgr_online_stats all]|[仅多角色:mgr_online_stats all]\n";
	if(!sizeof(accounts)){
		s+="当前没有在线账号。\n";
	}
	else{
		s+="第"+(string)(page+1)+"/"+(string)(max_page+1)+"页"+
			(only_multi?"（仅多角色）":"")+"\n";
		for(int i=start;i<=end;i++){
			string account=accounts[i];
			array(mapping(string:mixed)) chars=by_account[account];
			s+="§y"+account+"账号（"+(string)sizeof(chars)+"角色在线）§r";
			foreach(chars,mapping row)
				s+=" "+(string)row["name_cn"]+
					"("+(string)(int)row["level"]+")";
			s+="\n";
		}
		if(page>0)
			s+="[上一页:mgr_online_stats page "+(string)(page-1)+"] ";
		if(page<max_page)
			s+="[下一页:mgr_online_stats page "+(string)(page+1)+"] "+
				"[尾页:mgr_online_stats page "+(string)max_page+"]";
		if(max_page>0)
			s+="\n";
	}
	s+="[返回游戏:look]\n";
	me->write_view(WAP_VIEWD["/emote"],0,0,s);
	return 1;
}
